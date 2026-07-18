output "mainVnet" {
  value = azurerm_virtual_network.mainVnet.id
}

output "mainNAT-pip" {
  value = azurerm_public_ip.mainNAT-pip.ip_address
}
