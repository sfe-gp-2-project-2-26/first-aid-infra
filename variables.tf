variable "aws_region" {
  description = "AWS region to deploy into"
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type (GPU-capable for BGE-M3)"
  default     = "g4dn.xlarge"
}

variable "domain_name" {
  description = "Domain name for the application"
  default     = "medaid.abdallahgabr.me"
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for abdallahgabr.me"
  default     = "Z0406213I9IOOJOC6YR"
}

variable "gemini_api_key" {
  description = "Google Gemini API Key"
  type        = string
  sensitive   = true
}

variable "groq_api_key" {
  description = "Groq API Key"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
  default     = "medaid-production-jwt-secret-change-me"
}
