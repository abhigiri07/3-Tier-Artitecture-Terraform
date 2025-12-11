variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "pri-cidr" {
  default = "10.0.0.0/20"
}
variable "pub-cidr" {
  default = "10.0.16.0/20"
}
variable "az1" {
  default = "us-east-1a"
}
variable "az2" {
  default = "us-east-1b"
}
variable "project_name" {
  default = "FTC"
}
variable "ami" {
  default = "ami-0c02fb55956c7d316"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "key_name" {
  default = "Server101"
}