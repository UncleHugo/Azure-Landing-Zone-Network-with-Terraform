variable "subscription_id" {
  type        = string
  description = "Subscription ID for the Azure account"
  default     = "ba953ff2-c89c-4138-aac0-480b34fade19"
}

variable "ip" {
  type        = string
  description = "My public IP for firewall access"
  default     = "102.88.114.121/32"
}