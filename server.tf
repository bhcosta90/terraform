provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_ssh_key" "this" {
  name       = "${var.server_name}-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "digitalocean_droplet" "this" {
  name   = var.server_name
  region = var.region
  size   = var.droplet_size
  image  = "ubuntu-22-04-x64"

  ssh_keys = [digitalocean_ssh_key.this.id]
  tags = ["laravel", "shared"]
}
