locals {
  init_file_path = "/usr/local/bin/init-replicaset.sh"
  set_nodes      = join(",", formatlist("{_id: %s, host: \"%s:27017\"}", keys(var.nodes_list), values(var.nodes_list)))
  init_replicaset = templatefile("./modules/mongo-node/init-replicaset.tmpl", {
    replica_set = var.replica_set
    members     = local.set_nodes
  })
  echo_init_cmd       = "echo '${local.init_replicaset}' > ${local.init_file_path}"
  mongod_cmd          = "mongod --bind_ip_all --replSet ${var.replica_set}"
  init_permission_cmd = "chmod u+x ${local.init_file_path}"
}

resource "azurerm_storage_share" "this" {
  count                = var.nodes_count
  name                 = "db-${var.deployment_name}${count.index + 1}"
  storage_account_name = var.storage_account_name
}

# Create node container resource
resource "azurerm_container_group" "this" {
  count               = var.nodes_count
  name                = "aci-${var.deployment_name}${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_address_type     = "private"
  network_profile_id  = var.network_profile_id
  os_type             = "Linux"
  restart_policy      = "Never"

  container {
    name   = "mongo"
    image  = "mongo"
    cpu    = "0.5"
    memory = "1.5"
    commands = [
      "sh",
      "-c",
      "${local.echo_init_cmd} && ${local.init_permission_cmd} && (${local.init_file_path} & ${local.mongod_cmd})"
    ]

    volume {
      name                 = "vol-${var.deployment_name}"
      mount_path           = "/data/db"
      storage_account_name = var.storage_account_name
      storage_account_key  = var.storage_primary_key
      share_name           = azurerm_storage_share.this[count.index].name
    }

    ports {
      port     = 27017
      protocol = "TCP"
    }
  }
}

# Create node A DNS record
resource "azurerm_private_dns_a_record" "this" {
  count               = var.nodes_count
  name                = "${var.deployment_name}${count.index + 1}"
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_group.this[count.index].ip_address]
}
