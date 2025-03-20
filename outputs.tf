output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "storage_container_name" {
  value = azurerm_storage_container.container.name
}

output "postgresql_server_name" {
  value = azurerm_postgresql_server.postgresql.name
}

output "flask_url" {
  value = "http://${azurerm_public_ip.public_ip.ip_address}:80"
  description = "Public URL to access the Flask application"
}
