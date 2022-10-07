terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# 1. Declaring Azure Provider
provider "azurerm" {
  features {}
}

# 2. Creating Resource Group for the machine.
resource "azurerm_resource_group" "rg-demoapp" {
  name     = "rg-demoapp"
  location = "West US 3"
}

# 3. Deploy Virtual Network
resource "azurerm_virtual_network" "vn-demoapp" {
  name                = "vn-demoapp"
  address_space       = ["10.30.0.0/24"]
  location            = azurerm_resource_group.rg-demoapp.location
  resource_group_name = azurerm_resource_group.rg-demoapp.name
}

# 4. Create Subnet
resource "azurerm_subnet" "subnet-demoapp" {
  name                 = "subnet-demoapp"
  resource_group_name  = azurerm_resource_group.rg-demoapp.name
  virtual_network_name = azurerm_virtual_network.vn-demoapp.name
  address_prefixes     = ["10.30.0.0/28"]
}

# 5. Deploy Public IP DemoAPP
resource "azurerm_public_ip" "vm-demoapp-pip" {
  name                = "vm-demoapp-pip"
  location            = azurerm_resource_group.rg-demoapp.location
  resource_group_name = azurerm_resource_group.rg-demoapp.name
  allocation_method   = "Dynamic"
  domain_name_label   = "demo-app-yhernandez"

}

# 6. Deploy Network Interface
resource "azurerm_network_interface" "vm-demoapp-nic-01" {
  name                = "vm-demoapp-nic-01"
  location            = azurerm_resource_group.rg-demoapp.location
  resource_group_name = azurerm_resource_group.rg-demoapp.name
  depends_on = [
    azurerm_public_ip.vm-demoapp-pip
  ]

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet-demoapp.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm-demoapp-pip.id
  }
}

# 7. Wait the allocation of Public IP
resource "time_sleep" "wait_90_seconds" {
  depends_on = [azurerm_network_interface.vm-demoapp-nic-01]

  create_duration = "90s"
}

# 8. Deploy Virtual Machine vm-demoapp
resource "azurerm_linux_virtual_machine" "vm-demoapp" {
  name                = "vm-demoapp"
  location            = azurerm_resource_group.rg-demoapp.location
  resource_group_name = azurerm_resource_group.rg-demoapp.name
  size                = "Standard_D2as_v4"
  admin_username      = "yhernandez"
  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.vm-demoapp-nic-01.id,
  ]
  depends_on = [time_sleep.wait_90_seconds]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "yhernandez"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "20.04.202209200"
  }
}

# 9. Wait before provisioning
resource "time_sleep" "wait_45_seconds" {
  depends_on = [azurerm_linux_virtual_machine.vm-demoapp]
  create_duration = "45s"
}

# 10. Provisioning vm-demo
resource "null_resource" "vm-demo-provisioning" {
  depends_on = [time_sleep.wait_45_seconds] 
  provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook -u yhernandez -i 'demo-app-yhernandez.westus3.cloudapp.azure.com,' provisioning.yml"
  }
}
