variable "vpc_id" {
  type = string
}

variable "ami_version" {
  type = string
}

variable "subnet_ids" {
  type = list
}

variable "service_name" {
  type = string
}

variable "key_name" {
  type = string
}

# cluster settings

variable "instance_type" {
  type = string
}

variable "instance_count" {
  type = string
}

variable "volume_size" {
  type = string
}

# service settings

variable "image" {
  type = string
}

variable "task_count" {
  type = string
}

variable "task_cpu" {
  type = string
}

variable "task_memory" {
  type = string
}

variable "elastic_config" {
  type = map
}

# NLB configuration

variable "health_check_interval" {
  default = "30"
}

variable "deregistration_delay" {
  default = "30"
}

# s3 snapshot bucket

variable "s3_bucket_name" {
  type = string
}

# dns settings

variable "private_hosted_zone_name" {
  default = "local."
  type = string
}

# kibana settings

variable "kibana_config" {
  type = map
}

variable "kibana_peered_vpc_cidr" {
  type = string
}

variable "kibana_service_name" {
  type = string
}


variable "kibana_image" {
  type = string
}


variable "kibana_cpu" {
  type = string
}


variable "kibana_memory" {
  type = string
}


variable "kibana_task_count" {
  type = string
}


variable "kibana_certificate_arn" {
  type = string
}
