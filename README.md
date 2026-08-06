# Enterprise MERN DevOps Platform — Ansible Configuration Layer

Configures AWS EC2 infrastructure (already created by Terraform) and
bootstraps a production Kubernetes cluster, up to and including platform
components installed via Helm. Application deployment is Argo CD's
responsibility and is explicitly out of scope for this repository.

```
Terraform → AWS Infrastructure → Ansible (this repo) → Helm → Argo CD → Apps
```

## Architecture rules this repo enforces

- **Never hardcodes IPs.** All targeting comes from the `amazon.aws.aws_ec2`
  dynamic inventory plugin, resolving live EC2 tags set by Terraform.
- **Never reinstalls Golden AMI software.** `common`, `containerd`, and
  `kubernetes` roles are verify-only. Only `/etc/crictl.yaml` may be created
  by `containerd`, and only if it's missing.
- **Strict separation of concerns.** Ansible configures infra and bootstraps
  Kubernetes; Helm installs platform components only; Argo CD owns app
  deployment. No role in this repo touches application workloads.
- **Idempotent everywhere.** Every role can be re-run safely — bootstrap and
  join operations are guarded by marker files; worker joins are ASG-safe.

## Prerequisites

1. Terraform has already applied and tagged every EC2 instance with:
   `Project`, `Environment`, `Role` (`control-plane` | `worker` | `jenkins`),
   `Node` (e.g. `control-plane-0`).
2. Terraform outputs (or your CI job) export the following environment
   variables before running Ansible:

   ```bash
   export AWS_REGION="us-east-1"
   export PROJECT_NAME="mern-platform"
   export ENVIRONMENT="production"
   export CONTROL_PLANE_ENDPOINT="<internal ALB/NLB DNS name from Terraform>"
   ```

3. SSH access to nodes as `ubuntu` with a key loaded in your agent (or set
   `ansible_ssh_private_key_file` in inventory/group_vars as needed).
4. Ansible ≥ 2.15, Python 3, and the collections in `requirements.yml`:

   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

## Repository layout

```
ansible-mern-platform/
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── aws_ec2.yml            # AWS EC2 dynamic inventory (tag-driven)
│   └── group_vars/
│       ├── all.yml            # cluster-wide vars (versions, CIDRs, Helm charts)
│       ├── control_plane.yml
│       └── workers.yml
├── playbooks/
│   ├── site.yml                        # master entrypoint, runs all 9 stages in order
│   ├── 01-common.yml
│   ├── 02-containerd.yml
│   ├── 03-kubernetes.yml
│   ├── 04-bootstrap-control-plane.yml  # targets control_plane[0] only
│   ├── 05-join-control-plane.yml       # targets control_plane[1:]
│   ├── 06-install-cni.yml
│   ├── 07-join-workers.yml             # targets workers (ASG-safe, re-runnable)
│   ├── 08-install-helm.yml
│   └── 09-validation.yml
├── roles/
│   ├── common/                # verify-only OS baseline
│   ├── containerd/             # verify + crictl.yaml-if-missing
│   ├── kubernetes/             # verify kubeadm/kubelet/kubectl + hold state
│   ├── bootstrap_control_plane/# kubeadm init, join-credential generation
│   ├── join_control_plane/     # kubeadm join --control-plane, etcd validation
│   ├── install_cni/            # Calico
│   ├── join_workers/           # kubeadm join (workers), ASG-safe
│   ├── install_helm/           # Helm binary + platform charts only
│   └── validation/             # final cluster-wide health gate
└── .cluster-artifacts/         # (generated at runtime, git-ignored) admin.conf,
                                 # join commands, certificate key
```

## Running

```bash
# Full pipeline
ansible-playbook playbooks/site.yml

# Single stage (e.g. after an ASG scale-out event, only join new workers)
ansible-playbook playbooks/07-join-workers.yml

# Inspect resolved inventory before running anything
ansible-inventory -i inventory/aws_ec2.yml --graph

# Restrict to a subset
ansible-playbook playbooks/site.yml --limit control_plane
ansible-playbook playbooks/site.yml --tags kubernetes,containerd
```

## Generated artifacts

`bootstrap_control_plane` fetches the following to
`.cluster-artifacts/<cluster_name>/` on the Ansible control node so later
plays (running against different hosts) can consume them:

| File | Contents |
|---|---|
| `admin.conf` | Cluster admin kubeconfig |
| `worker-join-command.sh` | `kubeadm join` command for workers |
| `control-plane-join-command.sh` | `kubeadm join --control-plane --certificate-key ...` |
| `certificate-key.txt` | Certificate key for control-plane joins |

These are regenerated on every run (kubeadm tokens/certificate-keys expire)
and are git-ignored by design — treat them as secrets.

## Extending

- Add/adjust Helm-managed platform components in
  `inventory/group_vars/all.yml -> helm_charts` and
  `roles/install_helm/templates/values/*.yaml.j2`.
- Application Argo CD `Application`/`ApplicationSet` manifests belong in a
  **separate** GitOps repository — not here.
