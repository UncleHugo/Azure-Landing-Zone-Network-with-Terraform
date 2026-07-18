variable "subscription_id" {
  type        = string
  description = "Subscription ID for the Azure account"
  default     = "xxxxxxxxxxxxxxxxxxxxx"
}

variable "ip" {
  type        = string
  description = "My public IP for firewall access"
  default     = "xxxxxxx/32"
}
