provider "azurerm" {
  version = "=2.20.0"

  features {}
}

# Can use environment variables, see: https://www.terraform.io/docs/providers/cloudflare/index.html
provider "cloudflare" {
  version = "~> 2.0"
  email   = "[CLOUDFLARE EMAIL]"
  api_key = "[CLOUDFLARE API KEY]"
}

locals {
  deployment_name = "mongo"
  nodes_count     = 3
  location        = "eastus"
  zone_name       = "[DOMAIN NAME]" # Needs to be a domain available on the above CloudFlare account
  replica_set     = "mongo-set"
  nodes_list = {
    for index in range(1, local.nodes_count + 1) : index => "${local.deployment_name}${index}.${local.zone_name}"
  }
}

# Create resource group
resource "azurerm_resource_group" "this" {
  name     = "rg-${local.deployment_name}-${local.location}"
  location = local.location
}

# Create containers virtual network resources
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.deployment_name}-in"
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.1.0/24", "10.0.2.0/24"]
}

resource "azurerm_subnet" "internal" {
  name                 = "snet-${local.deployment_name}-in"
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "snet-delegation-${local.deployment_name}"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "external" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_network_profile" "this" {
  name                = "np-${local.deployment_name}"
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name

  container_network_interface {
    name = "nic-${local.deployment_name}"

    ip_configuration {
      name      = "ipc-${local.deployment_name}"
      subnet_id = azurerm_subnet.internal.id
    }
  }
}

# Create private DNS zone
resource "azurerm_private_dns_zone" "this" {
  name                = local.zone_name
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "dns-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

# Create firewall
module "firewall" {
  source = "./modules/firewall"

  deployment_name     = "${local.deployment_name}3"
  resource_group_name = azurerm_resource_group.this.name
  location            = local.location
  pips_count          = local.nodes_count
  subnet_id           = azurerm_subnet.external.id
}

# Create external DNS records
module "cloudflare_record" {
  source = "./modules/cloudflare-record"

  deployment_name = local.deployment_name
  zone_name       = local.zone_name
  pips            = module.firewall.this_pips
}

# Create nodes storage
resource "azurerm_storage_account" "this" {
  name                     = "strg${local.deployment_name}${local.location}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = local.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  static_website {}
}

# Create mongo replicaset nodes
module "mongo_node" {
  source = "./modules/mongo-node"

  deployment_name      = "${local.deployment_name}"
  location             = local.location
  nodes_count          = local.nodes_count
  resource_group_name  = azurerm_resource_group.this.name
  network_profile_id   = azurerm_network_profile.this.id
  zone_name            = local.zone_name
  storage_account_name = azurerm_storage_account.this.name
  storage_primary_key  = azurerm_storage_account.this.primary_access_key
  replica_set          = local.replica_set
  nodes_list           = local.nodes_list
}

# Create firewall rules
module "netowork_rule" {
  source = "./modules/network-rule"

  deployment_name     = "${local.deployment_name}"
  resource_group_name = azurerm_resource_group.this.name
  firewall_name       = module.firewall.this_name
  port                = 27017
  ip_addresses        = module.firewall.this_pips
}

module "nat_rule" {
  source = "./modules/nat-rule"

  deployment_name      = "${local.deployment_name}"
  resource_group_name  = azurerm_resource_group.this.name
  firewall_name        = module.firewall.this_name
  port                 = 27017
  public_ip_addresses  = module.firewall.this_pips
  private_ip_addresses = module.mongo_node.this_ips
}
