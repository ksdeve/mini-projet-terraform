resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "FlaskVNet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "FlaskSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "FlaskPublicIP"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"  # Utiliser "Static" au lieu de "Dynamic"
  sku                  = "Standard"  # SKU Standard
}

resource "azurerm_network_security_group" "nsg" {
  name                = "FlaskNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "FlaskNIC"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "FlaskNICConfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

 custom_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y python3-pip python3-venv postgresql

              # Créer un utilisateur pour exécuter l'application
              sudo useradd -m flaskuser
              sudo passwd -d flaskuser
              sudo usermod -aG sudo flaskuser

              # Passer à flaskuser
              sudo -i -u flaskuser bash << 'EOSU'

              # Créer un environnement virtuel
              cd /home/flaskuser
              python3 -m venv venv
              source venv/bin/activate
              pip install flask psycopg2

              # Créer l'application Flask
              echo "from flask import Flask
              import psycopg2

              app = Flask(__name__)

              @app.route('/')
              def hello():
                  return 'Hello, Flask with PostgreSQL on Azure!'

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=80)" > /home/flaskuser/app.py

              deactivate
              EOSU

              # Créer un service systemd pour Flask
              echo "[Unit]
              Description=Flask Application
              After=network.target

              [Service]
              User=flaskuser
              WorkingDirectory=/home/flaskuser
              ExecStart=/home/flaskuser/venv/bin/python3 /home/flaskuser/app.py
              Restart=always

              [Install]
              WantedBy=multi-user.target" | sudo tee /etc/systemd/system/flaskapp.service

              # Activer et démarrer le service
              sudo systemctl daemon-reload
              sudo systemctl enable flaskapp
              sudo systemctl start flaskapp
              EOF
)

}

resource "random_id" "storage_suffix" {
  byte_length = 4
}


resource "azurerm_storage_account" "storage" {
  name = "flaskstorageacct${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "random_id" "server_id" {
  byte_length = 8  # Génère un identifiant unique de 8 octets
}


resource "azurerm_postgresql_server" "postgresql" {
  name                         = "flaskdbserver-${random_id.server_id.hex}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = var.db_version
  administrator_login          = var.db_username
  administrator_login_password = var.db_password
  sku_name                     = "B_Gen5_1"
  storage_mb                   = 5120
  backup_retention_days        = 7

  # Configuration SSL corrigée
  ssl_enforcement_enabled = true  # Valeur correcte

  # Supprimer geo_redundant_backup (non supporté)
  # geo_redundant_backup = "Disabled"  # À supprimer
}


resource "azurerm_postgresql_database" "database" {
  name                = var.db_name
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgresql.name

  # Utiliser une valeur valide pour la collation
  collation            = "English_United States.1252"  # ou "en_US.utf8"

  charset             = "UTF8"  # C'est souvent recommandé de spécifier UTF8 pour le charset
}
