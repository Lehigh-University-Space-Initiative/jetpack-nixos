{ config, pkgs, lib, utils, ... }:

# Convenience package that allows you to set options for the flash script using the NixOS module system.
# You could do the overrides yourself if you'd prefer.
let
  inherit (lib)
    mkEnableOption
    mkOption
    types;

  cfg = config.hardware.nvidia-jetpack;

  flashTools = cfg.flasherPkgs.callPackages (import ../device-pkgs { inherit config pkgs; }) { };
in
{
  imports = with lib; [
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "bootloader" "autoUpdate" ] [ "hardware" "nvidia-jetpack" "firmware" "autoUpdate" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "bootloader" "logo" ] [ "hardware" "nvidia-jetpack" "firmware" "uefi" "logo" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "bootloader" "debugMode" ] [ "hardware" "nvidia-jetpack" "firmware" "uefi" "debugMode" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "bootloader" "errorLevelInfo" ] [ "hardware" "nvidia-jetpack" "firmware" "uefi" "errorLevelInfo" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "bootloader" "edk2NvidiaPatches" ] [ "hardware" "nvidia-jetpack" "firmware" "uefi" "edk2NvidiaPatches" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "firmware" "optee" "supplicantExtraArgs" ] [ "hardware" "nvidia-jetpack" "firmware" "optee" "supplicant" "extraArgs" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "firmware" "optee" "trustedApplications" ] [ "hardware" "nvidia-jetpack" "firmware" "optee" "supplicant" "trustedApplications" ])
    (mkRenamedOptionModule [ "hardware" "nvidia-jetpack" "firmware" "optee" "supplicantPlugins" ] [ "hardware" "nvidia-jetpack" "firmware" "optee" "supplicant" "plugins" ])
  ];

  options = {
    hardware.nvidia-jetpack = {
      firmware = {
        autoUpdate = lib.mkEnableOption "automatic updates for Jetson firmware";

        bootOrder = mkOption {
          # https://github.com/NVIDIA/edk2-nvidia/blob/71fc2f6de48f3e9f01214b4e9464dd03620b876b/Silicon/NVIDIA/Library/PlatformBootOrderLib/PlatformBootOrderLib.c#L26
          type = types.nullOr (types.listOf (types.enum [ "scsi" "usb" "sata" "pxev4" "httpv4" "pxev6" "httpv6" "nvme" "ufs" "sd" "emmc" "cdrom" "boot.img" "virtual" "shell" ]));
          default = null;
          description = "The default boot order";
        };

        uefi = {
          logo = mkOption {
            type = types.nullOr types.path;
            # This NixOS default logo is made available under a CC-BY license. See the repo for details.
            default = pkgs.fetchurl {
              url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/e7d4050f2bb39a8c73a31a89e3d55f55536541c3/logo/nixos.svg";
              sha256 = "sha256-E+qpO9SSN44xG5qMEZxBAvO/COPygmn8r50HhgCRDSw=";
            };
            description = "Optional path to a boot logo that will be converted and cropped into the format required";
          };

          debugMode = mkOption {
            type = types.bool;
            default = false;
          };

          errorLevelInfo = mkOption {
            type = types.bool;
            default = cfg.firmware.uefi.debugMode;
          };

          edk2NvidiaPatches = mkOption {
            type = types.listOf types.path;
            description = lib.mdDoc ''
              Patches that will be applied to the edk2-nvidia repo
            '';
            default = [ ];
          };

          edk2UefiPatches = mkOption {
            type = types.listOf types.path;
            description = lib.mdDoc ''
              Patches that will be applied to the nvidia edk2 repo which is nvidia's fork of the upstream edk2 repo
            '';
            default = [ ];
          };

          secureBoot = {
            enrollDefaultKeys = lib.mkEnableOption "enroll default UEFI keys";
            defaultPkEslFile = mkOption {
              type = lib.types.path;
              description = lib.mdDoc ''
                The path to the UEFI PK EFI Signature List (ESL).
              '';
            };
            defaultKekEslFile = mkOption {
              type = lib.types.path;
              description = lib.mdDoc ''
                The path to the UEFI KEK Signature List (ESL).
              '';
            };
            defaultDbEslFile = mkOption {
              type = lib.types.path;
              description = lib.mdDoc ''
                The path to the UEFI DB Signature List (ESL).
              '';
            };
          };

          capsuleAuthentication = {
            enable = mkEnableOption "capsule update authentication";

            trustedPublicCertPemFile = mkOption {
              type = lib.types.path;
              description = lib.mdDoc ''
                The path to the public certificate (in DER format) that will be
                used for validating capsule updates. Capsule files must be signed
                with a private key in the same certificate chain. This file will
                be included in the EDK2 build.
              '';
            };

            otherPublicCertPemFile = mkOption {
              type = lib.types.path;
              description = lib.mdDoc ''
                The path to another public certificate (in PEM format) that will
                be used when signing capsule payloads. This can be the same as
                `trustedPublicCertPem`, but it can also be an intermediate
                certificate further down in the chain of your PKI.
              '';
            };

            signerPrivateCertPemFile = mkOption {
              type = lib.types.path;
              description = lib.mdDoc ''
                The path to the private certificate (in PEM format) that will be
                used for signing capsule payloads.
              '';
            };

            requiredSystemFeatures = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = lib.mdDoc ''
                Additional `requiredSystemFeatures` to add to derivations which
                make use of capsule authentication private keys.
              '';
            };

            preSignCommands = lib.mkOption {
              type = types.lines;
              default = "";
              description = "Additional commands to run before performing operation that involve signing. Can be used to set up environment to interact with an external HSM.";
            };
          };
        };

        optee = {
          supplicant = {
            enable = mkEnableOption "tee-supplicant daemon" // { default = true; };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = lib.mdDoc ''
                Extra arguments to pass to tee-supplicant.
              '';
            };

            trustedApplications = mkOption {
              type = types.listOf types.package;
              default = [ ];
              description = lib.mdDoc ''
                Trusted applications that will be loaded into the TEE on
                supplicant startup.
              '';
            };

            plugins = mkOption {
              type = types.listOf types.package;
              default = [ ];
              description = lib.mdDoc ''
                A list of packages containing TEE supplicant plugins. TEE
                supplicant will load each plugin file in the top level of each
                package on startup.
              '';
            };
          };

          patches = mkOption {
            type = types.listOf types.path;
            default = [ ];
          };

          extraMakeFlags = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };

          taPublicKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = lib.mdDoc ''
              The public key to build into optee OS that will be used for
              verifying loaded runtime TAs. If not provided, TAs are verified
              with the public key derived from the private key in optee's
              source tree.
            '';
          };
        };

        eksFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };

        # See: https://docs.nvidia.com/jetson/archives/r35.4.1/DeveloperGuide/text/SD/Security/SecureBoot.html#prepare-an-sbk-key
        secureBoot = {
          pkcFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to Public Key Cryptography (PKC) .pem file used to validate authenticity and integrity of firmware partitions. Do not include this file in your /nix/store. Instead, use a sandbox exception to provide access to the key";
            example = "/run/keys/jetson/xavier_pkc.pem";
          };

          sbkFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to Secure Boot Key (SBK) file used to encrypt firmware partitions. Do not include this file in your /nix/store.  Instead, use a sandbox exception to provide access to the key";
            example = "/run/keys/jetson/xavier_skb.key";
          };

          requiredSystemFeatures = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional requiredSystemFeatures to add to derivations which make use of secure boot keys";
          };

          preSignCommands = lib.mkOption {
            type = types.lines;
            default = "";
            description = "Additional commands to run before performing operation that involve signing. Can be used to set up environment to interact with an external HSM.";
          };
        };

        # Firmware variants. For most normal usage, you shouldn't need to set this option
        variants = lib.mkOption {
          internal = true;
          type = types.listOf (types.submodule ({ config, name, ... }: {
            options = {
              boardid = lib.mkOption {
                type = types.str;
              };
              boardsku = lib.mkOption {
                type = types.str;
              };
              fab = lib.mkOption {
                type = types.str;
              };
              boardrev = lib.mkOption {
                type = types.str;
                default = "";
              };
              fuselevel = lib.mkOption {
                type = types.str; # TODO: Enum?
                default = "fuselevel_production";
              };
              chiprev = lib.mkOption {
                type = types.str;
                default = "";
              };
            };
          }));
        };
      };

      flashScriptOverrides = {
        targetBoard = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Target board to use when flashing (should match .conf in BSP package)";
        };

        configFileName = mkOption {
          type = types.str;
          default = cfg.flashScriptOverrides.targetBoard;
          description = "Name of configuration file to use when flashing (excluding .conf suffix).  Defaults to targetBoard";
        };

        flashArgs = mkOption {
          type = types.listOf types.str;
          description = "Arguments to apply to flashing script";
        };

        fuseArgs = mkOption {
          type = types.listOf types.str;
          description = "Arguments to apply to fusing script. DO NOT INCLUDE private files in fuseArgs (such as the odmfuse.xml file). Instead provide them at runtime on the command line";
        };

        partitionTemplate = mkOption {
          type = types.path;
          description = ".xml file describing partition template to use when flashing";
        };

        patches = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = "Patches to apply to the flash-tools";
        };

        postPatch = mkOption {
          type = types.lines;
          default = "";
          description = "Additional commands to run when building flash-tools";
        };

        additionalDtbOverlays = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = "A list of paths to compiled .dtbo files to include with the UEFI image while flashing. These overlays are applied by UEFI at runtime";
        };
      };

      flashScript = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Script to flash the xavier device";
      };

      devicePkgs = mkOption {
        type = types.attrsOf types.anything;
        readOnly = true;
        internal = true;
        description = "Flashing packages associated with this NixOS configuration";
      };
    };
  };

  config = {
    hardware.nvidia-jetpack.flashScript = lib.warn "hardware.nvidia-jetpack.flashScript is deprecated, use config.system.build.flashScript" config.system.build.flashScript;
    hardware.nvidia-jetpack.devicePkgs = (lib.mapAttrs (_: lib.warn "hardware.nvidia-jetpack.devicePkgs is deprecated, use pkgs.nvidia-jetpack") pkgs.nvidia-jetpack)
      // (lib.mapAttrs (name: lib.warn "hardware.nvidia-jetpack.devicePkgs.${name} is deprecated, use config.system.build.${name}") flashTools);

    system.build = {
      jetsonDevicePkgs = (lib.mapAttrs (_: lib.warn "system.build.jetsonDevicePkgs is deprecated, use pkgs.nvidia-jetpack") pkgs.nvidia-jetpack)
        // (lib.mapAttrs (name: lib.warn "system.build.jetsonDevicePkgs.${name} is deprecated, use config.system.build.${name}") flashTools);

      inherit (pkgs.nvidia-jetpack) uefiCapsuleUpdate;
      inherit (flashTools) flashScript initrdFlashScript fuseScript signedFirmware;
    };

    hardware.nvidia-jetpack.flashScriptOverrides.flashArgs = lib.mkAfter (
      lib.optional (cfg.firmware.secureBoot.pkcFile != null) "-u ${cfg.firmware.secureBoot.pkcFile}" ++
      lib.optional (cfg.firmware.secureBoot.sbkFile != null) "-v ${cfg.firmware.secureBoot.sbkFile}" ++
      [ cfg.flashScriptOverrides.configFileName "mmcblk0p1" ]
    );

    hardware.nvidia-jetpack.flashScriptOverrides.additionalDtbOverlays =
      let
        bootOrder = pkgs.runCommand "DefaultBootOrder.dtbo" { nativeBuildInputs = with pkgs.buildPackages; [ dtc ]; } ''
          export bootOrder=${lib.concatStringsSep "," cfg.firmware.bootOrder}
          substituteAll ${./uefi-boot-order.dts} keys.dts
          dtc -I dts -O dtb keys.dts -o $out
        '';
        uefiDefaultKeysDtbo = pkgs.runCommand "UefiDefaultSecurityKeys.dtbo" { nativeBuildInputs = with pkgs.buildPackages; [ dtc ]; } ''
          export pkDefault=$(od -t x1 -An "${cfg.firmware.uefi.secureBoot.defaultPkEslFile}")
          export kekDefault=$(od -t x1 -An "${cfg.firmware.uefi.secureBoot.defaultKekEslFile}")
          export dbDefault=$(od -t x1 -An "${cfg.firmware.uefi.secureBoot.defaultDbEslFile}")
          substituteAll ${./uefi-default-keys.dts} keys.dts
          dtc -I dts -O dtb keys.dts -o $out
        '';
      in
      (lib.optional (cfg.firmware.bootOrder != null) bootOrder) ++
      (lib.optional cfg.firmware.uefi.secureBoot.enrollDefaultKeys uefiDefaultKeysDtbo);

    hardware.nvidia-jetpack.flashScriptOverrides.fuseArgs = lib.mkAfter [ cfg.flashScriptOverrides.configFileName ];

    # These are from l4t_generate_soc_bup.sh, plus some additional ones found in the wild.
    hardware.nvidia-jetpack.firmware.variants =
      if (cfg.som != null) then
        (lib.mkOptionDefault (
          {
            xavier-agx = [
              { boardid = "2888"; boardsku = "0001"; fab = "400"; boardrev = "D.0"; fuselevel = "fuselevel_production"; chiprev = "2"; }
              { boardid = "2888"; boardsku = "0001"; fab = "400"; boardrev = "E.0"; fuselevel = "fuselevel_production"; chiprev = "2"; } # 16GB
              { boardid = "2888"; boardsku = "0004"; fab = "400"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = "2"; } # 32GB
              { boardid = "2888"; boardsku = "0005"; fab = "402"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = "2"; } # 64GB
            ];
            xavier-nx = [
              # Dev variant
              { boardid = "3668"; boardsku = "0000"; fab = "100"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = "2"; }
              { boardid = "3668"; boardsku = "0000"; fab = "301"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = "2"; }
            ];
            xavier-nx-emmc = [
              # Prod variant
              { boardid = "3668"; boardsku = "0001"; fab = "100"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = "2"; }
              { boardid = "3668"; boardsku = "0003"; fab = "301"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = "2"; }
            ];

            orin-agx = [
              { boardid = "3701"; boardsku = "0000"; fab = "300"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; }
              { boardid = "3701"; boardsku = "0004"; fab = "300"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # 32GB
              { boardid = "3701"; boardsku = "0005"; fab = "000"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # 64GB
            ];

            orin-agx-industrial = [
              { boardid = "3701"; boardsku = "0008"; fab = "300"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; }
            ];

            orin-nx = [
              { boardid = "3767"; boardsku = "0000"; fab = "000"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # Orin NX 16GB
              { boardid = "3767"; boardsku = "0001"; fab = "000"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # Orin NX 8GB
            ];

            orin-nano = [
              { boardid = "3767"; boardsku = "0003"; fab = "000"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # Orin Nano 8GB
              { boardid = "3767"; boardsku = "0004"; fab = "000"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # Orin Nano 4GB
              { boardid = "3767"; boardsku = "0005"; fab = "000"; boardrev = ""; fuselevel = "fuselevel_production"; chiprev = ""; } # Orin Nano devkit module
            ];
          }.${cfg.som}
        )) else lib.mkOptionDefault [ ];

    systemd.services.setup-jetson-efi-variables = lib.mkIf (cfg.flashScriptOverrides.targetBoard != null) {
      description = "Setup Jetson OTA UEFI variables";
      wantedBy = [ "multi-user.target" ];
      after = [ "opt-nvidia-esp.mount" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart = "${pkgs.nvidia-jetpack.otaUtils}/bin/ota-setup-efivars ${cfg.flashScriptOverrides.targetBoard}";
    };

    systemd.services.firmware-update = lib.mkIf (cfg.firmware.autoUpdate && cfg.som != null && cfg.flashScriptOverrides.targetBoard != null) {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.nvidia-jetpack.otaUtils ];
      after = [
        "${utils.escapeSystemdPath config.boot.loader.efi.efiSysMountPoint}.mount"
        "opt-nvidia-esp.mount"
      ];
      unitConfig = {
        ConditionPathExists = "/sys/devices/virtual/dmi/id/bios_version";
        # This directory is populated by ota-apply-capsule-update, don't run
        # if we already have a capsule update present on the ESP.
        ConditionDirectoryNotEmpty = "!${config.boot.loader.efi.efiSysMountPoint}/EFI/UpdateCapsule";
      };
      script =
        # NOTE: Our intention is to not apply any capsule update if the
        # user's intention is to "test" a new nixos config without having it
        # persist across reboots. "nixos-rebuild test" does not append a new
        # generation to /nix/var/nix/profiles for the system profile, so we
        # can compare that symlink to /run/current-system to see if our
        # current active config has been persisted as a generation. Note that
        # this check _may_ break down if not using nixos-rebuild and using
        # switch-to-configuration directly, however it is well-documented
        # that a user would need to self-manage their system profile's
        # generations if switching a system in that manner.
        lib.optionalString config.system.switch.enable ''
          if [[ -L /nix/var/nix/profiles/system ]]; then
            latest_generation=$(readlink -f /nix/var/nix/profiles/system)
            current_system=$(readlink -f /run/current-system)
            if [[ $latest_generation == /nix/store* ]] && [[ $latest_generation != "$current_system" ]]; then
              echo "Skipping capsule update, current active system not persisted to /nix/var/nix/profiles/system"
              exit 0
            fi
          fi
        '' + ''
          CUR_VER=$(cat /sys/devices/virtual/dmi/id/bios_version)
          NEW_VER=${pkgs.nvidia-jetpack.l4tVersion}

          if [[ "$CUR_VER" != "$NEW_VER" ]]; then
            echo "Current Jetson firmware version is: $CUR_VER"
            echo "New Jetson firmware version is: $NEW_VER"
            echo

            # Set efi vars here as well as in systemd service, in case we're
            # upgrading from an older nixos generation that doesn't have the
            # systemd service. Plus, this ota-setup-efivars will be from the
            # generation we're switching to, which can contain additional
            # fixes/improvements.
            ota-setup-efivars ${cfg.flashScriptOverrides.targetBoard}

            ota-apply-capsule-update ${pkgs.nvidia-jetpack.uefiCapsuleUpdate}
          fi
        '';
    };

    environment.systemPackages = lib.mkIf (cfg.firmware.autoUpdate && cfg.som != null && cfg.flashScriptOverrides.targetBoard != null) [
      (pkgs.writeShellScriptBin "ota-apply-capsule-update-included" ''
        ${pkgs.nvidia-jetpack.otaUtils}/bin/ota-apply-capsule-update ${pkgs.nvidia-jetpack.uefiCapsuleUpdate}
      '')
    ];
  };
}
