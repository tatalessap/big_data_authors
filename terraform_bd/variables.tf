variable "profile_name" {
	default     = "default"
	description = "Il profilo con cui connettersi tra le credenziali di AWS"
}
variable "AWS_credentials_path" {
	default     = "/home/tatalessap/.aws/credentials"
	description = "Path di riferimento per le credenziali di AWS"
}

variable "AWS_region" {
	default     = "us-east-1"
	description = "Regione in AWS in cui creare le istanze"
}
variable "AMI_code" {
	default     = "ami-085925f297f89fce1"
	description = "AMI da utilizzare. I codici cambiano in base alla regione"
}
variable "instance_type" {
	default     = "t2.2xlarge"
	description = "Il tipo delle istanze"
}

variable "access_key_name" {
	description = "Il nome della chiave .pem per accedere alle istanze AWS"
}
variable "access_key_path" {
	description = "Il path completo (incluso il file stesso) della chiave .pem"
}
