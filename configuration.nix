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

  systemd.services.stalwart-tls = {
    description = "Copy Caddy's mail cert into Stalwart's dir";
    wantedBy = [ "multi-user.target" ];
    after = [ "caddy.service" ];
    before = [ "stalwart.service" ];
    serviceConfig = {
      ExecStartPre = [
        ""
        "${pkgs.coreutils}/bin/install -d -m 0750 -o stalwart -g stalwart /var/lib/stalwart/tls"
      ];
      ExecStart = [
        ""
        ''
          ${pkgs.coreutils}/bin/install -m 0400 -o stalwart -g stalwart \
          /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/mail.elwinar.com/mail.elwinar.com.crt \
          /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/mail.elwinar.com/mail.elwinar.com.key \
          /var/lib/stalwart/tls/ \
        ''
      ];
      Restart = "on-failure";
      RestartSec = 10;
      # retry until the cert is issued, which may take a few seconds.
      StartLimitIntervalSec = 0;
    };
  };

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
        "mail.elwinar.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:8080
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

    stalwart = {
      enable = true;
      stateVersion = "26.05";
      openFirewall = true;
      credentials = {
        lldap_root_password = "/run/secrets/lldap/root/password";
      };
      settings = {
        server = {
          hostname = "mail.elwinar.com";
          listener = {
            smtp = {
              bind = ["0.0.0.0:25"];
              protocol = "smtp";
            };
            imap = {
              bind = ["0.0.0.0:993"];
              protocol = "imap";
              tls = {
                implicit = true;
              };
            };
            http = {
              bind = ["127.0.0.1:8080"];
              protocol = "http";
            };
          };
        };
        directory = {
          "ldap" = {
            type = "ldap";
            url = "ldap://127.0.0.1:3890";
            bind.dn = "uid=root,ou=people,dc=homelab";
            bind.secret = "%{file:/run/credentials/stalwart.service/lldap_root_password}%";
            base-dn = "ou=people,dc=homelab";

            filter.name = "(uid={user})";
            filter.email = "(|(mail={email})(mailAlias={email}))";

            attributes = {
              name = "uid";
              email = "mail";
              email-alias = [ "mailalias" ];
              # lldap doesn't expose the password hash, but stalwart needs a
              # secret to generate the webui auth token. remap the secret and
              # secret-changed so they are correctly used, the credentials
              # checking is done by binding anyway.
              secret = "uuid";
              "secret-changed" = "password_modified_date";
            };

            bind.auth.method = "template";
            bind.auth.template = "uid={user},ou=people,dc=homelab";
          };
        };
        storage.directory = "ldap";
        certificate = {
          "mail" = {
            cert = "%{file:/var/lib/stalwart/tls/mail.elwinar.com.crt}%";
            private-key = "%{file:/var/lib/stalwart/tls/mail.elwinar.com.key}%";
            default = true;
          };
        };
      };
    };

  };
}
