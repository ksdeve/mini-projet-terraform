variable "resource_group_name" {
  default = "FlaskRG"
}

variable "location" {
  default = "East US"
}

variable "vm_name" {
  default = "FlaskVMKevinS"
}

variable "vm_size" {
  default = "Standard_B2s"  # 2 CPU, 4 Go RAM
}

variable "admin_username" {
  default = "azureuser"
}

variable "admin_password" {
  description = "Password for the VM admin user"
  sensitive   = true
}
variable "storage_account_name" {
  default = "flaskstorageacct"
}

variable "container_name" {
  default = "flaskcontainer"
}

variable "db_name" {
  default = "flaskdb"
}

variable "db_username" {
  default = "flaskadmin"
}

variable "db_password" {
  description = "Password for the PostgreSQL admin user"
  sensitive   = true
}
variable "db_version" {
  default = "11"  # PostgreSQL version
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}