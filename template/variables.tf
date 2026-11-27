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
  default = "ubuntu-2404-lts"
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "ssh_user" {
  type    = string
  default = "user1"
}

variable "ssh_public_key" {
  type = string
}
