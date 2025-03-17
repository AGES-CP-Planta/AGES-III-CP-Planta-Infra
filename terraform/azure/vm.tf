module "ssh_keys" {
  source         = "../modules/common/ssh-keys"
  instance_names = var.vm_names
  keys_path      = "${path.module}/../../ssh_keys"
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = toset(var.vm_names)
  name                = each.key
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id,
  ]
  size               = "Standard_B2s"
  admin_username     = var.username
  disable_password_authentication = true
  
  admin_ssh_key {
    username   = var.username
    public_key = module.ssh_keys.public_keys[each.key]
  }
 
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble"
    sku       = "24_04-lts-gen2"
    version   = "latest"
  }
  
 os_disk {
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-${each.key}"
    caching              = "ReadWrite"
    disk_size_gb         =  64
  }
}