#!/bin/bash
# A Simple Shell Script To Create a Polaris Cluster
# David Webstar - 16/02/2019
export KUBECONFIG=/root/.kube/config
export AWS_REGION=${REGION}
export AWS_DEFAULT_REGION=${REGION}
export KOPS_STATE_STORE=s3://${STATE_BUCKET}
echo 'AWS_REGION: ' ${AWS_REGION}
echo 'KOPS_STATE_STORE: ' ${KOPS_STATE_STORE}

ssh-keygen -q -t rsa -f /root/.ssh/polaris -N ''
echo 'Generating polaris ssh key'

echo 'Creating vanilla cluster'
# To allow overriding of etcd version (to v3) for cilium
KOPS_FEATURE_FLAGS=SpecOverrideFlag \
kops create cluster \
   ${CLUSTER_NAME}                  `# Name of cluster` \
   --override=cluster.spec.etcdClusters[*].version=3.1.11 `# Specify etcd3 version (instead of etcd v2)` \
   --state s3://${STATE_BUCKET}     `# Name of bucket to store state` \
   `#--dry-run                       # Dont actually do it` \
   `#--output yaml                    # Output of dry-run [yaml | json]` \
   `#--out                           # Stdout redirect` \
   `#--target                        # direct, terraform, cloudformation` \
   `#--yes                           # Specify --yes to immediately create the cluster` \
   --admin-access 0.0.0.0/0         `# CIDRs for Admin API eg kubectl` \
   --api-loadbalancer-type public   `# ELB for Admin API internet facing?` \
   --associate-public-ip=false      `# No public IPs for Masters` \
   --authorization RBAC             `# [AlwaysAllow | RBAC]` \
   `# --bastion                      # No bastion hosts (instance group)` \
   --cloud aws                      `# aws, gce or vsphere` \
   --cloud-labels KUBE-CLUSTER=${CLUSTER_NAME} `# instancegroup tags to apply` \
   --dns public                     `# [public | private]` \
   `#--dns-zone blah` \
   `#--encrypt-etcd-storage` \
   --image ${IMAGE}                 `# Image / AMI to use` \
   --kubernetes-version ${KUBERNETES_VERSION} `# Version of kubernetes to run (defaults to version in channel)` \
   --master-count ${MASTER_COUNT}  `# Number of masters` \
   `#--master-public-name           # Only useful for public masters` \
   `#--master-security-groups       # Existing SGs to apply to masters ` \
   --master-size m4.large         `# Instance type of masters` \
   --master-tenancy default        `# [default | dedicated]` \
   --master-volume-size 30         `# Master volume size in GB` \
   --master-zones ${MASTER_ZONES}  `# Zones` \
   `#--model                        # Figure out what this is` \
   --network-cidr ${CLUSTER_CIDR}  `# CIDR for the cluster VPC` \
   --networking cilium             `# kubenet, classic, external, kopeio-vxlan, kopeio), weave, flannel-vxlan, flannel, flannel-udp, calico, canal, kube-router, romana, amazon-vpc-routed-eni, cilium` \
   --node-count ${NODE_COUNT}      `# Number of worker nodes` \
   `#--node-security-groups         # Existing SGs to apply to nodes` \
   --node-size m4.large             `# Node instance type` \
   `#--node-tenancy default          # [default | dedicated]` \
   --node-volume-size 30           `# Node volume size in GB` \
   `#--project                      # Project to use (must be set on GCE)` \
   `#--ssh-access                   # Restrict SSH access to this CIDR.  If not set, access will not be restricted by IP. (default [0.0.0.0/0])` \
   --ssh-public-key ~/.ssh/polaris.pub `# SSH public key to use (default "~/.ssh/id_rsa.pub")` \
   `#--subnets                      # Set to use shared subnets` \
   --topology private              `# [public | private]` \
   `#--utility-subnets              # Set to use shared utility subnets` \
   `#--vpc vpc-07d5a9727cf0103d7      # Set to use a shared VPC` \
   --zones ${AVAILABILITY_ZONES}   `# Zones in which to run the cluster (nodes?)` \
   $1 $2 $3 $4 $5 $6 $7 $8 $9


kops get --name ${CLUSTER_NAME} --state=s3://${STATE_BUCKET} -o yaml > infrastructure/vanilla_cluster.yaml

ROOT=$( dirname "${BASH_SOURCE[0]}" )
FOLDER=$ROOT/dex/ca

echo Will create CA in $FOLDER

mkdir -p $FOLDER
cd $FOLDER

cat << EOF > req.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dex.${CLUSTER_NAME}
EOF

# CA Private and Self-signed Certificate
#
openssl genrsa -out dex-ca-key.pem 2048
openssl req -x509 -new -nodes -key dex-ca-key.pem -days 9999 -out dex-ca-cert.pem -subj "/CN=dex-kube-ca"

# Issuer private key and signed by CA
#
openssl genrsa -out dex-issuer-key.pem 2048
openssl req -new -key dex-issuer-key.pem -out dex-issuer-csr.pem -subj "/CN=dex-kube-issuer" -config req.cnf
openssl x509 -req -in dex-issuer-csr.pem -CA dex-ca-cert.pem -CAkey dex-ca-key.pem -CAcreateserial -out dex-issuer-cert.pem -days 9999 -extensions v3_req -extfile req.cnf

cd -


DEX='https:\/\/dex.'${CLUSTER_NAME}

sed 's/^/      /' dex/ca/dex-ca-cert.pem  > dex/ca/temp.txt
sed -i -e '/<<URL>>/{r dex/ca/temp.txt' -e 'd' -e '}' permissions/permissions_scaffold
sed -i 's/<<DEX_ENDPOINT>>/'${DEX}'/g' permissions/permissions_scaffold

cat infrastructure/vanilla_cluster.yaml | awk '
/api:/ {
    line = $0;
    while ((getline < "permissions/permissions_scaffold") > 0) {print};
    print line;
    next
}
{print}' > infrastructure/dex_cluster.yaml

kops replace -f infrastructure/dex_cluster.yaml --state ${KOPS_STATE_STORE}
kops update cluster ${CLUSTER_NAME} --state ${KOPS_STATE_STORE} --yes

watch -d 'kubectl get nodes -o wide; kubectl get pods --all-namespaces'
