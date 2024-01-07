terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.85.0"
    }
  }
}

provider "azurerm" {
subscription_id = "fd86e47b-0d70-4234-af28-1aa422d7b611"
tenant_id      = "8e4d7ca5-f751-479c-90e4-3b42311daa6a"
client_id      = "d22e42cf-1feb-408e-bd85-c1b28d54caea"
client_secret = "TC38Q~dQSD4BwzXj_djrov-QxzdMYh0Bvj2-Gc~F"
features {}
}

locals {
  resource_group_name = "app-grp"
  location            = "North Europe"
  virtual_network     = {
  name                = "appnetwork"
  address_space       = "10.0.0.0/16"
  }
  subnets = [ 
    {
    name              = "subnetA"
    address_prefix    = "10.0.0.0/24"
    },
    {
     name              = "subnetB"
    address_prefix    = "10.0.1.0/24"
    }
  ]
  }

resource "azurerm_resource_group" "appgrp" {
name        = local.resource_group_name
location    = local.location

}

resource "azurerm_virtual_network" "appnetwork" {
  name                = local.virtual_network.name
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = [local.virtual_network.address_space]
  depends_on = [ azurerm_resource_group.appgrp ]
}

resource "azurerm_subnet" "subnetA" {
  name                 = local.subnets[0].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[0].address_prefix]  
  depends_on = [ azurerm_virtual_network.appnetwork ]
}

resource "azurerm_subnet" "subnetB" {
  name                 = local.subnets[1].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[1].address_prefix]
  depends_on = [ azurerm_virtual_network.appnetwork ]
}

resource "azurerm_network_interface" "appinterface" {
  name                = "appinterface"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetA.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.aapip.id
  }
  depends_on = [ azurerm_subnet.subnetA ]
}

resource "azurerm_public_ip" "aapip" {
  name                = "app-ip"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"
depends_on = [ azurerm_resource_group.appgrp ]
}

resource "azurerm_network_security_group" "appnsg" {
  name                = "app-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
depends_on = [ azurerm_resource_group.appgrp ]
}

resource "azurerm_subnet_network_security_group_association" "appnsglink" {
  subnet_id                 = azurerm_subnet.subnetA.id
  network_security_group_id = azurerm_network_security_group.appnsg.id
}

resource "azurerm_windows_virtual_machine" "appvm" {
  name                = "app-vm"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = "tahir"
  admin_password      = "Work@786"
  network_interface_ids = [
    azurerm_network_interface.appinterface.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

#new project