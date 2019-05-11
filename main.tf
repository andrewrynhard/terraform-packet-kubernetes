module "security" {
  source = "github.com/autonomy/terraform-talos-security"

  talos_target  = "${packet_ip_attachment.master.0.network}"
  talos_context = "${var.cluster_name}"
}

module "master_userdata" {
  source = "github.com/talos-systems/terraform-talos-configuration/masters"

  "cluster_name"               = "${var.cluster_name}"
  "trustd_password"            = "${module.security.trustd_password}"
  "kubernetes_token"           = "${module.security.kubeadm_token}"
  "kubernetes_certificate_key" = "${module.security.kubeadm_certificate_key}"
  "kubernetes_ca_key"          = "${module.security.kubernetes_ca_key}"

  "master_hostnames" = [
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,0)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,1)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,2)}",
  ]

  "pod_subnet"        = "${var.pod_subnet}"
  "talos_ca_crt"      = "${module.security.talos_ca_crt}"
  "trustd_username"   = "${module.security.trustd_username}"
  "kubernetes_ca_crt" = "${module.security.kubernetes_ca_crt}"

  "trustd_endpoints" = [
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,0)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,1)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,2)}",
  ]

  "container_network_interface_plugin" = "${var.container_network_interface}"
  "service_subnet"                     = "${var.service_subnet}"
  "talos_ca_key"                       = "${module.security.talos_ca_key}"
}

module "worker_userdata" {
  source = "github.com/talos-systems/terraform-talos-configuration/workers"

  "trustd_password" = "${module.security.trustd_password}"
  "trustd_username" = "${module.security.trustd_username}"

  "trustd_endpoints" = [
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,0)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,1)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,2)}",
  ]

  "kubernetes_token"                   = "${module.security.kubeadm_token}"
  "api_server_endpoint"                = "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,0)}"
  "container_network_interface_plugin" = "${var.container_network_interface}"
  "node_role"                          = "worker"
}

module "ingress_userdata" {
  source = "github.com/talos-systems/terraform-talos-configuration/workers"

  "trustd_password" = "${module.security.trustd_password}"
  "trustd_username" = "${module.security.trustd_username}"

  "trustd_endpoints" = [
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,0)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,1)}",
    "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,2)}",
  ]

  "kubernetes_token"                   = "${module.security.kubeadm_token}"
  "api_server_endpoint"                = "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,0)}"
  "container_network_interface_plugin" = "${var.container_network_interface}"
  "node_role"                          = "ingress"
  "node_taints"                        = "[{\"key\": \"dedicated\", \"value\": \"ingress\", \"effect\": \"NoSchedule\"}]"
}

locals {
  master_count = 3
}

resource "packet_reserved_ip_block" "masters" {
  project_id = "${var.project_id}"
  facility   = "${var.packet_facility}"
  quantity   = 4
}

resource "packet_ip_attachment" "master" {
  count = "${local.master_count}"

  device_id     = "${element(packet_device.master.*.id, count.index)}"
  cidr_notation = "${cidrhost(packet_reserved_ip_block.masters.cidr_notation,count.index)}/32"
}

resource "packet_device" "master" {
  count = "${local.master_count}"

  hostname         = "${format("master-%d", count.index + 1)}"
  operating_system = "custom_ipxe"
  plan             = "${var.packet_master_type}"
  network_type     = "layer3"
  ipxe_script_url  = "http://${var.ipxe_endpoint}:8080/boot.ipxe"
  always_pxe       = "false"
  facilities       = ["${var.packet_facility}"]
  project_id       = "${var.project_id}"
  billing_cycle    = "hourly"

  user_data = <<EOF
#!talos
${module.master_userdata.userdata[count.index]}
networking:
  os:
    devices:
    - interface: lo
      cidr: ${cidrhost(packet_reserved_ip_block.masters.cidr_notation,count.index)}/32
    - interface: eth0
      dhcp: true
install:
  wipe: false
  force: true
  boot:
    device: /dev/sda
    size: 1024000000
    kernel: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/vmlinuz
    initramfs: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/initramfs.xz
  root:
    device: /dev/sda
    size: 2048000000
    rootfs: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/rootfs.tar.gz
  data:
    device: /dev/sda
    size: 4096000000
EOF
}

resource "packet_device" "ingress" {
  count = "${var.ingress_count}"

  hostname         = "${format("ingress-%d", count.index + 1)}"
  operating_system = "custom_ipxe"
  plan             = "${var.packet_ingress_type}"
  network_type     = "layer3"
  ipxe_script_url  = "http://${var.ipxe_endpoint}:8080/boot.ipxe"
  always_pxe       = "false"
  facilities       = ["${var.packet_facility}"]
  project_id       = "${var.project_id}"
  billing_cycle    = "hourly"

  user_data = <<EOF
#!talos
${module.ingress_userdata.userdata}
install:
  wipe: false
  force: true
  boot:
    device: /dev/sda
    size: 1024000000
    kernel: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/vmlinuz
    initramfs: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/initramfs.xz
  root:
    device: /dev/sda
    size: 2048000000
    rootfs: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/rootfs.tar.gz
  data:
    device: /dev/sda
    size: 4096000000
EOF
}

resource "packet_device" "worker" {
  count = "${var.worker_count}"

  hostname         = "${format("worker-%d", count.index + 1)}"
  operating_system = "custom_ipxe"
  plan             = "${var.packet_worker_type}"
  network_type     = "layer3"
  ipxe_script_url  = "http://${var.ipxe_endpoint}:8080/boot.ipxe"
  always_pxe       = "false"
  facilities       = ["${var.packet_facility}"]
  project_id       = "${var.project_id}"
  billing_cycle    = "hourly"

  user_data = <<EOF
#!talos
${module.worker_userdata.userdata}
install:
  wipe: false
  force: true
  boot:
    device: /dev/sda
    size: 1024000000
    kernel: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/vmlinuz
    initramfs: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/initramfs.xz
  root:
    device: /dev/sda
    size: 2048000000
    rootfs: http://${var.ipxe_endpoint}:8080/assets/talos/${var.talos_version}/rootfs.tar.gz
  data:
    device: /dev/sda
    size: 4096000000
EOF
}
