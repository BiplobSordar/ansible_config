# Role: install_cni

Runs against the first control-plane node. Installs Calico (the only CNI
this project uses) and waits for Ready.

## Responsibilities
1. Download the pinned Calico manifest (`calico_version` in `group_vars/all.yml`)
2. `kubectl apply` it via `kubernetes.core.k8s` (idempotent)
3. Wait until every node currently registered in the API reports `Ready`

## Notes
At this point in the playbook order, only control-plane nodes have joined -
worker readiness is validated later by the `validation` role after
`join_workers` runs.

## Tags
`install_cni`
