variable "do_token" {
  type      = string
  sensitive = true
}

variable "server_name" {
  type = string
}

variable "region" {
  default = "nyc1"
}

variable "droplet_size" {
  default = "s-2vcpu-4gb"
}

variable "allowed_ssh_ip" {
  type = string
}
