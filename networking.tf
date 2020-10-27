resource "google_compute_network" "vpc_network_main" {
  name                    = "VPC_NAME"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork_bastion" {
  name                     = "bastion"
  ip_cidr_range            = "CIDR_RANGE"
  region                   = "REGION"
  private_ip_google_access = true
  network                  = google_compute_network.vpc_network_main.id
}
