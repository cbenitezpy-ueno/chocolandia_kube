# Input variables for PostgreSQL database module

variable "db_name" {
  description = "Name of the PostgreSQL database to create"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "db_user" {
  description = "Name of the database user/role to create"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]*$", var.db_user))
    error_message = "User name must start with a letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "db_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "Password must be at least 16 characters long."
  }
}
