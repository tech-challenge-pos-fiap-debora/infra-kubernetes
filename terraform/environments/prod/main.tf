locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  availability_zones = var.availability_zones
  tags               = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  kubernetes_version  = var.kubernetes_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = local.common_tags
}

module "platform" {
  source = "../../modules/platform"

  database_url          = var.database_url
  jwt_secret            = var.jwt_secret
  seed_admin_password   = var.seed_admin_password
  new_relic_license_key = var.new_relic_license_key

  depends_on = [module.eks]
}

# Só é provisionado quando as chaves do New Relic estão configuradas, para que
# o ambiente continue subindo sem observabilidade caso elas faltem.
module "observability" {
  source = "../../modules/observability"
  count  = var.new_relic_api_key == "" ? 0 : 1

  project_name          = var.project_name
  environment           = var.environment
  cluster_name          = module.eks.cluster_name
  new_relic_account_id  = var.new_relic_account_id
  new_relic_license_key = var.new_relic_license_key
  alert_email           = var.alert_email
  healthcheck_url       = var.healthcheck_url

  depends_on = [module.eks, module.platform]
}

module "alb_ingress" {
  source = "../../modules/alb-ingress"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id
  aws_region   = var.aws_region
  tags         = local.common_tags

  depends_on = [module.eks, module.platform]
}
