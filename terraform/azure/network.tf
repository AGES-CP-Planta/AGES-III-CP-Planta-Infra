module "security_rules" {
  source = "../modules/common/security-rules"
  environment_name = var.resource_group_name
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${module.security_rules.environment_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Dynamically create TCP security rules
  dynamic "security_rule" {
    for_each = module.security_rules.tcp_rules_with_priority
    content {
      name                       = "allow-${security_rule.value.name}"
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # Dynamically create UDP security rules
  dynamic "security_rule" {
    for_each = module.security_rules.udp_rules_with_priority
    content {
      name                       = "allow-${security_rule.value.name}"
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
  
  security_rule {
    name                       = "allow-all-outbound"
    priority                   = 500  
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}