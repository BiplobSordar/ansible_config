# Kubernetes Infrastructure Ansible

Production-grade Ansible automation for provisioning, configuring, joining, and validating a highly available Kubernetes cluster on AWS EC2.

This repository is responsible for the **configuration and software layer** of the Kubernetes platform. AWS infrastructure such as VPCs, subnets, security groups, EC2 instances, load balancers, NAT gateways, RDS, and IAM resources are created by Terraform.

Ansible takes the infrastructure created by Terraform and turns the EC2 instances into a fully functional Kubernetes platform.

---

## Architecture

```text
                         AWS Infrastructure
                              │
                              │ Terraform
                              ▼
                    ┌─────────────────────┐
                    │     AWS EC2 Nodes   │
                    │                     │
                    │  Control Plane × 3  │
                    │  Workers × N        │
                    └──────────┬──────────┘
                               │
                               │ Terraform outputs
                               ▼
                    ┌─────────────────────┐
                    │     outputs.json    │
                    └──────────┬──────────┘
                               │
                               │ generate_tf_vars.py
                               ▼
                    ┌─────────────────────┐
                    │ Ansible Variables   │
                    │ terraform.yml       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Dynamic AWS         │
                    │ Inventory           │
                    │ aws_ec2.yml         │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      Ansible        │
                    │      site.yml       │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
      Common              Containerd           Kubernetes
          │                    │                    │
          │                    │                    ▼
          │                    │             kubeadm init
          │                    │                    │
          │                    │                    ▼
          │                    │          Control Plane #1
          │                    │                    │
          │                    │                    ▼
          │                    │          Control Plane #2/#3
          │                    │                    │
          │                    │                    ▼
          │                    │             Worker Nodes
          │                    │
          └────────────────────┴────────────────────┐
                                                   │
                                                   ▼
                                               Calico CNI
                                                   │
                                                   ▼
                                                 Helm
                                                   │
                         ┌─────────────────────────┼─────────────────────┐
                         │                         │                     │
                         ▼                         ▼                     ▼
                    Platform                  Monitoring            Validation
                         │                         │                     │
                         │                         │                     │
              ┌──────────┼──────────┐      ┌──────┼────────┐            │
              │          │          │      │      │        │            │
              ▼          ▼          ▼      ▼      ▼        ▼            ▼
           Ingress    cert-manager  Argo  Prometheus Grafana Loki     Checks
           NGINX                    CD                     │
              │          │          │                      ▼
              │          │          │                   Promtail
              │          │          │
              └──────────┴──────────┴───────────────────────────────┐
                                                                    │
                                                                    ▼
                                                         Ready Kubernetes Platform
```

---

# Responsibilities

This repository handles:

* EC2 host preparation
* Kubernetes prerequisites
* containerd configuration
* Kubernetes package installation and verification
* Kubernetes control-plane initialization
* Additional control-plane joining
* Worker-node joining
* Calico CNI installation
* Helm installation
* Kubernetes platform components
* Monitoring stack
* Cluster validation
* Terraform output integration
* AWS dynamic inventory

Terraform is responsible for infrastructure.

Ansible is responsible for configuration and cluster software.

---

# Repository Structure

```text
ansible_config/
│
├── README.md
├── ansible.cfg
├── ansible_check_environment.sh
├── requirements.yml
│
├── inventory/
│   └── aws_ec2.yml
│
├── playbooks/
│   ├── 01-common.yml
│   ├── 02-containerd.yml
│   ├── 03-kubernetes.yml
│   ├── 04-bootstrap-control-plane.yml
│   ├── 05-join-control-plane.yml
│   ├── 06-install-cni.yml
│   ├── 07-join-workers.yml
│   ├── 08-install-helm.yml
│   ├── 09-install-platform.yml
│   ├── 10-validation.yml
│   ├── 11-install-monitoring.yml
│   └── site.yml
│
├── roles/
│   ├── common/
│   ├── containerd/
│   ├── kubernetes/
│   ├── bootstrap_control_plane/
│   ├── join_control_plane/
│   ├── install_cni/
│   ├── join_workers/
│   ├── install_helm/
│   ├── install_platform/
│   ├── install_monitoring/
│   └── validation/
│
├── scripts/
│   └── generate_tf_vars.py
│
├── terraform/
│   └── outputs.json
│
└── vars/
    ├── artifacts.yml
    ├── calico.yml
    ├── containerd.yml
    ├── control_plane.yml
    ├── defaults.yml
    ├── helm.yml
    ├── kubernetes.yml
    ├── terraform.yml
    ├── validation.yml
    └── workers.yml
```

