# modules/compute_vm/variables.tf

variable "name" {
  description = "Имя виртуальной машины (и префикс для связанных ресурсов)"
  type        = string
}

variable "zone" {
  description = "Зона доступности Yandex Cloud (например, ru-central1-a)"
  type        = string
  default     = "ru-central1-a" # Значение по умолчанию
}

variable "network_id" {
  description = "ID сети (VPC), в которой будет работать ВМ"
  type        = string
}

variable "subnet_id" {
  description = "ID подсети, к которой будет подключен сетевой интерфейс"
  type        = string
}

variable "image_id" {
  description = "ID образа загрузочного диска (по умолчанию Ubuntu 24.04)"
  type        = string
  default     = "fd8lcd9f54ldmonh1d72" # Пример ID образа Ubuntu 24.04 LTS
}

variable "ssh_key" {
  description = "Публичный SSH ключ для пользователя ubuntu"
  type        = string
  sensitive   = true # Помечаем как чувствительные данные (скроет значение в логах)
}
