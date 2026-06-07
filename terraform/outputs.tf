output "public_ip_address" {
  description = "IP publica estatica del servidor de juegos"
  value       = azurerm_public_ip.pip.ip_address
}

output "web_panel_url" {
  description = "URL del panel de administracion Pterodactyl"
  value       = "http://${azurerm_public_ip.pip.ip_address}"
}

output "minecraft_connection" {
  description = "Direccion para conectarse a Minecraft (configurada en el Panel)"
  value       = "${azurerm_public_ip.pip.ip_address}:25565"
}

output "terraria_connection" {
  description = "Direccion para conectarse a Terraria (configurada en el Panel)"
  value       = "${azurerm_public_ip.pip.ip_address}:7777"
}

output "ssh_connection_command" {
  description = "Comando SSH para conectarse a la VM"
  value       = "ssh -i terraform/minecraft_server_key.pem ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "ssh_private_key" {
  description = "Clave SSH privada (guardar en un lugar seguro)"
  value       = tls_private_key.ssh_key.private_key_openssh
  sensitive   = true
}

output "resource_group_name" {
  description = "Nombre del Resource Group creado"
  value       = azurerm_resource_group.rg.name
}

output "vm_name" {
  description = "Nombre de la VM"
  value       = azurerm_linux_virtual_machine.vm.name
}
