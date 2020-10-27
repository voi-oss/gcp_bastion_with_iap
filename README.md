# gcp_bastion_with_iap

(See blog_post_here for the full context.)

This is Terraform code to provision the infrastructure for bastion in GCP with IAP.
It will deploy :
* in a custom VPC
* a regional instance managed group with instances without public IP
* the instances will be accessible via gcloud-ssh to users in ${your_google_group} :
  * with no sudo possible
  * with IAP authentication (so no need for ssh key)
  * with 2FA enforced


# Deployment

* Some steps are manual : the consent auth screen and the IAP needs to be manually provisioned (see https://cloud.google.com/iap/docs/tutorial-gce#set_up_iap )
* Set-up your own variables in terraform.tfvars
* Create a google group that contains the users that need to access via Bastion and set the email address in local.your_google_group
* Change the region
* Change networking.tf : change the name of your VPC network, decide on the CIDR range and region. We choosed to use a custom VPC (which is defined in networking.tf), if you prefer to use the default VPC, you will need to change the resource google_compute_instance_template.bastion-template.network_interface subnetwork into network.
* Regarding terraform plan/terraform apply, you will need to tf apply twice: first to create the managed instance group, then to apply the IAM in the instances created by the managed instance group (to do so, you could use terraform apply with the target option, or comment the IAM settings for the first apply )


# Usage

* On the infrastructure, make sure the CIDR of the bastion instances are authorized for accessing the private ressources
* Add the users in the group ${your_google_group}
* The user will ssh in one of the instances via the gcloud command :
```
# To ssh into the instance :
gcloud compute --project ${PROJECT_ID} ssh --zone ${BASTION_ZONE} ${BASTION_INSTANCE_NAME} 
# To establish an ssh tunnel into the instance :
gcloud compute --project ${PROJECT_ID} ssh --zone ${BASTION_ZONE} ${BASTION_INSTANCE_NAME} --tunnel-through-iap --ssh-flag="-L${LOCAL_PORT}:${IP_ADDRESS}:${REMOTE_PORT}"
```
