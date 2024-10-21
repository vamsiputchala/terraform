variable "region" {
  description = "AWS Region"
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default     = "ami-050cd642fd83388e4" # Replace with a valid AMI ID
}

variable "instance_type" {
  description = "EC2 Instance type"
  default     = "t2.micro"
}

variable "db_username" {
  description = "Database username"
}

variable "db_password" {
  description = "Database password"
}

variable "db_name" {
  description = "Database name"
  default     = "opensupports"
}
