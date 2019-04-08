variable "project_id" {}

variable "packet_facility" {}

variable "ipxe_endpoint" {}

variable "packet_worker_type" {
  default = "t1.small.x86"
}

variable "packet_master_type" {
  default = "t1.small.x86"
}

variable "worker_count" {
  default = "1"
}

variable "cluster_name" {}

variable "container_network_interface" {
  default = "flannel"
}

variable "pod_subnet" {
  default = "10.244.0.1/16"
}

variable "service_subnet" {
  default = "10.96.0.1/12"
}

variable "talos_version" {}