---

# Infrastructure and Configuration Separation

The project intentionally separates infrastructure provisioning from configuration management.

```text
Terraform
   │
   ├── VPC
   ├── Subnets
   ├── Security Groups
   ├── EC2
   ├── Load Balancer
   ├── IAM
   ├── NAT Gateway
   ├── RDS
   └── Other AWS resources
          │
          ▼
     outputs.json
          │
          ▼
       Ansible
          │
          ├── OS configuration
          ├── containerd
          ├── Kubernetes
          ├── kubeadm
          ├── Calico
          ├── Helm
          ├── Platform
          ├── Monitoring
          └── Validation
```

This means Ansible does not create AWS infrastructure.

It consumes the infrastructure created by Terraform.

---

# Terraform Output Integration

Terraform generates machine-readable infrastructure information.

The expected file is:

```text
terraform/outputs.json
```

The Python script:

```text
scripts/generate_tf_vars.py
```

converts Terraform outputs into Ansible-compatible variables.

The general flow is:

```text
Terraform
   │
   ▼
terraform/outputs.json
   │
   ▼
scripts/generate_tf_vars.py
   │
   ▼
vars/terraform.yml
   │
   ▼
Ansible
```

The Terraform variables are then available to the Ansible roles and playbooks.

Typical infrastructure information may include:

* AWS region
* project name
* environment
* cluster name
* VPC information
* control-plane endpoint
* load balancer information
* worker information
* SSM parameters
* other Terraform-generated values

---

# AWS Dynamic Inventory

The repository uses the AWS EC2 dynamic inventory plugin:

```text
inventory/aws_ec2.yml
```

Instead of maintaining static IP addresses manually, Ansible discovers EC2 instances directly from AWS.

The inventory can group nodes according to AWS tags and discovered attributes.

Typical Kubernetes groups are:

```text
control-plane
worker
bootstrap
environment
project
```

This makes the inventory suitable for dynamic environments where worker nodes may be created or replaced by an Auto Scaling Group.

---

# Ansible Execution Flow

The complete installation sequence is:

```text
01 Common
     │
     ▼
02 containerd
     │
     ▼
03 Kubernetes packages
     │
     ▼
04 Bootstrap Control Plane
     │
     ▼
05 Join Additional Control Planes
     │
     ▼
06 Install Calico CNI
     │
     ▼
07 Join Workers
     │
     ▼
08 Install Helm
     │
     ▼
09 Install Platform
     │
     ▼
10 Validation
     │
     ▼
11 Monitoring
```

The main orchestration file is:

```text
playbooks/site.yml
```

---

# Playbooks

## 01-common.yml

Prepares the operating system for Kubernetes.

The `common` role handles:

* OS verification
* hostname configuration
* package verification
* Python verification
* swap verification
* kernel modules
* sysctl configuration
* time synchronization
* system prerequisites

The objective is to make every Kubernetes node consistent before installing Kubernetes.

---

# 02-containerd.yml

Installs and validates containerd.

The `containerd` role handles:

* containerd configuration
* service verification
* runtime version verification
* CRI configuration
* `crictl` configuration

The role creates:

```text
/etc/crictl.yaml
```

so Kubernetes tooling can communicate with containerd through the CRI interface.

The runtime architecture is:

```text
Kubernetes
     │
     ▼
   CRI
     │
     ▼
containerd
     │
     ▼
container runtime
```

---

# 03-kubernetes.yml

Installs and verifies Kubernetes components.

The `kubernetes` role verifies:

```text
kubeadm
kubelet
kubectl
```

It also validates:

* Kubernetes package versions
* kubelet service
* held Kubernetes packages
* required binaries

At this stage the node has Kubernetes software installed, but the cluster itself has not necessarily been initialized.

---

# 04-bootstrap-control-plane.yml

