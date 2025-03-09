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
    public_key = tls_private_key.vm_ssh_key[each.key].public_key_openssh
  }
 
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
 os_disk {
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-${each.key}"
    caching              = "ReadWrite"
    disk_size_gb         =  64
  }
}