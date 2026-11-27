variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "vm_params" {
  type = map(object({
    cores   = number
    memory  = number
    disk_gb = number
  }))
  default = {
    builder  = { cores = 1, memory = 2, disk_gb = 20 }
    deployer = { cores = 1, memory = 2, disk_gb = 10 }
  }
}

variable "image_family" {
  type    = string
  default = "ubuntu-2004-lts"
}

variable "zone" {
  type    = string
  default = "ru-central1-d"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key" {
  type = string
}

variable "repo_url" {
  type    = string
  default = "https://github.com/sharifullinartyom/terraform_test.git"
}

variable "private_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519"
}