Initializes the first Kubernetes control-plane node.

The `bootstrap_control_plane` role performs the initial:

```text
kubeadm init
```

The role handles:

* kubeadm configuration
* control-plane initialization
* API server availability
* kubectl configuration
* join credential generation
* artifact retrieval
* SSM parameter storage where configured

The generated kubeadm configuration is based on:

```text
templates/kubeadm-init-config.yaml.j2
```

The first control-plane node becomes the initial cluster authority.

---

# 05-join-control-plane.yml

Joins additional control-plane nodes to the existing cluster.

The architecture becomes:

```text
             Kubernetes API
                    │
          ┌─────────┼─────────┐
          │         │         │
          ▼         ▼         ▼
       CP #1      CP #2      CP #3
          │         │         │
          └─────────┼─────────┘
                    │
                 etcd
```

The `join_control_plane` role handles:

* retrieving join information
* executing `kubeadm join --control-plane`
* configuring kubectl
* waiting for node readiness
* validating etcd participation

This creates a highly available Kubernetes control plane.

---

# 06-install-cni.yml

Installs the Kubernetes Container Network Interface.

The repository uses Calico.

The `install_cni` role:

* installs Calico
* waits for the Calico DaemonSet
* waits for cluster networking to converge
* verifies that nodes become Ready

The networking architecture is:

```text
Pod
 │
 ▼
Calico
 │
 ▼
Kubernetes Node
 │
 ▼
AWS Network
```

The configured Pod CIDR and networking values are maintained in:

```text
vars/calico.yml
```

---

# 07-join-workers.yml

Joins worker nodes to the Kubernetes cluster.

The `join_workers` role is designed to work with dynamically created workers.

This is particularly important when workers are managed through an AWS Auto Scaling Group.

The role:

* retrieves worker join credentials
* executes `kubeadm join`
* waits for the Kubernetes node to become Ready
* verifies node readiness

The resulting architecture is:

```text
                    Control Plane
                 ┌───────┼───────┐
                 │       │       │
                CP1     CP2     CP3
                 │       │       │
                 └───────┼───────┘
                         │
                  Kubernetes API
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
       Worker 1       Worker 2       Worker N
```

---

# 08-install-helm.yml

Installs Helm on the Kubernetes administration/control-plane environment.

Helm is used as the package manager for Kubernetes applications.

After Helm is installed, platform components can be deployed using charts.

The repository uses Helm for components such as:

* Ingress NGINX
* cert-manager
* Metrics Server
* AWS EBS CSI Driver
* Cluster Autoscaler
* Argo CD
* Prometheus
* Grafana
* Loki
* Promtail

---

# 09-install-platform.yml

Installs the Kubernetes platform layer.

The `install_platform` role manages Helm repositories, values, and charts.

The platform components include:

## Ingress NGINX

Provides Kubernetes HTTP/HTTPS ingress functionality.

```text
Internet
   │
   ▼
AWS Load Balancer
   │
   ▼
Ingress NGINX
   │
   ▼
Kubernetes Service
   │
   ▼
Application Pods
```

## cert-manager

Automates TLS certificate management inside Kubernetes.

## Metrics Server

Provides Kubernetes resource metrics such as:

* CPU
* memory
* node metrics
* pod metrics

## AWS EBS CSI Driver

Allows Kubernetes workloads to use AWS EBS volumes through Kubernetes PersistentVolumes.

## Cluster Autoscaler

Allows Kubernetes worker capacity to scale according to pending workloads and cluster requirements.

## Argo CD

Provides GitOps-based continuous delivery.

The intended deployment model is:

```text
Git Repository
      │
      ▼
    Argo CD
      │
      ▼
 Kubernetes
      │
      ▼
 Application
```

---

# 10-validation.yml

The validation role performs final cluster health checks.

Validation is intentionally performed after the infrastructure and platform components are installed.

The validation layer checks:

```text
Kubernetes Nodes
       │
       ▼
Control Plane
       │
       ▼
API Server
       │
       ▼
etcd
       │
       ▼
CoreDNS
       │
       ▼
Kubernetes Pods
       │
       ▼
Platform Components
       │
       ▼
Monitoring Stack
```

---

# Validation Checks

