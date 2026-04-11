# 1. Входная переменная
variable "env" {
  description = "Environment type: dev or prod"
  type        = string
  default     = "dev" 
  # Попробуйте поменять на "prod" при запуске
}

variable "virtual_machines" {
  description = "Map of VMs with their specific configuration"
  type = map(object({
    cores  = number
    memory = number
  }))
  default = {
    "db" = {
      cores  = 4
      memory = 4
    }
    "app" = {
      cores  = 2
      memory = 2
    }
    "cache" = {
      cores  = 2
      memory = 1 # Redis-у много не надо для теста
    }
  }
}
