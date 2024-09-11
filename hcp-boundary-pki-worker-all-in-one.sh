#!/bin/bash
# HCP Boundary PKI Worker all-in-one v1 by Trifo Tsantsarov @ HashiCorp.

# Install Boundary Enterprise:
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository --yes "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update
apt install boundary-enterprise

echo ""

# Get HCP Boundary cluster id:
read -p "Please enter your HCP Boundary cluster id: " hcpb_cluster_id

echo ""

# Prepare worker directories:
mkdir -p /home/boundary/hcp-boundary-pki-worker/storage/auth
mkdir -p /home/boundary/hcp-boundary-pki-worker/storage/recordings

# Write worker's config:
cat <<EOF > /etc/hcp-boundary-pki-worker.hcl
disable_mlock = true
hcp_boundary_cluster_id = "$hcpb_cluster_id"
listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}
worker {
  public_addr = "$(curl http://checkip.amazonaws.com)"
  auth_storage_path = "/home/boundary/hcp-boundary-pki-worker/storage/auth"
  tags {
    type = ["hcp-boundary-pki-worker"]
  }
  recording_storage_path = "/home/boundary/hcp-boundary-pki-worker/storage/recordings"
}
EOF

# Create Boundary as systemd service:
TYPE=worker
NAME=boundary
cat << EOF > /etc/systemd/system/hcp-boundary-pki-worker.service
[Unit]
Description=HCP Boundary PKI Worker

[Service]
ExecStart=/usr/bin/boundary server -config /etc/hcp-boundary-pki-worker.hcl
User=boundary
Group=boundary
LimitMEMLOCK=infinity
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

# Add the boundary system user and group to ensure we have a no-login user capable of owning and running Boundary:
adduser --system --group boundary || true

# Small fixes:
chown boundary:boundary /etc/hcp-boundary-pki-worker.hcl
chown boundary:boundary /usr/bin/boundary
chown -R boundary:boundary /home/boundary
chmod 664 /etc/systemd/system/hcp-boundary-pki-worker.service

# Reload systemd, enable the service, start the service:
systemctl daemon-reload
systemctl enable hcp-boundary-pki-worker
systemctl start hcp-boundary-pki-worker

echo "If all commands exdcuted successfully, then you should find the Worker Auth Registration code below:"

grep 'Worker Auth Registration Request' /var/log/syslog | awk {'print $8'}
