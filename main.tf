terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

variable "do_token" {}
variable "ssh_key_id" {}

# Master node (4 GB)
resource "digitalocean_droplet" "master" {
  name     = "k8s-master"
  region   = "sgp1"
  size     = "s-2vcpu-4gb"
  image    = "ubuntu-22-04-x64"
  ssh_keys = [var.ssh_key_id]
}

# Worker nodes (2 GB each)
resource "digitalocean_droplet" "worker" {
  count    = 2
  name     = "k8s-worker-${count.index + 1}"
  region   = "sgp1"
  size     = "s-1vcpu-2gb"
  image    = "ubuntu-22-04-x64"
  ssh_keys = [var.ssh_key_id]
}

output "master_ip" {
  value = digitalocean_droplet.master.ipv4_address
}

output "worker_ips" {
  value = [for w in digitalocean_droplet.worker : w.ipv4_address]
}
