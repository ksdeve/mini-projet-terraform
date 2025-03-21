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

  # Règle pour autoriser HTTP (déjà présente)
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

  # Règle pour autoriser SSH
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle pour autoriser le port 8080
  security_rule {
    name                       = "Allow8080"
    priority                   = 1002  # Priorité plus élevée que d'autres règles si nécessaire
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
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

# Change les permissions du fichier de log pour que azureuser puisse écrire dedans
echo "Modification des permissions du fichier setup.log..." 
sudo chmod 644 /home/azureuser/setup.log
sudo chown azureuser:azureuser /home/azureuser/setup.log

# Ajout des permissions d'écriture globales
sudo chmod 666 /home/azureuser/setup.log  # Ajout de cette ligne pour donner des permissions d'écriture à tous

# Maintenant, commence l'écriture dans le fichier de log
echo "Début du script d'installation..." > /home/azureuser/setup.log 2>&1

# Met à jour les paquets
echo "Mise à jour des paquets..." >> /home/azureuser/setup.log 2>&1
sudo apt update -y >> /home/azureuser/setup.log 2>&1
sudo apt upgrade -y >> /home/azureuser/setup.log 2>&1

# Installe les dépendances nécessaires
echo "Installation de git, Python, pip, etc." >> /home/azureuser/setup.log 2>&1
sudo apt install -y python3-pip python3-venv postgresql libpq-dev git >> /home/azureuser/setup.log 2>&1

# Créer un utilisateur dédié pour l'exécution de l'application
echo "Création de l'utilisateur flaskuser..." >> /home/azureuser/setup.log 2>&1
sudo useradd -m flaskuser >> /home/azureuser/setup.log 2>&1
sudo passwd -d flaskuser >> /home/azureuser/setup.log 2>&1
sudo usermod -aG sudo flaskuser >> /home/azureuser/setup.log 2>&1

# Passer à l'utilisateur flaskuser pour continuer
echo "Passage à l'utilisateur flaskuser..." >> /home/azureuser/setup.log 2>&1
sudo -u flaskuser bash
  # Passer dans le répertoire home de flaskuser
  echo "Changement de répertoire dans /home/flaskuser..." >> /home/azureuser/setup.log 2>&1
  cd /home/flaskuser

  # Cloner le dépôt Git contenant l'application Flask
  echo "Clonage du dépôt Git..." >> /home/azureuser/setup.log 2>&1
  git clone https://ksdeve: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@github.com/ksdeve/mini-projet-terraform.git mini-projet-terraform >> /home/azureuser/setup.log 2>&1
  if [ $? -ne 0 ]; then
    echo "Erreur lors du clonage du dépôt Git." >> /home/azureuser/setup.log
    exit 1
  fi

  # Créer un environnement virtuel Python
  echo "Création de l'environnement virtuel Python..." >> /home/azureuser/setup.log 2>&1
  python3 -m venv /home/flaskuser/mini-projet-terraform/venv >> /home/azureuser/setup.log 2>&1
  if [ $? -ne 0 ]; then
    echo "Erreur lors de la création de l'environnement virtuel." >> /home/azureuser/setup.log
    exit 1
  fi

  # Activer l'environnement virtuel
  source /home/flaskuser/mini-projet-terraform/venv/bin/activate

  # Installer les dépendances Python depuis requirements.txt
  echo "Installation des dépendances Python..." >> /home/azureuser/setup.log 2>&1
  sudo chown flaskuser:flaskuser /home/flaskuser/mini-projet-terraform/flaskApp/requirements.txt
  pip install -r /home/flaskuser/mini-projet-terraform/flaskApp/requirements.txt >> /home/azureuser/setup.log 2>&1
  if [ $? -ne 0 ]; then
    echo "Erreur lors de l'installation des dépendances." >> /home/azureuser/setup.log
    exit 1
  fi

  # Créer le fichier .env avec les variables d'environnement
  echo "Création du fichier .env..." >> /home/azureuser/setup.log 2>&1
  echo "FLASK_APP=app.py" > /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "FLASK_ENV=development" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "DB_NAME=flaskdb" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "DB_USER=flaskadmin@flaskdbserver-2430c625a67eb8c4" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "DB_PASSWORD=MotDePasseDB456!" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "DB_HOST=flaskdbserver-2430c625a67eb8c4.postgres.database.azure.com" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "DB_PORT=5432" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "STORAGE_ACCOUNT_NAME=flaskstorageacctaa9c9648" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "STORAGE_ACCOUNT_KEY=zjSTfq8pI0bdoxu+nvaNROWv+Khfaqz+kfrTcwpjOH94s9TURZTT6l1sRPfAosyHB/1oi8OpTb6G+AStiVIAkg==" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env
  echo "CONTAINER_NAME=flaskcontainer" >> /home/flaskuser/mini-projet-terraform/flaskApp/.env

  # Démarrer l'application Flask en arrière-plan
  echo "Démarrage de l'application Flask..." >> /home/azureuser/setup.log 2>&1
  nohup flask run --host=0.0.0.0 --port=8080 & >> /home/azureuser/setup.log 2>&1
  if [ $? -ne 0 ]; then
    echo "Erreur lors du démarrage de Flask." >> /home/azureuser/setup.log
    exit 1
  else
    echo "Flask démarré avec succès." >> /home/azureuser/setup.log
  fi
EOSU
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

resource "azurerm_postgresql_firewall_rule" "allow_postgresql" {
  name                = "AllowMyPostgresql"
  server_name         = azurerm_postgresql_server.postgresql.name
  resource_group_name = azurerm_resource_group.rg.name
  start_ip_address    = "0.0.0.0"  # Autorise toutes les adresses (remplacer par des IP spécifiques pour plus de sécurité)
  end_ip_address      = "255.255.255.255"  # Autorise toutes les adresses
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