The `validation` role contains separate validation tasks.

```text
roles/validation/tasks/
├── main.yml
├── validate_nodes.yml
├── validate_control_plane.yml
├── validate_api_server.yml
├── validate_etcd_health.yml
├── validate_coredns.yml
├── validate_pods.yml
├── validate_platform.yml
├── validate_monitoring.yml
└── summary.yml
```

---

## Node Validation

The validation checks all Kubernetes nodes.

The expected state is:

```text
Ready
```

Unhealthy states such as:

```text
False
Unknown
```

cause validation to fail.

---

## Control Plane Validation

The following static Kubernetes components are validated:

```text
kube-apiserver
kube-controller-manager
kube-scheduler
etcd
```

These components are deployed as static pods on control-plane nodes.

---

## API Server Validation

The API server is checked using:

```text
kubectl get --raw=/healthz
```

The expected result is:

```text
ok
```

If the API server does not return `ok`, validation fails.

---

## etcd Validation

The validation role dynamically discovers the local etcd pod rather than assuming that the pod name matches the EC2 instance ID.

This is important because kubeadm static pod names can differ depending on node naming.

The health check uses:

```text
etcdctl endpoint health
```

with the Kubernetes etcd certificates:

```text
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/etcd/server.crt
/etc/kubernetes/pki/etcd/server.key
```

Expected state:

```text
healthy
```

---

# CoreDNS Validation

CoreDNS is checked using the Kubernetes Deployment status.

The validation verifies that the required number of replicas are Ready.

This confirms that cluster DNS is operational.

DNS is critical for Kubernetes service discovery:

```text
Application Pod
      │
      ▼
Kubernetes DNS
      │
      ▼
Service
      │
      ▼
Backend / Database / Internal Service
```

---

# Pod Validation

The validation role retrieves Kubernetes pods across all namespaces.

This provides visibility into:

```text
Pending
Running
Completed
CrashLoopBackOff
ImagePullBackOff
Error
Unknown
```

The validation output can therefore be used to quickly identify workloads that require investigation.

---

# Platform Validation

The platform validation verifies the existence of required:

* namespaces
* deployments
* daemonsets

The platform resources are defined using variables such as:

```text
validation_required_namespaces
validation_required_deployments
validation_required_daemonsets
```

This allows the validation logic to remain reusable without hard-coding every resource into the task files.

---

# Monitoring Validation

The monitoring layer validates:

```text
Prometheus
Grafana
Alertmanager
Loki
Promtail
kube-state-metrics
```

The monitoring namespace is:

```text
monitoring
```

The validation checks:

### Deployments

```text
kube-prometheus-stack-grafana
kube-prometheus-stack-operator
kube-prometheus-stack-kube-state-metrics
```

### StatefulSets

```text
prometheus-kube-prometheus-stack-prometheus
alertmanager-kube-prometheus-stack-alertmanager
loki
```

### DaemonSets

```text
promtail
```

Promtail is expected to run on every Kubernetes node.

---

# 11-install-monitoring.yml

The monitoring role installs the observability stack.

The stack consists of:

```text
Prometheus
     │
     ├── Kubernetes metrics
     ├── Node metrics
     └── Application metrics

Grafana
     │
     └── Visualization

Loki
     │
     └── Log storage

Promtail
     │
     └── Log collection
```

The monitoring architecture is:

```text
                     Kubernetes Cluster
                            │
             ┌──────────────┴──────────────┐
             │                             │
          Metrics                         Logs
             │                             │
             ▼                             ▼
        Prometheus                      Promtail
             │                             │
             │                             ▼
             │                           Loki
             │                             │
             └──────────────┬──────────────┘
                            │
                            ▼
                          Grafana
```

Promtail runs as a DaemonSet so that each Kubernetes node has a log collector.

---

# Monitoring Configuration

Monitoring templates are located at:

```text
roles/install_monitoring/templates/
```

Files:

```text
kube-prometheus-stack.yaml.j2
loki.yaml.j2
promtail.yaml.j2
```

These templates are rendered into configuration files before Helm installation.

The monitoring role is split into:

```text
repositories.yml
values.yml
charts.yml
main.yml
```

This keeps repository configuration, values generation, and chart installation separated.

---

