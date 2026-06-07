variable "location" {
  description = "Region de Azure donde se desplegara la infraestructura"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-minecraft-ard"
}

variable "project_name" {
  description = "Prefijo usado para nombrar todos los recursos"
  type        = string
  default     = "minecraft-ard"
}

variable "vm_size" {
  description = "SKU de la maquina virtual"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Usuario administrador de la VM"
  type        = string
  default     = "localadmin"
}

variable "os_disk_size_gb" {
  description = "Tamano del disco del sistema operativo en GB"
  type        = number
  default     = 128
}

variable "vnet_address_space" {
  description = "Espacio de direcciones de la VNet"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_address_prefix" {
  description = "CIDR de la subnet principal"
  type        = string
  default     = "10.10.1.0/24"
}

variable "minecraft_port" {
  description = "Puerto del servidor Minecraft Java Edition"
  type        = number
  default     = 25565
}

variable "wings_http_port" {
  description = "Puerto HTTP del daemon Pterodactyl Wings"
  type        = number
  default     = 8080
}

variable "wings_sftp_port" {
  description = "Puerto SFTP gestionado por Pterodactyl Wings"
  type        = number
  default     = 2022
}

variable "terraria_port" {
  description = "Puerto del servidor Terraria"
  type        = number
  default     = 7777
}

variable "timezone" {
  description = "Zona horaria del servidor (formato IANA, usado en Docker)"
  type        = string
  default     = "America/Santo_Domingo"
}

variable "ssh_allowed_ip" {
  description = "IP publica autorizada para acceso SSH (solo tu IP)"
  type        = string
  default     = "148.255.202.16"
}

variable "auto_shutdown_time" {
  description = "Hora de apagado automatico diario (formato HHMM, hora local RD)"
  type        = string
  default     = "2300"
}

variable "auto_shutdown_timezone" {
  description = "Zona horaria para el apagado automatico (formato Windows)"
  type        = string
  default     = "SA Western Standard Time"
}
