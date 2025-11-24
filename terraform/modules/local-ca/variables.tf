# Local CA Module - Variables

variable "namespace" {
  description = "Namespace where CA certificate secret will be stored"
  type        = string
  default     = "cert-manager"
}

variable "issuer_name" {
  description = "Name for the CA ClusterIssuer"
  type        = string
  default     = "local-ca"
}

variable "ca_common_name" {
  description = "Common Name for the CA certificate"
  type        = string
  default     = "Homelab Local CA"
}
