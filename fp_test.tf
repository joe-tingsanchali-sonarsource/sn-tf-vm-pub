resource "azurerm_network_security_group" "fp_test_nsg" {
  name                = "fp-test-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.sn_tf_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
