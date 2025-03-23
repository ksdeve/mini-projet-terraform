variable "resource_group_name" {
  description = "Le nom du groupe de ressources Azure à créer"
  default     = "FlaskRG"
}

variable "location" {
  description = "La région Azure où les ressources seront déployées"
  default     = "East US"
}

variable "vm_name" {
  description = "Le nom de la machine virtuelle"
  default     = "FlaskVMKevinS"
}

variable "vm_size" {
  description = "La taille de la machine virtuelle (par exemple, nombre de CPU, RAM)"
  default     = "Standard_B2s"  # 2 CPU, 4 Go RAM
}

variable "admin_username" {
  description = "Le nom d'utilisateur administrateur pour la machine virtuelle"
  default     = "azureuser"
}

variable "admin_password" {
  description = "Mot de passe pour l'utilisateur administrateur de la machine virtuelle"
  sensitive   = true
}

variable "storage_account_name" {
  description = "Le nom du compte de stockage"
  default     = "flaskstorageacct"
}

variable "container_name" {
  description = "Le nom du conteneur Blob dans le compte de stockage"
  default     = "flaskcontainer"
}

variable "db_name" {
  description = "Le nom de la base de données PostgreSQL"
  default     = "flaskdb"
}

variable "db_username" {
  description = "Le nom d'utilisateur administrateur de la base de données PostgreSQL"
  default     = "flaskadmin"
}

variable "db_password" {
  description = "Mot de passe pour l'utilisateur administrateur de la base de données PostgreSQL"
  sensitive   = true
}

variable "db_version" {
  description = "La version de PostgreSQL à utiliser"
  default     = "11"  # Version de PostgreSQL
}

variable "subscription_id" {
  description = "L'ID de l'abonnement Azure"
  type        = string
}