# Promtail Log Collection

Promtail runs as a DaemonSet:

```text
Node 1 ── Promtail
Node 2 ── Promtail
Node 3 ── Promtail
Node 4 ── Promtail
Node 5 ── Promtail
Node 6 ── Promtail
```

It reads Kubernetes/container log files from the node and sends them to Loki.

Conceptually:

```text
Container
   │
   ▼
Node log files
   │
   ▼
Promtail
   │
   ▼
Loki
   │
   ▼
Grafana
```

---

# Variables

Global configuration is separated into the `vars` directory.

```text
vars/
├── artifacts.yml
├── calico.yml
├── containerd.yml
├── control_plane.yml
├── defaults.yml
├── helm.yml
├── kubernetes.yml
├── terraform.yml
├── validation.yml
└── workers.yml
```

This separation prevents individual roles from becoming tightly coupled to one large configuration file.

---

# Variable Responsibilities

## terraform.yml

Contains Terraform-generated infrastructure values.

Examples include:

```text
AWS region
project
environment
cluster
network information
control-plane endpoint
```

---

## kubernetes.yml

Contains Kubernetes configuration such as:

```text
Kubernetes version
service CIDR
pod CIDR
control-plane configuration
```

---

## containerd.yml

Contains container runtime configuration.

---

## calico.yml

Contains Calico networking configuration.

---

## control_plane.yml

Contains control-plane-specific configuration.

---

## workers.yml

Contains worker-node configuration.

---

## helm.yml

Contains Helm-related configuration and chart information.

---

## validation.yml

Contains validation requirements.

For example:

```text
validation_admin_conf_path
validation_coredns_min_ready
validation_monitoring_namespace
validation_monitoring_deployments
validation_monitoring_statefulsets
validation_monitoring_daemonsets
```

This allows validation rules to be changed without modifying the validation task logic.

---

# Ansible Roles

## common

Prepares and validates the operating system.

```text
common/
├── tasks/
│   ├── hostname.yml
│   ├── kernel_modules.yml
│   ├── load_vars.yml
│   ├── sysctl.yml
│   ├── verify_chrony.yml
│   ├── verify_hostname.yml
│   ├── verify_kernel_modules.yml
│   ├── verify_os.yml
│   ├── verify_packages.yml
│   ├── verify_python.yml
│   ├── verify_swap.yml
│   └── verify_sysctl.yml
```

---

## containerd

Configures the Kubernetes container runtime.

---

## kubernetes

Installs and validates Kubernetes binaries and services.

---

## bootstrap_control_plane

Creates the initial Kubernetes control plane using kubeadm.

---

## join_control_plane

Adds additional control-plane nodes.

---

## install_cni

Installs Calico and waits for cluster networking to become operational.

---

## join_workers

Adds worker nodes to the cluster.

The role is designed to work with dynamically discovered workers.

---

## install_helm

Installs Helm.

---

## install_platform

Installs the Kubernetes platform layer using Helm.

---

## install_monitoring

Installs the observability stack.

---

## validation

Performs final cluster health verification.

---

# Role Design

Each role follows the standard Ansible role structure.

Example:

```text
role/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── meta/
│   └── main.yml
├── tasks/
│   └── main.yml
├── templates/
├── vars/
│   └── main.yml
└── README.md
```

The main task file acts as the entry point and includes smaller task files when necessary.

For example:

```text
main.yml
   │
   ├── repositories.yml
   ├── values.yml
   └── charts.yml
```

This keeps the code modular and easier to maintain.

---

# Idempotency

The playbooks are designed to be safely re-run.

For example:

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/site.yml
```

Running the playbook again should not recreate an already functioning Kubernetes cluster unnecessarily.

The use of:

* Ansible modules
* Helm upgrade/install
* Kubernetes resource checks
* readiness checks
* validation tasks

helps maintain idempotent behavior.

---

# Running the Complete Installation

Before running the installation, verify that:

* Terraform infrastructure exists
* EC2 instances are running
* AWS credentials are available
* Terraform outputs are available
* Ansible dependencies are installed
* AWS dynamic inventory can discover the nodes
* SSH access is working
* Kubernetes security-group rules are correct

Then run:

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/site.yml
```

---

