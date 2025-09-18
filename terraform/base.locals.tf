# Local Values in Terraform
locals {
  region       = var.region
  azs          = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[2]]
  service      = var.service
  owners       = var.owners
  environment  = var.environment
  map_migrated = var.map_migrated

  tags = {
    owners       = local.owners
    environment  = local.environment
    service      = local.service
    backup       = "false"
    cz-project   = local.service
    cz-owner     = local.owners
    cz-stage     = local.environment
    map-migrated = local.map_migrated
  }
}
