variable "project" {
  description = "Project name, used in resource names and tags"
  type        = string
  default     = "learnline"
}

variable "account_id" {
  description = "The only AWS account this config may run in"
  type        = string
  default     = "369970405316"
}

variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}