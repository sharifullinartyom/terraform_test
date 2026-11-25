variable "project_id" {
  type        = string
  description = "Идентификатор проекта из console.cloud.ru"
  default     = ""
}

variable "auth_key_id" {
  type        = string
  description = "Идентификатор ключа доступа сервисного аккаунта"
  sensitive   = true
  default     = ""
}

variable "auth_secret" {
  type        = string
  description = "Секрет ключа доступа сервисного аккаунта"
  sensitive   = true
  default     = ""
}

variable "my_ip_cidr" {
  type        = string
  description = "CIDR вашего IP-адреса для доступа по SSH"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "Идентификатор VPC"
  default     = ""
}

variable "subnet_address" {
  type        = string
  description = "CIDR подсети"
  default     = ""
}

variable "vm_name" {
  type        = string
  description = "Название виртуальной машины"
  default     = "tf-evo-vm"
}

variable "user_password" {
  type        = string
  description = "Пароль пользователя виртуальной машины"
  sensitive   = true
  nullable    = false
}

variable "ssh_public_key_path" {
  type        = string
  description = "Путь к публичному SSH ключу"
  default     = "./id_ed25519.pub"
}

variable "disk_size" {
  type        = number
  description = "Размер диска в ГБ"
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Тип диска"
  default     = "SSD"
}

variable "flavor" {
  type        = string
  description = "Флейвор ВМ"
  default     = "gen-1-1"
}

variable "zone" {
  type        = string
  description = "Зона доступности"
  default     = "ru.AZ-2"
}
