<!-- Header -->
<div align="center">

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              I N F R A - L A B - A R D                   ║
║         Servidor de Juegos Privado en Azure              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

![Terraform](https://img.shields.io/badge/Terraform-≥_1.5-7B42BC?style=flat-square&logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?style=flat-square&logo=microsoftazure&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Playbook-EE0000?style=flat-square&logo=ansible&logoColor=white)
![Pterodactyl](https://img.shields.io/badge/Pterodactyl-Panel-4b8df8?style=flat-square&logoColor=white)

Infraestructura como código para un servidor de juegos privado en Azure.<br>
Panel web de administración global con soporte para **Minecraft**, **Terraria**<br>
y cualquier juego futuro mediante eggs de Pterodactyl.

</div>

---

## Contenido

- [Arquitectura](#arquitectura)
- [Recursos Azure](#recursos-azure)
- [Requisitos](#requisitos)
- [Despliegue](#despliegue)
- [Configuracion de Wings](#configuracion-de-wings-paso-manual)
- [Agregar servidores de juego](#agregar-servidores-de-juego)
- [Conectarse a los juegos](#conectarse-a-los-juegos)
- [Agregar nuevos juegos](#agregar-nuevos-juegos)
- [Variables de configuracion](#variables-de-configuracion)
- [Comandos utiles](#comandos-utiles)
- [Seguridad](#seguridad)
- [Costos estimados](#costos-estimados)
- [Destruir la infraestructura](#destruir-la-infraestructura)

---

## Arquitectura

```
                              INTERNET
                                 │
                       ┌─────────▼──────────┐
                       │   IP Pública       │
                       │   Estática (SKU    │
                       │   Standard)        │
                       └─────────┬──────────┘
                                 │
                       ┌─────────▼──────────┐
                       │   NSG (Firewall)   │
                       │                    │
                       │  :22   ──► admin   │  ← Solo tu IP
                       │  :80   ──► todos   │  ← Panel web HTTP
                       │  :443  ──► todos   │  ← Panel web HTTPS
                       │  :8080 ──► todos   │  ← Wings daemon
                       │  :2022 ──► todos   │  ← Wings SFTP
                       │  :25565 ──► todos  │  ← Minecraft
                       │  :7777 ──► todos   │  ← Terraria
                       └─────────┬──────────┘
                                 │
            ┌────────────────────▼────────────────────┐
            │         VNet: 10.10.0.0/16              │
            │                                         │
            │   ┌─────────────────────────────────┐   │
            │   │    Subnet: 10.10.1.0/24         │   │
            │   │                                 │   │
            │   │  ┌──────────────────────────┐   │   │
            │   │  │  VM: Standard_B2ms       │   │   │
            │   │  │  Ubuntu 24.04 LTS        │   │   │
            │   │  │  Disco: 128 GB Std SSD   │   │   │
            │   │  │  RAM: 8 GB             │   │   │
            │   │  │                          │   │   │
            │   │  │  ┌────────────────────┐  │   │   │
            │   │  │  │  Docker            │  │   │   │
            │   │  │  │                    │  │   │   │
            │   │  │  │  pterodactyl_panel │  │   │   │
            │   │  │  │  ├── :80 / :443    │  │   │   │
            │   │  │  │  │   Panel web     │  │   │   │
            │   │  │  │  │                 │  │   │   │
            │   │  │  │  pterodactyl_mysql │  │   │   │
            │   │  │  │  pterodactyl_redis │  │   │   │
            │   │  │  │                    │  │   │   │
            │   │  │  │  pterodactyl_wings │  │   │   │
            │   │  │  │  ├── :8080 (HTTP)  │  │   │   │
            │   │  │  │  ├── :2022 (SFTP)  │  │   │   │
            │   │  │  │  │                 │  │   │   │
            │   │  │  │  │  Crea y gestiona│  │   │   │
            │   │  │  │  │  contenedores:  │  │   │   │
            │   │  │  │  │  ├── Minecraft  │  │   │   │
            │   │  │  │  │  ├── Terraria   │  │   │   │
            │   │  │  │  │  └── ...+juegos │  │   │   │
            │   │  │  └────────────────────┘  │   │   │
            │   │  │                          │   │   │
            │   │  │  Auto-shutdown: 23:00 RD │   │   │
            │   │  └──────────────────────────┘   │   │
            │   └─────────────────────────────────┘   │
            └─────────────────────────────────────────┘
```

### Flujo de comunicacion

```
Jugador                Panel Admin             Wings daemon
   │                       │                       │
   │  Minecraft :25565     │    HTTP :8080         │
   ├──────────────────────►│◄──────────────────────┤
   │                       │  Crea/detiene          │
   │  Terraria :7777        │  contenedores Docker   │
   ├──────────────────────►│                        │
   │                       │  Gestiona archivos     │
   │                       │  via SFTP :2022        │
```

---

## Recursos Azure

| Recurso                   | Nombre                    | Detalle                          |
|---------------------------|---------------------------|----------------------------------|
| Resource Group            | `rg-minecraft-ard`        | Contenedor de todos los recursos |
| Virtual Network           | `vnet-minecraft-ard`      | `10.10.0.0/16`                   |
| Subnet                    | `snet-minecraft-ard`      | `10.10.1.0/24`                   |
| Network Security Group    | `nsg-minecraft-ard`       | SSH, Panel, Wings, juegos        |
| Public IP                 | `pip-minecraft-ard`       | Estática, SKU Standard           |
| Network Interface         | `nic-minecraft-ard`       | NIC de la VM                     |
| Virtual Machine           | `vm-minecraft-ard`        | Standard_B2ms (2 vCPU, 8 GB RAM) |
| OS Disk                   | `osdisk-minecraft-ard`    | 128 GB StandardSSD_LRS           |
| Auto-shutdown Schedule    | *(dev test schedule)*     | Diario 23:00 hora RD             |

---

## Requisitos

| Herramienta | Version minima | Instalacion                              |
|-------------|----------------|------------------------------------------|
| Terraform   | >= 1.5.0       | [developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads) |
| Ansible     | >= 2.14        | `pip install ansible`                    |
| Azure CLI   | >= 2.50        | [aka.ms/installazurecli](https://aka.ms/installazurecli) |
| Python      | >= 3.10        | [python.org](https://python.org)         |

> [!NOTE]
> Asegurate de tener una suscripcion activa en Azure y permisos de `Contributor` o superiores.

---

## Despliegue

### 1 — Autenticarse en Azure

```bash
az login
az account set --subscription "<TU_SUBSCRIPTION_ID>"
```

### 2 — Configurar variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars — especialmente admin_password y db_password
```

### 3 — Inicializar y aplicar Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Al finalizar, Terraform muestra:

```
Outputs:

public_ip_address      = "X.X.X.X"
web_panel_url          = "http://X.X.X.X"
minecraft_connection   = "X.X.X.X:25565"
terraria_connection    = "X.X.X.X:7777"
ssh_connection_command = "ssh -i terraform/minecraft_server_key.pem localadmin@X.X.X.X"
```

### 4 — Configurar el servidor con Ansible

```bash
cd ansible
ansible-playbook playbook.yml
```

Ansible instala Docker, despliega Pterodactyl Panel + MySQL + Redis y crea el usuario administrador.
Al finalizar muestra las credenciales y los proximos pasos en pantalla.

> [!TIP]
> Si el playbook falla por timeout en el paso de esperar al Panel, la VM sigue inicializando. Espera 2 minutos y vuelve a ejecutarlo.

---

## Configuracion de Wings (paso manual)

Wings es el daemon que crea y gestiona los contenedores de cada juego. Requiere un paso de configuracion manual en el Panel antes de iniciar.

### 1 — Acceder al Panel

```
http://<IP_PUBLICA>
```

| Campo      | Valor del playbook    |
|------------|-----------------------|
| Usuario    | `admin`               |
| Contraseña | valor de `admin_password` en `playbook.yml` |

> [!WARNING]
> **Cambia la contraseña inmediatamente** desde el menu de usuario → `Account Settings`.

### 2 — Crear Location

```
Admin Panel → Locations → Create New
  Short Code: RD
  Description: Republica Dominicana
```

### 3 — Crear Node

```
Admin Panel → Nodes → Create New
  Name:             ARD Game Server
  FQDN:             <IP_PUBLICA>       (sin https://)
  Communicate over SSL: OFF            (sin dominio, usamos HTTP)
  Behind Proxy:     OFF
  Memory:           6144 MB            (6 GB para juegos, 2 GB para Panel+Wings)
  Memory Overallocate: 0
  Disk:             90000 MB           (90 GB para mundos y archivos)
  Disk Overallocate: 0
  Daemon Port:      8080
  Daemon SFTP Port: 2022
```

### 4 — Obtener y aplicar la configuracion de Wings

Una vez creado el nodo, ve a **Configuration** tab y copia el contenido YAML. Luego:

```bash
# Conectarse a la VM
ssh -i terraform/minecraft_server_key.pem localadmin@<IP_PUBLICA>

# Pegar la configuracion de Wings
sudo nano /etc/pterodactyl/config.yml
# Pegar el contenido copiado del Panel y guardar (Ctrl+O, Ctrl+X)

# Iniciar Wings
cd /opt/gameserver
docker compose --profile wings up -d wings

# Verificar que Wings se conecto al Panel
docker logs pterodactyl_wings -f
# Debe mostrar "Pterodactyl Wings is now running..."
```

### 5 — Verificar el nodo en el Panel

```
Admin Panel → Nodes → <tu nodo> → tabla de estadisticas verde = Wings conectado
```

---

## Agregar servidores de juego

Con Wings activo, crea servidores desde el Panel:

```
Admin Panel → Servers → Create New Server
```

### Minecraft Java Edition

| Campo           | Valor recomendado                     |
|-----------------|---------------------------------------|
| Server Name     | `Minecraft ARD`                       |
| Owner           | `admin`                               |
| Nest            | `Minecraft`                           |
| Egg             | `Paper` (mejor rendimiento + plugins) |
| Node            | `ARD Game Server`                     |
| Allocation      | `<IP>:25565`                          |
| Memory Limit    | `2048 MB`                             |
| Disk Space      | `10000 MB`                            |
| Minecraft Ver.  | `LATEST`                              |

### Terraria

| Campo           | Valor recomendado                     |
|-----------------|---------------------------------------|
| Server Name     | `Terraria ARD`                        |
| Owner           | `admin`                               |
| Nest            | `Voice Servers` → buscar Terraria     |
| Egg             | `Terraria` (importar si no aparece)   |
| Node            | `ARD Game Server`                     |
| Allocation      | `<IP>:7777`                           |
| Memory Limit    | `512 MB`                              |
| Disk Space      | `5000 MB`                             |

> [!NOTE]
> Si el egg de Terraria no aparece en la lista, importalo desde el repositorio oficial de eggs de Pterodactyl en GitHub.

---

## Conectarse a los juegos

### Minecraft Java Edition

```
Launcher → Multijugador → Agregar Servidor
  IP:     <IP_PUBLICA>
  Puerto: 25565
```

### Terraria

```
Menu principal → Multijugador → Unirse via IP
  IP:     <IP_PUBLICA>
  Puerto: 7777
```

---

## Agregar nuevos juegos

Pterodactyl tiene un repositorio de "eggs" para instalar nuevos juegos en minutos, sin tocar la infraestructura.

### Proceso general

1. Busca el egg del juego en [github.com/parkervcp/eggs](https://github.com/parkervcp/eggs)
2. En el Panel: `Admin → Nests → Import Egg` → pega la URL del JSON
3. Agrega una nueva Allocation con el puerto del juego
4. Crea el servidor desde `Admin → Servers → Create New`
5. Abre el puerto en el NSG de Azure (un `terraform apply` con la nueva regla)

### Juegos populares con egg disponible

| Juego           | Puerto por defecto |
|-----------------|--------------------|
| Valheim         | 2456               |
| CS2             | 27015              |
| Rust            | 28015              |
| ARK             | 7777               |
| Project Zomboid | 16261              |
| Factorio        | 34197              |
| Satisfactory    | 7777               |

---

## Variables de configuracion

| Variable                | Por defecto                  | Descripcion                              |
|-------------------------|------------------------------|------------------------------------------|
| `location`              | `eastus`                     | Region de Azure                          |
| `resource_group_name`   | `rg-minecraft-ard`           | Nombre del Resource Group                |
| `project_name`          | `minecraft-ard`              | Prefijo de todos los recursos            |
| `vm_size`               | `Standard_B2ms`              | SKU de la maquina virtual (8 GB RAM)     |
| `admin_username`        | `localadmin`                 | Usuario SSH de la VM                     |
| `os_disk_size_gb`       | `128`                        | Tamano del disco en GB                   |
| `vnet_address_space`    | `10.10.0.0/16`               | CIDR de la VNet                          |
| `subnet_address_prefix` | `10.10.1.0/24`               | CIDR de la subnet                        |
| `minecraft_port`        | `25565`                      | Puerto del servidor Minecraft            |
| `terraria_port`         | `7777`                       | Puerto del servidor Terraria             |
| `wings_http_port`       | `8080`                       | Puerto HTTP del daemon Wings             |
| `wings_sftp_port`       | `2022`                       | Puerto SFTP gestionado por Wings         |
| `timezone`              | `America/Santo_Domingo`      | Zona horaria Docker (IANA)               |
| `ssh_allowed_ip`        | `148.255.202.16`             | IP autorizada para SSH                   |
| `auto_shutdown_time`    | `2300`                       | Hora de apagado automatico (HHMM)        |
| `auto_shutdown_timezone`| `SA Western Standard Time`   | Zona horaria para auto-shutdown          |

---

## Comandos utiles

### Conectarse a la VM

```bash
terraform -chdir=terraform output -raw ssh_private_key > terraform/minecraft_server_key.pem
chmod 600 terraform/minecraft_server_key.pem
ssh -i terraform/minecraft_server_key.pem localadmin@<IP_PUBLICA>
```

### Gestionar los servicios en la VM

```bash
# Ver todos los contenedores (Panel + Wings + juegos)
docker ps

# Logs del Panel
docker logs pterodactyl_panel -f

# Logs de Wings (incluye logs de inicio de juegos)
docker logs pterodactyl_wings -f

# Reiniciar solo el Panel
docker restart pterodactyl_panel

# Reiniciar toda la infraestructura base
cd /opt/gameserver && docker compose restart

# Iniciar Wings (tras configurar el nodo)
cd /opt/gameserver && docker compose --profile wings up -d wings

# Ver uso de recursos
docker stats
```

### Encender la VM tras el auto-shutdown

```bash
az vm start --resource-group rg-minecraft-ard --name vm-minecraft-ard
```

---

## Seguridad

| Estado | Medida                                                         |
|--------|----------------------------------------------------------------|
| ✓      | SSH restringido a IP del administrador (`148.255.202.16`)      |
| ✓      | Autenticacion por clave SSH RSA-4096 (sin contraseña)          |
| ✓      | Limites de memoria por contenedor (MySQL 512m, Redis 128m)     |
| ✓      | Auto-shutdown diario a las 23:00 hora RD                       |
| ✗      | Cambiar contraseña del Panel al primer acceso                  |
| ✗      | Cambiar `admin_password` y `db_password` en `playbook.yml`     |
| ✗      | Configurar backups de mundos desde el Panel de Pterodactyl     |
| ✗      | Revisar `ssh_allowed_ip` si cambia tu IP publica               |

---

## Costos estimados

> Precios orientativos en region `eastus` (USD/mes).

| Recurso                           | Costo aprox.  |
|-----------------------------------|---------------|
| VM Standard_B2ms (24/7)           | ~$42.00       |
| VM Standard_B2ms (auto-shutdown ~8h/dia) | ~$14.00 |
| Disco OS 128 GB StandardSSD       | ~$11.00       |
| IP Publica Estatica Standard      | ~$4.00        |
| **Total (sin auto-shutdown)**     | **~$57/mes**  |
| **Total (con auto-shutdown)**     | **~$29/mes**  |

> [!TIP]
> El auto-shutdown esta configurado para las 23:00 RD. Enciende la VM antes de jugar con `az vm start --resource-group rg-minecraft-ard --name vm-minecraft-ard` o desde el portal de Azure.

---

## Destruir la infraestructura

> [!CAUTION]
> Esto **elimina permanentemente** la VM, la IP y todos los mundos almacenados. Haz un backup de los servidores desde el Panel de Pterodactyl antes de continuar.

```bash
cd terraform
terraform destroy
```

---

## Estructura del repositorio

```
Infra-Lab-ARD/
│
├── terraform/                        # Infraestructura en Azure
│   ├── providers.tf                  # Proveedor AzureRM + versiones
│   ├── main.tf                       # VM, VNet, NSG, IP, SSH key, auto-shutdown
│   ├── variables.tf                  # Variables configurables
│   ├── outputs.tf                    # IP, URL panel, comandos SSH
│   ├── terraform.tfvars.example      # Plantilla de configuracion
│   └── templates/
│       ├── cloud-init.yml.tpl        # Bootstrap: instala Docker al arranque
│       └── inventory.ini.tpl         # Genera el inventario de Ansible
│
├── ansible/                          # Configuracion del servidor
│   ├── ansible.cfg
│   ├── playbook.yml                  # Instala Docker, despliega Pterodactyl
│   └── templates/
│       └── docker-compose.yml.j2     # Panel + MySQL + Redis + Wings
│
├── .gitignore
└── README.md
```

---

<div align="center">

Desplegado con Terraform · Configurado con Ansible · Contenedores Docker · Pterodactyl Panel

</div>
