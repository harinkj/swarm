@ECHO OFF

if "createnetwork"=="%1" CALL:CREATENETWORK
if "destroynetwork"=="%1" CALL:DESTROYNETWORK
if "createinstance"=="%1" CALL:CREATEINSTANCES
if "destroyinstance"=="%1" CALL:DESTROYINSTANCES
GOTO:EOF
:CREATENETWORK
	rem gcloud compute networks subnets create swarmsubnet-us-east1  --network swarm-network --region us-east1  --range 10.196.130.32/27
	terraform plan -target=google_compute_subnetwork.swarmsubnet-us-east1 -out ./out/network.out
	terraform apply -target=google_compute_subnetwork.swarmsubnet-us-east1 -backup=.\out\network.tfstate.backup -state=.\out\network.tfstate
GOTO:EOF
:DESTROYNETWORK
	terraform destroy -force -state=.\out\network.tfstate -backup=.\out\network.tfstate.backup
	rem gcloud compute networks delete swarm-network
GOTO:EOF
:CREATEINSTANCES
	terraform plan -out ./out/instance.out
	terraform apply  -backup=.\out\instance.tfstate.backup -state=.\out\instance.tfstate
GOTO:EOF
:DESTROYINSTANCES
	terraform destroy -force -state=.\out\instance.tfstate -backup=.\out\instance.tfstate.backup
GOTO:EOF
	
:LEGACY
	terraform plan -target=google_compute_subnetwork.default-us-east1 -out ./out/network.out
	terraform apply -backup=.\out\network.tfstate.backup -state-out=.\out\network.tfstate  .\out\network.out 
	terraform show .\out\network.tfstate
	terraform destroy -force -state=.\out\network.tfstate -backup=.\out\network.tfstate.backup
	packer validate google.json 
	packer build -only googlecompute google.json 

	terraform plan -target=google_compute_instance.docker-test-us-east1-b -out ./out/instance.out
	terraform apply -target=google_compute_instance.docker-test-us-east1-b -backup=.\out\instance.tfstate.backup -state-out=.\out\instance.tfstate
	terraform destroy -force -state=.\out\instance.tfstate -backup=.\out\instance.tfstate.backup


	gcloud config set compute/region us-east1
	gcloud config set compute/zone us-east1-b
	gcloud compute project-info describe
	gcloud compute instances  describe docker-test-us-east1-b
	gcloud compute instances add-metadata docker-test-us-east1-b --metadata-from-file ssh-keys=.\keys\rootkey.pub

	network check
	nc -z -v -w5 -u 104.196.199.165 8600
GOTO:EOF
:EOF	