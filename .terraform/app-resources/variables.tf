variable "project_name" {
    type = string
}

variable "domain" {
    type = string
}

variable "env_tag" {
    type = string
}

variable "env_tag_version" {
    type = string
}

variable "project_id" {
    type = string
}

variable "region_name" {
    type = string
    default = "europe-west3"
}

variable "rails_env" {
    type = string
    default = "staging"
}

variable "requires_load_balancer" {
    type = bool
    default = false
}

# SQL
variable "sql_version" {
    type = string
    default = "POSTGRES_14"
}

# Secret Manager
variable "master_key_secret" {
    type = string
}