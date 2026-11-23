terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
  required_version = ">= 0.13"
}

provider "scaleway" {
  organization_id = "ebd41d30-2627-4c73-95a8-65a1e81a087d"
  project_id      = "ebd41d30-2627-4c73-95a8-65a1e81a087d"
  zone            = "fr-par-1"
  region          = "fr-par"
}

resource "scaleway_instance_ip" "homelab" {
}

resource "scaleway_domain_record" "homelab" {
  dns_zone = "elwinar.com"
  name     = "homelab"
  type     = "A"
  data     = scaleway_instance_ip.homelab.address
  ttl      = 3600
}

resource "scaleway_domain_record" "lldap" {
  dns_zone = "elwinar.com"
  name     = "lldap"
  type     = "A"
  data     = scaleway_instance_ip.homelab.address
  ttl      = 3600
}

resource "scaleway_domain_record" "mail" {
  dns_zone = "elwinar.com"
  name     = "mail"
  type     = "A"
  data     = scaleway_instance_ip.homelab.address
  ttl      = 3600
}

resource "scaleway_domain_record" "jellyfin" {
  dns_zone = "elwinar.com"
  name     = "jellyfin"
  type     = "A"
  data     = scaleway_instance_ip.homelab.address
  ttl      = 3600
}

resource "scaleway_domain_record" "mx" {
  dns_zone = "elwinar.com"
  name     = "@"
  type     = "MX"
  priority = 10
  data     = "mail.elwinar.com."
  ttl      = 3600
}

resource "scaleway_instance_security_group" "homelab" {
  name                    = "homelab"
  enable_default_security = false
  description             = "homelab security group"
  inbound_default_policy  = "accept"
}

resource "scaleway_instance_server" "homelab" {
  type              = "DEV1-S"
  name              = "homelab"
  image             = "ubuntu_jammy"
  ip_id             = scaleway_instance_ip.homelab.id
  security_group_id = scaleway_instance_security_group.homelab.id
}

