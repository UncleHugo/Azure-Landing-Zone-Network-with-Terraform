#Create a resource group
resource "azurerm_resource_group" "mainRG" {
  name     = "RG_Landing_Zone"
  location = "centralus"
}

#Create a virtual network with two subnets(public and private)
resource "azurerm_virtual_network" "mainVnet" {
  name                = "VNet_Landing_Zone"
  location            = azurerm_resource_group.mainRG.location
  resource_group_name = azurerm_resource_group.mainRG.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "public-subnet" {
  name                 = "public-subnet1"
  resource_group_name  = azurerm_resource_group.mainRG.name
  virtual_network_name = azurerm_virtual_network.mainVnet.name
  address_prefixes     = ["10.0.10.0/24"]
}

resource "azurerm_subnet" "private-subnet" {
  name                 = "private-subnet1"
  resource_group_name  = azurerm_resource_group.mainRG.name
  virtual_network_name = azurerm_virtual_network.mainVnet.name
  address_prefixes     = ["10.0.20.0/24"]
}


#Create a Network Security Group (NSG) for the public subnet
resource "azurerm_network_security_group" "mainNSG" {
  name                = "NSG_Landing_Zone_Public"
  location            = azurerm_resource_group.mainRG.location
  resource_group_name = azurerm_resource_group.mainRG.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ip
    destination_address_prefix = "*"
  }
}

#Associate the NSG with the public subnet
resource "azurerm_subnet_network_security_group_association" "mainAssoNSG" {
  subnet_id                 = azurerm_subnet.public-subnet.id
  network_security_group_id = azurerm_network_security_group.mainNSG.id
}

#Create a public IP for the NAT Gateway
resource "azurerm_public_ip" "mainNAT-pip" {
  name                = "NatGatewayPublicIP"
  location            = azurerm_resource_group.mainRG.location
  resource_group_name = azurerm_resource_group.mainRG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#Create a NAT Gateway
resource "azurerm_nat_gateway" "mainNATgw" {
  name                = "LandingZoneNATGateway"
  location            = azurerm_resource_group.mainRG.location
  resource_group_name = azurerm_resource_group.mainRG.name
  sku_name            = "Standard"
}

#Associate the NAT Gateway with the public IP
resource "azurerm_nat_gateway_public_ip_association" "mainNAT-Association" {
  nat_gateway_id       = azurerm_nat_gateway.mainNATgw.id
  public_ip_address_id = azurerm_public_ip.mainNAT-pip.id
}

#Associate the NAT Gateway with the private subnet
resource "azurerm_subnet_nat_gateway_association" "privateAssociation" {
  subnet_id      = azurerm_subnet.private-subnet.id
  nat_gateway_id = azurerm_nat_gateway.mainNATgw.id
}
#Create a network interface for the virtual machine
resource "azurerm_network_interface" "mainNIC" {
  name                = "Landing_Zone_NIC"
  location            = azurerm_resource_group.mainRG.location
  resource_group_name = azurerm_resource_group.mainRG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
#Create a Linux virtual machine in the private subnet
resource "azurerm_linux_virtual_machine" "mainVM" {
  name                  = "hugo-vm"
  location              = azurerm_resource_group.mainRG.location
  resource_group_name   = azurerm_resource_group.mainRG.name
  size                  = "Standard_D2s_v3"
  admin_username        = "azureuser1"
  network_interface_ids = [azurerm_network_interface.mainNIC.id]

  admin_ssh_key {
    username   = "azureuser1"
    public_key = file("C:/Users/User/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