# Running Individual Stages

The individual playbooks can also be executed separately.

## Common

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/01-common.yml
```

## Containerd

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/02-containerd.yml
```

## Kubernetes

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/03-kubernetes.yml
```

## Bootstrap Control Plane

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/04-bootstrap-control-plane.yml
```

## Join Control Planes

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/05-join-control-plane.yml
```

## Calico

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/06-install-cni.yml
```

## Workers

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/07-join-workers.yml
```

## Helm

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/08-install-helm.yml
```

## Platform

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/09-install-platform.yml
```

## Validation

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/10-validation.yml
```

## Monitoring

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/11-install-monitoring.yml
```

---

# Running by Tags

The playbooks support tags where configured.

For example:

```bash
ansible-playbook \
  -i inventory/aws_ec2.yml \
  playbooks/11-install-monitoring.yml \
  --tags monitoring
```

---

# Environment Check

Before running the complete automation, the repository provides:

```text
ansible_check_environment.sh
```

Run:

```bash
./ansible_check_environment.sh
```

This can be used as a pre-flight check for the Ansible execution environment.

---

# Ansible Dependencies

Required Ansible collections are defined in:

```text
requirements.yml
```

Install them using:

```bash
ansible-galaxy collection install -r requirements.yml
```

The project uses Ansible modules for:

* AWS
* Kubernetes
* Helm
* system configuration

---

# Kubernetes Access

The Kubernetes administrator configuration is:

```text
/etc/kubernetes/admin.conf
```

The validation role uses:

```text
/etc/kubernetes/admin.conf
```

to communicate with the Kubernetes API.

Example:

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get nodes
```

---

# Final Cluster State

After successful execution, the expected architecture is:

```text
AWS
│
├── Control Plane 1
│   ├── kube-apiserver
│   ├── kube-controller-manager
│   ├── kube-scheduler
│   └── etcd
│
├── Control Plane 2
│   ├── kube-apiserver
│   ├── kube-controller-manager
│   ├── kube-scheduler
│   └── etcd
│
├── Control Plane 3
│   ├── kube-apiserver
│   ├── kube-controller-manager
│   ├── kube-scheduler
│   └── etcd
│
└── Worker Nodes
    ├── kubelet
    ├── containerd
    ├── Calico
    └── Promtail
```

The Kubernetes platform contains:

```text
Ingress NGINX
cert-manager
Metrics Server
AWS EBS CSI Driver
Cluster Autoscaler
Argo CD
```

The observability layer contains:

```text
Prometheus
Grafana
Alertmanager
Loki
Promtail
kube-state-metrics
Node Exporter
```

---

# Validation Result

A successful validation run ends with a summary similar to:

```text
====================================
 CLUSTER VALIDATION PASSED
 Cluster: k8s-pr
 Nodes: READY
 API Server: HEALTHY
 etcd: HEALTHY
 CoreDNS: HEALTHY
 Prometheus: READY
 Grafana: READY
 Loki: READY
 Promtail: READY
====================================
```

This summary indicates that the major Kubernetes control-plane, networking, platform, and monitoring components passed the configured validation checks.

---

# Troubleshooting

## Check Nodes

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get nodes -o wide
```

---

## Check All Pods

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get pods -A -o wide
```

---

## Check Monitoring

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get pods -n monitoring
```

---

## Check Helm Releases

```bash
helm list -A
```

---

## Check Kubernetes Events

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get events -A \
  --sort-by='.lastTimestamp'
```

---

## Check Promtail

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get daemonset promtail -n monitoring
```

Expected result:

```text
DESIRED   CURRENT   READY
6         6         6
```

The actual number depends on the number of Kubernetes nodes.

---

## Check Loki

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get pods -n monitoring -l app.kubernetes.io/name=loki
```

---

## Check Prometheus

```bash
kubectl \
  --kubeconfig=/etc/kubernetes/admin.conf \
  get pods -n monitoring \
  -l app.kubernetes.io/name=prometheus
```

---

# Important Operational Notes

## Do not manually configure Kubernetes nodes

Node configuration should normally be performed through Ansible.

Manual changes can create configuration drift between nodes.

---

## Do not store infrastructure configuration in multiple places

