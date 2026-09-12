variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "tech-challenge"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "api_image_tag" {
  type    = string
  default = "latest"
}

variable "mongo_url" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "seed_admin_password" {
  type      = string
  sensitive = true
}
