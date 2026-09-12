variable "namespace" {
  type    = string
  default = "tech-challenge-namespace"
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
