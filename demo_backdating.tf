resource "azurerm_network_security_group" "demo_backdating_nsg" {
  name                = "demo-backdating-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.sn_tf_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_storage_account" "demo_backdating_storage" {
  name                     = "demobackdatingstorage"
  resource_group_name      = azurerm_resource_group.sn_tf_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_0"
}
