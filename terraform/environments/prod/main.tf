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

  mongo_url           = var.mongo_url
  jwt_secret          = var.jwt_secret
  seed_admin_password = var.seed_admin_password

  depends_on = [module.eks]
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
