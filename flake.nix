{
  description = "Install scripts for nix-based tools";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/23.05";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        # { toolName: string, baseUrl: string, flakeLocation: string, testCommand: string } -> derivation
        #
        # The derivation builds a set of files which contain the install script
        # and other needed files. So you can copy the files to a web server to
        # host the files and people can install nix and the given tool with:
        #
        # $ sh <(curl --proto '=https' --tlsv1.2 -sSf https://example.com/install.sh)
        #
        # Example usage:
        #   lib.mkInstallScriptFiles {
        #     toolName = "test-tool";
        #     baseUrl = "https://example.com";
        #     flakeLocation = "github:nixos/nixpkgs/f098c1634d7bc427d9fe51e5f536c8aed65c1991#hello";
        #     testCommand = "hello";
        #   }
        lib.mkInstallScriptFiles = { toolName, baseUrl, allowHttp ? false, flakeLocation, testCommand }:
          let
            files = {
              "install.sh" = pkgs.writeScript
                "install.sh"
                (pkgs.lib.replaceStrings
                  [
                    "@@toolName@@"
                    "@@baseUrl@@"
                    "@@flakeLocation@@"
                    "@@testCommand@@"
                    "@@additionalPrefix@@"
                    "@@forceHttpsOption@@"
                  ]
                  [
                    toolName
                    baseUrl
                    flakeLocation
                    testCommand
                    (if allowHttp then "export NIX_INSTALLER_FORCE_ALLOW_HTTP=true" else "")
                    (if allowHttp then "" else "--proto '=https'")
                  ]
                  (builtins.readFile ./install-template.sh));
              "nix-installer.sh" = pkgs.fetchurl {
                url = "https://github.com/DeterminateSystems/nix-installer/releases/download/v0.14.0/nix-installer.sh";
                hash = "sha256-zY5hgeiK1FvKag4db2XmS7rJrjEmn/aIul5sIgXEGE4=";
              };
            } //
            pkgs.lib.attrsets.mapAttrs'
              (name: hash: {
                inherit name;
                value = pkgs.fetchurl
                  {
                    url = "https://github.com/DeterminateSystems/nix-installer/releases/download/v0.14.0/${name}";
                    inherit hash;
                  };
              })
              {
                "nix-installer-x86_64-linux" = "sha256-1kqnlgk39OQmbw4ubewl586gw1JYYNzESIexjWWjKHs=";
                "nix-installer-aarch64-linux" = "sha256-wu/O7YGRrqNPHoaHW5wMfoiIsEvrlEA2FoIzphASxko=";
                "nix-installer-x86_64-darwin" = "sha256-PxttqPQ2BnAo8/KrL/W+zC8l0h1FC5y+n9XiSYJwJ2o=";
                "nix-installer-aarch64-darwin" = "sha256-DwjQsLVE3Nl9MmIlU14DGAXaHI7Ddm4jAI96ncukeQU=";
              };
          in
          pkgs.runCommand "install-files" { } (
            pkgs.lib.attrsets.foldlAttrs
              (acc: name: path: acc + "cp ${path} $out/${name}\n") "mkdir $out\n"
              files
          );
        packages = {
          exampleInstallerFiles = self.lib.${system}.mkInstallScriptFiles {
            toolName = "hello";
            baseUrl = "http://10.0.2.2:8000";
            allowHttp = true;
            flakeLocation = "github:nixos/nixpkgs/f098c1634d7bc427d9fe51e5f536c8aed65c1991#hello";
            testCommand = "hello";
          };
        };
        apps = {
          testFileServer = {
            type = "app";
            program =
              builtins.toString (pkgs.writeScript "test-file-server" ''
                cd ${packages.exampleInstallerFiles}
                exec ${pkgs.python3}/bin/python3 -m http.server 2> /dev/null
              '');
          };
          bootDarwinVm =
            let
              bootVMScript = pkgs.writeShellScriptBin "boot-vm" ''
                set -eu
                export TMPDIR=/tmp
                ALLOCATED_RAM="8192" # MiB
                CPU_SOCKETS="1"
                CPU_CORES="4"
                CPU_THREADS="4"

                IMAGES_PATH="macos"
                test -f $IMAGES_PATH/mac_hdd_ng.img || (echo "macos images not found" && exit 1)

                # shellcheck disable=SC2054
                args=(
                  -enable-kvm -m "$ALLOCATED_RAM" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check
                  -machine q35
                  -usb -device usb-kbd -device usb-tablet
                  -smp "$CPU_THREADS",cores="$CPU_CORES",sockets="$CPU_SOCKETS"
                  -device usb-ehci,id=ehci
                  -device nec-usb-xhci,id=xhci
                  -global nec-usb-xhci.msi=off
                  -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
                  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
                  -drive if=pflash,format=raw,readonly=on,file="$IMAGES_PATH/OVMF_CODE.fd"
                  -drive if=pflash,format=raw,file="$IMAGES_PATH/OVMF_VARS-1920x1080.fd"
                  -smbios type=2
                  -device ich9-ahci,id=sata
                  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$IMAGES_PATH/OpenCore.qcow2"
                  -device ide-hd,bus=sata.2,drive=OpenCoreBoot
                  -drive id=MacHDD,if=none,snapshot=on,file="$IMAGES_PATH/mac_hdd_ng.img",format=qcow2
                  -device ide-hd,bus=sata.3,drive=MacHDD
                  -netdev user,id=net0,hostfwd=tcp::2222-:22 -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27
                  -device vmware-svga
                  -display none
                )
                ${pkgs.qemu}/bin/qemu-system-x86_64 "''${args[@]}" &
                while ! ssh -q -p 2222 -o ConnectTimeout=1 garnix@127.0.0.1 true; do
                  echo -n "."
                  sleep 1
                done
                echo "VM booted"
              '';
            in
            {
              type = "app";
              program = "${bootVMScript}/bin/boot-vm";
            };
          bootLinuxVm = {
            type = "app";
            program =
              let
                ubuntu = pkgs.fetchurl {
                  url = "https://cloud-images.ubuntu.com/jammy/20231027/jammy-server-cloudimg-amd64.img";
                  hash = "sha256-a7Ukf4eRm4A8IRr9GvdLMJa+boNNrCnPrHEdrXLq/qg=";
                };
                # See https://cloudinit.readthedocs.io/en/latest/reference/index.html
                cloudcfg = {
                  ssh_pwauth = true;
                  users = [{
                    name = "garnix";
                    plain_text_passwd = "test";
                    lock_passwd = false;
                    sudo = "ALL=(ALL) ALL";
                    shell = "/bin/bash";
                  }];
                  runcmd = [
                    # Attempt to briefly connect to port 2223 on the host to
                    # notify the boot-vm script that we have fully booted and
                    # it can stop waiting.
                    [ "nc" "-vz" "10.0.2.2" "2223" ]
                  ];
                };
                cloud-init-img = pkgs.runCommand "user-data-img" { }
                  "${pkgs.cloud-utils}/bin/cloud-localds $out ${pkgs.writeTextFile {
                    name = "userdata";
                    text = "#cloud-config\n" + builtins.toJSON cloudcfg;
                  }}";
              in
              builtins.toString (pkgs.writeScript "boot-vm" ''
                set -eux

                ROOT_IMG=$(mktemp)
                CLOUD_INIT_IMG=$(mktemp)
                ${pkgs.qemu}/bin/qemu-img create -o backing_file=${ubuntu},backing_fmt=qcow2 -f qcow2 $ROOT_IMG 3G
                cp ${cloud-init-img} $CLOUD_INIT_IMG
                chmod +w $CLOUD_INIT_IMG
                ${pkgs.qemu}/bin/qemu-system-x86_64 \
                  -m 1G \
                  -enable-kvm \
                  -machine q35 \
                  -device intel-iommu \
                  -drive file=$ROOT_IMG,format=qcow2 \
                  -drive file=$CLOUD_INIT_IMG,format=raw \
                  -nographic \
                  -device e1000,netdev=net0 \
                  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
                  &
                # Wait for the runcmd to call us back to let us know that we are fully booted.
                # (See runcmd in the flake file under cloudcfg)
                nc -vl 2223
              '');
          };
          sshVm = {
            type = "app";
            program = builtins.toString (pkgs.writeScript "ssh-vm" ''
              ${pkgs.sshpass}/bin/sshpass -p test ssh \
                -t \
                -o "StrictHostKeyChecking no" \
                -o "UserKnownHostsFile=/dev/null" \
                localhost \
                -p 2222 \
                -l garnix \
                "$@"
            '');
          };
        };
        checks = {
          shellCheck = pkgs.runCommand "shellcheck"
            { nativeBuildInputs = [ pkgs.shellcheck ]; }
            ''
              shellcheck ${packages.exampleInstallerFiles}/install.sh
              touch $out
            '';
        };
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.just
              pkgs.lsof
              pkgs.shellcheck
            ];
          };
        };
      }
    );
}
