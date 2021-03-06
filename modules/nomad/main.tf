resource "scaleway_server" "server" {
  count               = "${var.server_count}"
  name                = "nomad-${count.index + 1}"
  image               = "${var.image}"
  type                = "${var.type}"
  dynamic_ip_required = true
  tags                = ["cluster"]

  # provisioner "file" {
  #   source      = "${path.module}/scripts/upstart.conf"
  #   destination = "/tmp/upstart.conf"
  # }
  provisioner "file" {
    source      = "${path.module}/scripts/system.service"
    destination = "/tmp/nomad.service"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/nomad_v0.4_linux_arm"
    destination = "/usr/local/bin/nomad"
  }

  provisioner "remote-exec" {
    inline = <<CMD
cat > /tmp/server.hcl <<EOF
datacenter = "dc1"

bind_addr = "${self.private_ip}"

advertise {
  # We need to specify our host's IP because we can't
  # advertise 0.0.0.0 to other nodes in our cluster.
  serf = "${self.private_ip}:4648"
  rpc = "${self.private_ip}:4647"
  http= "${self.private_ip}:4646"
}

server {
  enabled = true
  bootstrap_expect = ${element(split(",", "1,0"), signum(count.index))}
}

client {
  enabled = true
  options = {
    "driver.raw_exec.enable" = "1"
  }
}

consul {
  address = "${var.consul_cluster_ip}:8500"
}
EOF
CMD
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/scripts/install.sh",
      "${path.module}/scripts/service.sh",
    ]
  }

  security_group = "${var.security_group}"
}
