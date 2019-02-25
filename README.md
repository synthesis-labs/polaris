# Polaris

*Polaris development currently in **pre-release***

```
              .__               .__
______   ____ |  | _____ _______|__| ______
\____ \ /  _ \|  | \__  \\_  __ \  |/  ___/
|  |_> >  <_> )  |__/ __ \|  | \/  |\___ \
|   __/ \____/|____(____  /__|  |__/____  >
|__|                    \/ by synthesis \/

```

# Overview

Polaris is an open-source, opiniated & validated architecture for hyper-scale enterprise clusters that allows for easy setup of a cluster with all the essentials ready for application development and deployment. The authors of Polaris believe that event-driven microservice architectures will eat the current legacy RESTful request/response world, and therefore a slant towards hyper-scale, streaming technology is evident in the Polaris design.

Polaris has the following features:

## Platform
- Kubernetes
- CoreOS (CoreOS-stable-1855.4.0-hvm)

## Authorization, Authentication and Access Control
- RBAC enabled
- DEX & Static Password login (for kubectl credential)

## Monitoring
- Includes Prometheus Operator (& Kube-Prometheus collectors)
- Grafana pre-configured with basic graphs

## Networking
- Ingress-controller setup
- External DNS to Route53
- Cilium

## Autoscaling
- Cluster Autoscaler enabled

## CI/CD and Deployments
- Flux for CD pipeline and automated deployments
- Helm installed
- AWS Service Operator installed (for auto-creation of ECRs)

## Streaming
- Confluent Platform Open-source (all components from cp-helm-charts)
- Landoop Schema Registry UI
- Landoop Topics UI
- Landoop Connect UI

# Principles

Polaris is __built, governed__ and __benchmarked__ against the following principles:

- Fully Automated
- Batteries Included
- Core Kubernetes
- Scalable
- Secure
- Immutable
- Platform Agnostic
- Customizable

For a more detailed look at the Principles and Architecture of Polaris please view [ARCHITECTURE.md](./ARCHITECTURE.md).

# Provisioning a polaris cluster on AWS

## What you'll need:

- Registered domain name
- Route53 Hosted Zone
- S3 state bucket
- IAM User with access key for kops with the following permissions:
  * AmazonEC2FullAccess
  * IAMFullAccess
  * AmazonS3FullAccess
  * AmazonVPCFullAccess
  * AmazonRoute53FullAccess

You can view the [kops aws docs](https://github.com/kubernetes/kops/blob/master/docs/aws.md) for more info.

1. Install Helm, a package manager for Kubernetes

```
  The Helm client can be installed either from source, or from pre-built binary releases.

  From Snap(Linux)
  $ sudo snap install helm --classic

  macOS
  $ brew install kubernetes-helm

  From Chocolatey
  $ choco install kubernetes-helm
```

2. Run cluster script which creates your vanilla cluster it also generates yaml files in infrastructure/

```
$ sudo ./run-cluster

Wait for cluster to come up it should have atleast one master node and one worker node in status READY also make sure all operators are READY
```

3. Run polaris script which install polaris operators on your cluster

```
$ sudo ./run-polaris
```

4. Install polaris-kafka

```
$ helm --name polaris-kafka-cp-kafka --namespace app install polaris-kafka/

Deploy other containers to this namespace to interact with Kafka topics
```

5. Cleanup

```
$ kops delete cluster kops delete cluster example.cluster.k8s --state s3://{bucket_name} --yes

Also remove files from dex folder and revert all changes in git to start again.
```

## Other administrative stuff

- Shell access to the cluster (using creators id_rsa):
```
$ ssh -i ~/.ssh/polaris@api.example.cluster.k8s
```

## Related Polaris Projects

- The Polaris Operator Project https://github.com/synthesis-labs/polaris-operator
- The Polaris CLI Project https://github.com/synthesis-labs/polaris-cli
- The Polaris Scaffolds(List Of Published Polaris Scaffolds) https://github.com/synthesis-labs/polaris-scaffolds

There's it!
