# modules/compute_vm/outputs.tf

output "instance_name" {
  description = "Имя созданной виртуальной машины"
  value       = yandex_compute_instance.this.name
}

output "public_ip" {
  description = "Публичный IP адрес виртуальной машины"
  value       = yandex_compute_instance.this.network_interface[0].nat_ip_address
}

output "internal_ip" {
  description = "Внутренний IP адрес виртуальной машины"
  value       = yandex_compute_instance.this.network_interface[0].ip_address
}
