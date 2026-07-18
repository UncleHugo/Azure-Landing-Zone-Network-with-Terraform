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

## AWS to Azure mapping

Coming from AWS, these are the equivalents this project uses:

| AWS | Azure | Difference worth knowing |
|---|---|---|
| — | Resource Group | No AWS equivalent. Every Azure resource lives in one; deleting the group deletes everything inside it. |
| VPC | Virtual Network (VNet) | Same idea, same CIDR-based address space. |
| Subnet | Subnet | Azure subnets are not tied to an availability zone. "Public" vs "private" is convention, not a property. |
| Security Group | Network Security Group (NSG) | Attaches to subnets or NICs via a separate association resource, not inline on the instance. |
| Route Table | Route Table / User-Defined Routes | Attached via `azurerm_subnet_route_table_association`. This project needs none — see NAT note below. |
| Internet Gateway | (implicit) | Azure VNets have internet routing by default; there is no IGW resource to create. |
| NAT Gateway | NAT Gateway | AWS NAT lives in a public subnet and needs a route table entry. Azure NAT attaches directly to the private subnet and Azure injects the route automatically. |
| ENI | Network Interface (NIC) | Standalone resource in both; created here as its own resource and referenced by the VM. |
| EC2 Instance | Virtual Machine | Image selection via `source_image_reference` (publisher/offer/sku) instead of an AMI ID. |
| `map_public_ip_on_launch` | — | No subnet-level flag. A VM is "public" only if its NIC has a public IP and an NSG allows inbound. |

## The association-resource pattern

The least obvious thing coming from AWS. Where AWS attaches a security group directly on the instance, Azure models attachments as their own resources. This project uses three:

- `azurerm_subnet_network_security_group_association` (`mainAssoNSG`) — NSG ↔ public subnet
- `azurerm_nat_gateway_public_ip_association` (`mainNAT-Association`) — NAT Gateway ↔ public IP
- `azurerm_subnet_nat_gateway_association` (`privateAssociation`) — NAT Gateway ↔ private subnet

Each association references both sides by ID, creating an implicit dependency chain: Terraform builds the joined resources first and the association last. On `terraform destroy` the order reverses — associations drop before the resources they join. The same rule applies as with AWS route tables: keep attachments as separate resources and never mix them with inline definitions.

## Verifying the NAT Gateway

The VM has no public IP, so the test runs through the Azure portal's **Run command** feature (VM → Operations → Run command → RunShellScript):

```bash
curl ifconfig.me
```

The IP returned matches `terraform output nat_public_ip`, proving outbound traffic from the private subnet flows through the NAT Gateway:

<!-- Replace with your screenshot -->
![NAT verification](images/nat-verification.png)

## Usage

```powershell
az login
terraform init
terraform plan
terraform apply
```

Requires:
- Terraform >= 1.5, azurerm provider
- Azure CLI, authenticated
- An SSH key pair at `C:/Users/<you>/.ssh/id_rsa` (`ssh-keygen -t rsa -b 4096`)
- Your admin IP in `terraform.tfvars` (see `terraform.tfvars.example`)

## Teardown

The VM (`Standard_D2s_v3`) and NAT Gateway bill by the hour, so destroy when done:

```powershell
terraform destroy
```

## What I learned

- Writing Azure resources manually before touching registry modules
- The resource-group-first structure and how it changes the blast radius of a delete
- Azure's association-resource pattern vs AWS inline attachment
- How implicit dependencies drive both create and destroy order
- Deploying a genuinely private VM and verifying its egress path without SSH access
- `terraform fmt`, `validate`, and `plan` as the local feedback loop before any apply
