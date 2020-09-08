data "cloudflare_zones" "this" {
  filter {
    name   = var.zone_name
    status = "active"
    paused = false
  }
}

resource "cloudflare_record" "record1" {
  count   = length(var.pips)
  zone_id = data.cloudflare_zones.this.zones[0].id
  name    = "${var.deployment_name}${count.index + 1}"
  value   = var.pips[count.index]
  type    = "A"
  ttl     = 3600
}
