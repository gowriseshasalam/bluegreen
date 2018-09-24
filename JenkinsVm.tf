#create vm for Jenkins
variable "prefix" {
  default = "terraformJenkins"
}
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = "West US 2"
}
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.0.2.0/24"
}
resource "azurerm_public_ip" "main"{
    name="${var.prefix}-pubip"
    location = "${azurerm_resource_group.main.location}"
    resource_group_name = "${azurerm_resource_group.main.name}"
    public_ip_address_allocation = "Static"
    idle_timeout_in_minutes = 30
}
resource "azurerm_network_security_group" "main" {
  name = "${var.prefix}-nsg"
  location = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}
resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "static"
    private_ip_address = "10.0.2.5"
    public_ip_address_id = "${azurerm_public_ip.main.id}"
  }
}
resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "Standard_DS1_v2"
  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true
  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "Jumplinx123"
    admin_username = "testadmin123"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
   provisioner "local-exec"{
    #"${element(azurerm_public_ip.main.*.ip_address, count.index)}"
    command = "echo ${element(azurerm_public_ip.main.*.ip_address, count.index)} + ${azurerm_public_ip.main.ip_address}>> copy.txt"
    #command = "echo ${azurerm_public_ip.main.ip_address} >> data.txt"
  }
  connection {
      host     ="${azurerm_public_ip.main.ip_address}"
      #host =  "${element(azurerm_public_ip.main.*.ip_address, count.index)}"
      agent    =false
      type     = "ssh"
      user     = "testadmin123"
      password = "Password1234!"
      timeout = "4m"
    }
  provisioner "file"{
    source = "jenkins.sh"
    destination = "~/jenkins.sh"    
    }
    provisioner "remote-exec" {
    inline = [
      "chmod +x ~/jenkins.sh",
       "sudo  ~/jenkins.sh",
      ] 
  }
  tags {
    environment = "non-prod"
  }
}
/* data "azurerm_public_ip" "main" {
  name                = "${azurerm_public_ip.main.name}"
  resource_group_name = "${azurerm_virtual_machine.main.resource_group_name}"
}
output "public_ip_address" {
  value = "${data.azurerm_public_ip.main.ip_address}"  
} */
