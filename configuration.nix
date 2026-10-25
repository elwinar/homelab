{
  pkgs,
  ...
}:
{
  imports = [
    ./disko-config.nix
  ];

  system.stateVersion = "26.05";
  networking.hostName = "homelab";
  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXU1ZD/EvrcltO3JMQ7HXNACLPk2AyYulutwqQI6Bda"
  ];
  users.mutableUsers = false;

  # --- disk drivers in the initrd ---
  # NixOS' default initrd does NOT include virtio block drivers. Scaleway's
  # disk controller is virtio, so without this the kernel cannot find the root
  # filesystem and the machine never boots (stuck at "booting kernel").
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "sd_mod"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages = with pkgs; [
    helix
    git
    curl
    glances
  ];
}
