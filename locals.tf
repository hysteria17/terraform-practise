# 2. Локальные значения (Внутренняя логика)
locals {
  # Логика именования: project-env-vm
  vm_name = "rebrand-app-${var.env}-vm"

  # Логика прерываемости:
  # Если env == "prod", то прерываемость (preemptible) = false.
  # Иначе (для dev, stage и т.д.) = true.
  is_preemptible = var.env == "prod" ? false : true

  # Общие метки
  common_labels = {
    environment = var.env
    project     = "learning-terraform"
    cost_center = "training"
  }

  allowed_ports = [22, 80, 443, 8080]
}
