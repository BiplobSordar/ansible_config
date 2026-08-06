# Role: bootstrap_control_plane

Targets **only** the first control-plane node
(`groups['control_plane'][0]`, see `playbooks/04-bootstrap-control-plane.yml`).

## Responsibilities
1. Render `kubeadm-init-config.yaml` from Terraform-sourced variables
   (`control_plane_endpoint`, `pod_network_cidr`, `service_cidr`, etc.)
2. Run `kubeadm init` **once**, guarded by `/etc/kubernetes/.ansible-bootstrap-complete`
3. Configure `kubectl` for root via `admin.conf`
4. Wait for `/healthz` and the node's own `Ready` condition
5. Mint fresh bootstrap token, re-upload certs, and derive:
   - worker join command
   - control-plane join command (`--control-plane --certificate-key ...`)
   - certificate key
6. `fetch` all artifacts to `{{ local_artifacts_dir }}` on the Ansible
   control node so `join_control_plane` and `join_workers` can consume them

## Idempotency notes
- `kubeadm init` only runs when the marker file is absent.
- Join credentials are **always regenerated** on every run since kubeadm
  tokens/certificate-keys expire — this is safe and does not disrupt an
  already-joined cluster.

## Tags
`bootstrap_control_plane`
