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
  ttl      = 60
}

moved {
  from = scaleway_instance_server.this
  to   = scaleway_instance_server.homelab
}
resource "scaleway_instance_server" "homelab" {
  type  = "DEV1-S"
  name  = "homelab"
  image = "ubuntu_jammy"
  ip_id = scaleway_instance_ip.homelab.id
}

