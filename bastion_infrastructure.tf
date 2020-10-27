# The consent auth screen and the IAP  needs to be manually provisioned


#############################################################
###     MANAGED INSTANCE GROUP ###
locals {
  distribution_policy_zones = ["europe-west4-a", "europe-west4-b", "europe-west4-c"]
  your_google_group = "GOOGLE_GROUP_EMAIL_ADRESS"
}


# IAM binding for the instance group manager
# ${project_id}@cloudservices.gserviceaccount.com
resource "google_project_iam_binding" "project" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"

  members = [
    "serviceAccount:${var.project_number}@cloudservices.gserviceaccount.com",
  ]
}

resource "google_compute_instance_template" "bastion-template" {
  name        = "bastion-template"
  description = "This template is used to create bastion instances."

  tags = ["bastion"]

  labels = {
    environment = var.environment_name
  }

  instance_description = "Instance used for bastion - non-preemptible type"
  machine_type         = "f1-micro"

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
    preemptible         = false
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnetwork_bastion.id
  }

  metadata = {
    enable-oslogin     = "True"
    enable-oslogin-2fa = "True"
  }
}

resource "google_compute_region_instance_group_manager" "bastion" {
  name = "instance-group-manager-bastion"

  base_instance_name        = "bastion"
  region                    = "europe-west4"
  distribution_policy_zones = local.distribution_policy_zones

  version {
    instance_template = google_compute_instance_template.bastion-template-v4.id
  }

  target_size = 3
  depends_on = [google_compute_instance_template.bastion-template-v4]

}

#############################################################
###     IAM SETTINGS ###
data "google_compute_region_instance_group" "mig" {
  name = google_compute_region_instance_group_manager.bastion.name
  region = "europe-west4"
}

data "google_compute_instance" "instance_in_mig" {
  count = length(data.google_compute_region_instance_group.mig.instances)
  self_link = data.google_compute_region_instance_group.mig.instances[count.index].instance
}

resource "google_iap_tunnel_instance_iam_member" "membership" {
  count = length(data.google_compute_region_instance_group.mig.instances)

  project  = var.project_id
  zone     = data.google_compute_instance.instance_in_mig[count.index].zone
  instance = data.google_compute_instance.instance_in_mig[count.index].name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "group:${local.your_google_group}"
}

resource "google_compute_instance_iam_member" "membership" {
  count = length(data.google_compute_region_instance_group.mig.instances)

  project       = var.project_id
  zone          = data.google_compute_instance.instance_in_mig[count.index].zone
  instance_name = data.google_compute_instance.instance_in_mig[count.index].name
  role          = "roles/compute.osLogin"
  member        = "group:${local.your_google_group}"
}


#############################################################
###     NETWORK SETTINGS ###
resource "google_compute_router" "bastion-router" {
  name    = "bastion-router-custom-vpc"
  region  = "europe-west4"
  network = google_compute_network.vpc_network_main.id
}

resource "google_compute_router_nat" "bastion-nat" {
  name                               = "bastion-router-nat-custom-vpc"
  router                             = google_compute_router.bastion-router.name
  region                             = "europe-west4"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ALL"
  }
  depends_on =[ google_compute_router.bastion-router ]
}


resource "google_compute_firewall" "bastion-firewall" {
  name    = "iap-bastion-custom-vpc"
  network = google_compute_network.vpc_network_main.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["bastion"]
  source_ranges = ["35.235.240.0/20"] # This range contains all IP addresses that IAP uses for TCP forwarding.
}