AWS infrastructure values should originate from Terraform.

The intended flow is:

```text
Terraform
   ↓
outputs.json
   ↓
generate_tf_vars.py
   ↓
Ansible variables
```

---

## Do not hard-code EC2 IP addresses

The AWS dynamic inventory should discover EC2 instances.

This is especially important for worker nodes managed through an Auto Scaling Group.

---

## Protect Terraform Outputs

`terraform/outputs.json` may contain infrastructure information that should not be publicly exposed.

If it contains sensitive values in the future, it must not be committed to Git.

Prefer:

```text
.gitignore
```

for sensitive generated files.

---

# GitOps Relationship

This repository is responsible for creating the Kubernetes platform.

Application deployment can then be handled separately through GitOps.

The intended architecture is:

```text
                    Infrastructure
                         │
                      Terraform
                         │
                         ▼
                      AWS EC2
                         │
                         ▼
                       Ansible
                         │
             ┌───────────┴───────────┐
             │                       │
          Platform                Monitoring
             │                       │
             ▼                       ▼
          Argo CD                Prometheus
             │                   Grafana
             │                   Loki
             │                   Promtail
             │
             ▼
       Application GitOps
             │
             ▼
       Kubernetes Workloads
```

This keeps infrastructure automation and application delivery logically separated.

---

# Design Principles

This repository follows several important principles.

### Infrastructure as Code

AWS resources are managed by Terraform.

### Configuration as Code

Operating-system and Kubernetes configuration are managed by Ansible.

### Kubernetes as Code

Kubernetes platform components are deployed through Helm values and Ansible automation.

### GitOps

Application delivery is handled through Argo CD.

### Dynamic Infrastructure

AWS EC2 instances are discovered dynamically instead of using a static inventory.

### Idempotent Automation

Playbooks are designed to be safely re-run.

### Validation First

Each major infrastructure layer is validated before considering the cluster ready.

### Separation of Concerns

```text
Terraform
    ↓
Infrastructure

Ansible
    ↓
Cluster configuration

Helm
    ↓
Platform applications

Argo CD
    ↓
Application deployment

Prometheus/Grafana/Loki
    ↓
Observability
```

---

# End-to-End Lifecycle

The complete lifecycle of the platform is:

```text
1. Terraform creates AWS infrastructure
                 │
                 ▼
2. EC2 instances become available
                 │
                 ▼
3. Terraform outputs are generated
                 │
                 ▼
4. Ansible discovers EC2 nodes
                 │
                 ▼
5. Common OS configuration
                 │
                 ▼
6. containerd installation
                 │
                 ▼
7. Kubernetes packages installation
                 │
                 ▼
8. First control plane initialized
                 │
                 ▼
9. Additional control planes joined
                 │
                 ▼
10. Calico CNI installed
                 │
                 ▼
11. Worker nodes joined
                 │
                 ▼
12. Helm installed
                 │
                 ▼
13. Kubernetes platform installed
                 │
                 ├── Ingress NGINX
                 ├── cert-manager
                 ├── Metrics Server
                 ├── AWS EBS CSI
                 ├── Cluster Autoscaler
                 └── Argo CD
                 │
                 ▼
14. Monitoring installed
                 │
                 ├── Prometheus
                 ├── Grafana
                 ├── Alertmanager
                 ├── Loki
                 └── Promtail
                 │
                 ▼
15. Final cluster validation
                 │
                 ▼
          Production-ready
          Kubernetes cluster
```

---

# Repository Goal

The goal of this repository is to provide a repeatable and maintainable way to transform newly provisioned AWS EC2 instances into a complete Kubernetes platform.

The desired outcome is:

```text
AWS Infrastructure
       +
Ansible Automation
       +
Kubernetes
       +
Calico
       +
Helm
       +
Platform Services
       +
Monitoring
       +
Validation
       +
GitOps
       │
       ▼
Production Kubernetes Platform
```

The repository should therefore be treated as the **configuration and platform automation layer** of the overall infrastructure system.

Terraform creates the infrastructure.

Ansible configures the infrastructure.

Kubernetes provides the orchestration platform.

Helm installs platform services.

Argo CD manages application delivery.

Prometheus, Grafana, Loki, and Promtail provide observability.
