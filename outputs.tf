# 5. Выводим данные, которые нам понадобятся для настройки бэкенда
output "access_key" {
  value = yandex_iam_service_account_static_access_key.sa_static_key.access_key
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  sensitive = true # Terraform скроет это значение в консоли по умолчанию
}

output "bucket_name" {
  value = yandex_storage_bucket.state_storage.bucket
}

# Блок output поможет нам проверить, что именно нашёл Terraform
output "current_image_id" {
  value = data.yandex_compute_image.ubuntu_latest.id
}

# # Вывод для проверки
# output "vm_status" {
#   value = "VM '${yandex_compute_instance.vm.name}' created. Preemptible: ${yandex_compute_instance.vm.scheduling_policy[0].preemptible}"
# }

# # Вывод IP-адресов всех созданных машин
# output "cluster_ips" {
#   # Синтаксис со звездочкой [*] позволяет получить список значений для всех копий
#   value = yandex_compute_instance.web_cluster[*].network_interface.0.nat_ip_address
# }

# outputs.tf (в корне проекта)

output "frontend_public_ip" {
  description = "Публичный IP адрес Frontend сервера"
  value       = module.frontend.public_ip
}

output "backend_public_ip" {
  description = "Публичный IP адрес Backend сервера"
  value       = module.backend.public_ip
}

output "connection_string_frontend" {
  description = "Строка для подключения по SSH"
  value       = "ssh ubuntu@${module.frontend.public_ip}"
}
