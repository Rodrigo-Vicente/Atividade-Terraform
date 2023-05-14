terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.55.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg-Atividade" {
  name     = "AtividadeTerraform"
  location = "East US"
}


resource "azurerm_virtual_network" "vNET" {
  name                = "Network"
  location            = azurerm_resource_group.rg-Atividade.location
  resource_group_name = azurerm_resource_group.rg-Atividade.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "sNET" {
  name                 = "SUBNET"
  resource_group_name  = azurerm_resource_group.rg-Atividade.name
  virtual_network_name = azurerm_virtual_network.vNET.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "publicIP" {
  name                = "ipPublic"
  resource_group_name = azurerm_resource_group.rg-Atividade.name
  location            = azurerm_resource_group.rg-Atividade.location
  allocation_method   = "Static"

}

resource "azurerm_network_interface" "interface-Network" {
  name                = "interface-net"
  location            = azurerm_resource_group.rg-Atividade.location
  resource_group_name = azurerm_resource_group.rg-Atividade.name

  ip_configuration {
    name                          = "ipPublic"
    subnet_id                     = azurerm_subnet.sNET.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.publicIP.id
  }
}

resource "azurerm_linux_virtual_machine" "virtual-Machine" {
  name                = "virtual-Machine"
  resource_group_name = azurerm_resource_group.rg-Atividade.name
  location            = azurerm_resource_group.rg-Atividade.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "Rs-88283835!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.interface-Network.id,
  ]

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
}

resource "azurerm_network_security_group" "nsg-atividade" {
  name                = "nsg-atividade"
  location            = azurerm_resource_group.rg-Atividade.location
  resource_group_name = azurerm_resource_group.rg-Atividade.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "associationInterfaceToSecurity" {
  network_interface_id          = azurerm_network_interface.interface-Network.id
  network_security_group_id     = azurerm_network_security_group.nsg-atividade.id
}

resource "null_resource" "install-nginx" {
  connection {
    type = "ssh"
    host = azurerm_public_ip.publicIP.ip_address
    user = "adminuser"
    password = "Rs-88283835!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.virtual-Machine
  ]
}