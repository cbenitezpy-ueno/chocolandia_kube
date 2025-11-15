# Variables for BeerSystem database provisioning

variable "postgres_host" {
  description = "PostgreSQL cluster host (service endpoint)"
  type        = string
  default     = "postgres-rw.postgres.svc.cluster.local"
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_admin_user" {
  description = "PostgreSQL cluster admin username"
  type        = string
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "PostgreSQL cluster admin password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "beersystem_stage"
}

variable "db_user" {
  description = "Name of the database user to create"
  type        = string
  default     = "beersystem_admin"
}

variable "db_password" {
  description = "Password for the beersystem database user"
  type        = string
  sensitive   = true
}
