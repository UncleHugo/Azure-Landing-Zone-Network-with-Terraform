# Azure-Landing-Zone-Network-with-Terraform

A hand-written Azure network foundation: a VNet with public and private subnets, an NSG on the public subnet, a NAT Gateway for outbound traffic from the private subnet, and an Ubuntu VM deployed privately with no public IP. Every resource is written manually, no registry modules. It is a translation of the same architecture I previously built on AWS.

## Architecture

![Architecture diagram](images/architecture.png)

The VM lives in the private subnet with no public IP, so it is unreachable from the internet. Its outbound traffic exits through the NAT Gateway, which holds the only egress public IP. The public subnet carries an NSG allowing SSH from a single admin IP, ready for a bastion or public-facing workload.

## Resources deployed in the process.

| Resource | Name | Purpose |
|---|---|---|
| Resource Group | `RG_Landing_Zone` | Container for everything, in `centralus` |
| Virtual Network | `VNet_Landing_Zone` | Address space `10.0.0.0/16` |
| Subnet (public) | `public-subnet1` | `10.0.10.0/24`, NSG-protected |
| Subnet (private) | `private-subnet1` | `10.0.20.0/24`, NAT-attached |
| NSG | `NSG_Landing_Zone_Public` | Allows SSH (22) from my IP only |
| NAT Gateway | `LandingZoneNATGateway` | Outbound internet for the private subnet |
| Public IP | `NatGatewayPublicIP` | Static, Standard SKU, bound to the NAT Gateway |
| NIC | `Landing_Zone_NIC` | VM network interface, private subnet, dynamic private IP |
| Virtual Machine | `hugo-vm` | Ubuntu 24.04 LTS, `Standard_D2s_v3`, SSH key auth |


## The association-resource pattern

Having done something similar on AWS, where AWS attaches a security group directly on the instance, Azure models attachments as their own resources. This project uses three:

- `azurerm_subnet_network_security_group_association` (`mainAssoNSG`) — NSG ↔ public subnet
- `azurerm_nat_gateway_public_ip_association` (`mainNAT-Association`) — NAT Gateway ↔ public IP
- `azurerm_subnet_nat_gateway_association` (`privateAssociation`) — NAT Gateway ↔ private subnet

Each association references both sides by ID, creating an implicit dependency. Terraform builds the joined resources first and the association last. On `terraform destroy` the order reverses, as associations drop before the resources they join. The same rule applies as with AWS route tables.

## Verifying the NAT Gateway

The VM has no public IP, so the test runs through the Azure portal's **Run command** feature (VM → Operations → Run command → RunShellScript):

```bash
curl ifconfig.me
```

The IP returned matches `terraform output nat_public_ip`, proving outbound traffic from the private subnet flows through the NAT Gateway:

<!-- Replace with your screenshot -->
<img width="2782" height="1252" alt="image" src="https://github.com/user-attachments/assets/75d87aa2-170c-4840-8ff0-70c114380873" />

)

## Command Usage in the course of this project

```powershell
az login
az account show
az feature register --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress
az feature show --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress -o table
az provider register --namespace Microsoft.Network
az provider show --namespace Microsoft.Network --query registrationState -o tsv
terraform init
terraform validate
terraform fmt
terraform plan
terraform apply
terraform state show
terraform output
```

Requires:
- Terraform >= 1.5, azurerm provider
- Azure CLI, authenticated
- An SSH key pair
- Admin IP in `variables.tf`

## Teardown

The VM and NAT Gateway are been charged per hour, so a `terraform destroy` was performed at the end of the project.

## What I learned

- Writing Azure resources manually before touching registry modules
- The resource-group-first structure and how it changes the blast radius of a delete
- Azure's association-resource pattern vs AWS inline attachment
- How implicit dependencies drive both create and destroy order
- Deploying a private VM and verifying its egress path without SSH access
- `terraform fmt`, `validate`, and `plan` as the local feedback loop before any apply
