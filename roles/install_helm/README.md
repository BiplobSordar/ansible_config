# Role: install_helm

Runs against the first control-plane node.

## Responsibilities
1. Install the Helm binary (`helm_version`), idempotent — skips download if
   the correct version is already present
2. Add the required chart repositories
3. `helm upgrade --install` (via `kubernetes.core.helm`) the platform
   components ONLY:
   - Ingress NGINX
   - Metrics Server
   - cert-manager
   - AWS EBS CSI Driver
   - Cluster Autoscaler
   - Argo CD

Application workloads are explicitly **out of scope** — Argo CD (deployed
here, configured with app-of-apps elsewhere) owns that layer per the
architecture.

## Variables
See `group_vars/all.yml -> helm_charts` for chart repos/versions/namespaces.
Per-chart Helm values live in `templates/values/*.yaml.j2`.

## Tags
`install_helm`, `helm_binary`, `helm_charts`
