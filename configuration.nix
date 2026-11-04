{
  pkgs,
  ...
}:
{
  disko = {
    devices.disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
  
  system = {
    stateVersion = "26.05";
  };

  networking = {
    hostName = "homelab";
    firewall.allowedTCPPorts = [ 22 80 443 ];
  };

  # --- disk drivers in the initrd ---
  # NixOS' default initrd does NOT include virtio block drivers. Scaleway's
  # disk controller is virtio, so without this the kernel cannot find the root
  # filesystem and the machine never boots (stuck at "booting kernel").
  boot = {
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "sd_mod"
    ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  users = {
    mutableUsers = false;
    users = {
      "root" = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXU1ZD/EvrcltO3JMQ7HXNACLPk2AyYulutwqQI6Bda"
        ];
      };
      "lldap" = {
        isSystemUser = true;
        group = "lldap";
      };
    };
    groups = {
      "lldap" = {};
    };
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age = {
      sshKeyPaths = [];
      keyFile = "/var/lib/sops-nix/keys.txt";
      generateKey = false;
    };
    secrets = {
      "lldap/root/password" = {
        owner = "lldap";
        group = "lldap";
        mode = "0400";
        restartUnits = ["lldap.service"];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    helix
    git
    curl
    glances
    tree
  ];

  services = {

    openssh = {
      enable = true;
    };

    caddy = {
      enable = true;
      virtualHosts = {
        "homelab.elwinar.com" = {
          extraConfig = ''
            respond "Hello world!"
          '';
        };
        "lldap.elwinar.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:17170
          '';
        };
      };
    };

    lldap = {
      enable = true;
      settings = {
        ldap_host = "127.0.0.1";
        http_host = "127.0.0.1";
        http_port = 17170;
        http_url = "https://lldap.elwinar.com";
        ldap_base_dn = "dc=homelab";
        ldap_user_dn = "root";
        ldap_user_pass_file = "/run/secrets/lldap/root/password";
        force_ldap_user_pass_reset = "always";
      };
    };

  };
}
