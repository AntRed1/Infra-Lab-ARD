# ─────────────────────────────────────────────
# SSH Key
# ─────────────────────────────────────────────
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${path.module}/minecraft_server_key.pem"
  file_permission = "0600"
}

# ─────────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project     = "Minecraft ARD"
    Environment = "gaming"
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────
# Networking
# ─────────────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_address_space]

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-${var.project_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH - restringido a IP del administrador
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_allowed_ip
    destination_address_prefix = "*"
  }

  # Minecraft Java Edition
  security_rule {
    name                       = "Allow-Minecraft-TCP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.minecraft_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Minecraft-UDP"
    priority                   = 111
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.minecraft_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Pterodactyl Panel - HTTPS
  security_rule {
    name                       = "Allow-Panel-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Pterodactyl Panel - HTTP
  security_rule {
    name                       = "Allow-Panel-HTTP"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Pterodactyl Wings - daemon HTTP
  security_rule {
    name                       = "Allow-Wings-HTTP"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.wings_http_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Pterodactyl Wings - SFTP
  security_rule {
    name                       = "Allow-Wings-SFTP"
    priority                   = 131
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.wings_sftp_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Terraria
  security_rule {
    name                       = "Allow-Terraria"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.terraria_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Rango de puertos para juegos adicionales gestionados por Wings
  security_rule {
    name                       = "Allow-GameServers-Range"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27000-27100"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ─────────────────────────────────────────────
# IP Publica Estatica
# ─────────────────────────────────────────────
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = azurerm_resource_group.rg.tags
}

# ─────────────────────────────────────────────
# Network Interface
# ─────────────────────────────────────────────
resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  tags = azurerm_resource_group.rg.tags
}

# ─────────────────────────────────────────────
# Virtual Machine
# ─────────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    name                 = "osdisk-${var.project_name}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    admin_username = var.admin_username
  }))

  tags = azurerm_resource_group.rg.tags
}

# ─────────────────────────────────────────────
# Auto-shutdown: 23:00 hora RD (UTC-4)
# ─────────────────────────────────────────────
resource "azurerm_dev_test_global_vm_shutdown_schedule" "auto_shutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  location           = azurerm_resource_group.rg.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = azurerm_resource_group.rg.tags
}

# ─────────────────────────────────────────────
# Inventario Ansible (generado automaticamente)
# ─────────────────────────────────────────────
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    vm_public_ip   = azurerm_public_ip.pip.ip_address
    admin_username = var.admin_username
    ssh_key_path   = abspath(local_sensitive_file.ssh_private_key.filename)
  })
  filename = "${path.module}/../ansible/inventory.ini"

  depends_on = [azurerm_linux_virtual_machine.vm]
}
