/*
provider "google" {
  credentials = "${file("../../../accounts/Harin's First Project-335635df82f2.json")}"
  project = "quick-replica-95101"
  region = "us-east1"
}*/
provider "google" {
  credentials = "${file("../../../accounts/dowjonestest11-computeserviceaccount.json")}"
  project = "infra-agent-144815"
  region = "us-east1"
}
resource "google_compute_network" "swarm" {
  name       = "swarm-network"
}
resource "google_compute_firewall" "allow-http" {
  name    = "allow-http"
  network = "${google_compute_network.swarm.name}"
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["http-server"]
}
resource "google_compute_firewall" "allow-https" {
  name    = "allow-https"
  network = "${google_compute_network.swarm.name}"
  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  target_tags = ["https-server"]
}

resource "google_compute_firewall" "loadbalancer-firewall" {
  name    = "firewall-loadbalancer"
  network = "${google_compute_network.swarm.name}"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22","8080","2375","80"]
  }

  target_tags = ["loadbalancer"]
}
resource "google_compute_firewall" "swarm-mgr-firewall" {
  name    = "firewall-swarm-mgr"
  network = "${google_compute_network.swarm.name}"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22","2375","3375","4000"]
  }

  target_tags = ["swarm-mgr"]
}
resource "google_compute_firewall" "swarm-node-firewall" {
  name    = "firewall-swarm-node"
  network = "${google_compute_network.swarm.name}"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22","2375"]
  }

  target_tags = ["swarm-node"]
}
resource "google_compute_firewall" "swarm-consul-firewall" {
  name    = "firewall-swarm-consul"
  network = "${google_compute_network.swarm.name}"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "udp"
    ports    = [ "53","8600"]
  }
  allow {
    protocol = "tcp"
    ports    = [ "22","8500","8300-8302","8400","8600"]
  }

  target_tags = ["swarm-consul"]
}
resource "google_compute_subnetwork" "swarmsubnet-us-east1" {
  name          = "swarmsubnet-us-east1"
  ip_cidr_range = "10.196.130.32/27"
  network       = "${google_compute_network.swarm.self_link}"
  region        = "us-east1"
  depends_on = ["google_compute_network.swarm","google_compute_firewall.swarm-consul-firewall","google_compute_firewall.swarm-node-firewall","google_compute_firewall.swarm-mgr-firewall","google_compute_firewall.allow-http","google_compute_firewall.allow-https"]
}
resource "google_compute_instance" "consul" {
  name        = "consul"
  description = "consul"
  tags = ["http-server", "https-server","swarm-consul"]
  zone="us-east1-b"
  machine_type = "n1-standard-1"
//  depends_on = ["google_compute_subnetwork.swarmsubnet-us-east1","google_compute_firewall.swarm-mgr-firewall","google_compute_firewall.swarm-node-firewall","google_compute_firewall.swarm-consul-firewall","google_compute_firewall.allow-http","google_compute_firewall.allow-https"]
	disk {
		image = "https://www.googleapis.com/compute/v1/projects/quick-replica-95101/global/images/a-ubuntu-trusty-docker"
	}
	network_interface {
		subnetwork = "swarmsubnet-us-east1"
		access_config{
		}
	}
/*	metadata {
		ssh-keys = "${file("./keys/rootkey.pub")}"
	}*/
	metadata {
		ssh-keys = "${file("./keys/putty.pub")}"
	}
	metadata_startup_script = "${file("consul_script.txt")}"
	service_account {
		scopes = [ "compute-rw", "storage-ro", "datastore" ]
	}
    provisioner "local-exec" {
        command = "echo export consul_ip=${google_compute_instance.consul.network_interface.0.access_config.0.assigned_nat_ip}; > consulip.txt"
    }	
}

resource "google_compute_instance" "swarm-mgr" {
  count=1
  name        = "swarm-mgr${count.index}"
  description = "swarm-mgr${count.index}"
  tags = ["http-server", "https-server","swarm-mgr"]
  zone="us-east1-b"
  machine_type = "n1-standard-1"
  depends_on = ["google_compute_instance.consul"]
	disk {
		image = "https://www.googleapis.com/compute/v1/projects/quick-replica-95101/global/images/a-ubuntu-trusty-docker"
	}
	network_interface {
		subnetwork = "swarmsubnet-us-east1"
		access_config{
		}
	}
	metadata {
		ssh-keys = "${file("./keys/putty.pub")}"
	}
	metadata_startup_script = "${file("consulip.txt")}${file("swarmmgr_script.txt")}"
	service_account {
		scopes = [ "compute-rw", "storage-ro", "datastore" ]
	}
    provisioner "local-exec" {
        command = "echo export swarmmgr_ip=${google_compute_instance.swarm-mgr.network_interface.0.access_config.0.assigned_nat_ip} > swarmmgrip.txt >>./config/setup.sh"
    }	
    provisioner "local-exec" {
        command = "sed -e 's/ipaddress/${google_compute_instance.swarm-mgr.network_interface.0.access_config.0.assigned_nat_ip}/g' < ./config/config.toml.template > ./config/config.toml"
    }	
	
}
resource "google_compute_instance" "node" {
  count=2
  name = "node${count.index}"
  description = "node${count.index}"
  tags = ["http-server", "https-server","swarm-node"]
  zone="us-east1-b"
  machine_type = "n1-standard-1"
  depends_on = ["google_compute_instance.swarm-mgr"]
	disk {
		image = "https://www.googleapis.com/compute/v1/projects/quick-replica-95101/global/images/a-ubuntu-trusty-docker"
	}
	network_interface {
		subnetwork = "swarmsubnet-us-east1"
		access_config{
		}
	}
	metadata {
		ssh-keys = "${file("./keys/putty.pub")}"
	}
	metadata_startup_script = "${file("consulip.txt")}${file("node_script.txt")}"
	service_account {
		scopes = [ "compute-rw", "storage-ro", "datastore" ]
	}
}
resource "google_compute_instance" "loadbalancer" {
  name = "loadbalancer"
  description = "loadbalancer"
  tags = ["http-server", "https-server","loadbalancer"]
  zone="us-east1-b"
  machine_type = "n1-standard-1"
  depends_on = ["google_compute_instance.swarm-mgr"]
	disk {
		image = "https://www.googleapis.com/compute/v1/projects/quick-replica-95101/global/images/a-ubuntu-trusty-docker"
	}
	network_interface {
		subnetwork = "swarmsubnet-us-east1"
		access_config{
		}
	}
	metadata {
		ssh-keys = "root:${file("./keys/putty.pub")}"
	}
	service_account {
		scopes = [ "compute-rw", "storage-ro", "datastore" ]
	}
	connection {
		type = "ssh"
		user = "root"
		private_key = "${file("./keys/ssh-keygen")}"
		timeout = "240s"
	}
    provisioner "file" {
        source = "./config"
        destination = "./"
    }
	
    provisioner "remote-exec" {
        inline = [
			"docker restart",
			"cd config",
			"docker run -P --name interlock -d -ti -v nginx:/etc/conf  -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/config.toml:/etc/config.toml  ehazlett/interlock:1.0.1 -D run -c /etc/config.toml",
			"docker run -ti -d -p 80:80 --label interlock.ext.name=nginx --link=interlock:interlock -v nginx:/etc/conf --name nginx nginx nginx -g 'daemon off;' -c /etc/conf/nginx.conf"
        ]
    }
}
