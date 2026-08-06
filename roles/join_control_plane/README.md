# Role: join_control_plane

Targets `groups['control_plane'][1:]` (every control-plane node except the
bootstrap node).

## Responsibilities
1. `kubeadm join ... --control-plane --certificate-key ...` using the command
   fetched by `bootstrap_control_plane`, guarded by a per-node marker file
2. Configure `kubectl` for root
3. Wait for the node's `Ready` condition
4. Validate the node's stacked etcd member is `Running` and present in
   `etcdctl member list`

## Tags
`join_control_plane`
