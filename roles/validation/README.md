# Role: validation

Runs against the first control-plane node as the final gate of the pipeline.
Entirely read-only (aside from one throwaway `busybox` debug pod used to
verify DNS, which self-deletes via `--rm`).

## Responsibilities
1. **Nodes** — every node reports `Ready=True`
2. **Control plane** — `kube-apiserver`, `kube-controller-manager`,
   `kube-scheduler`, `etcd` static pods are `Running` on every control-plane node
3. **API server** — `/healthz` returns `ok`
4. **etcd** — `etcdctl endpoint health --cluster` reports every endpoint healthy
5. **CoreDNS** — minimum ready replica count met, and an in-cluster
   `nslookup kubernetes.default.svc.cluster.local` resolves successfully
6. **Pods** — no pod cluster-wide is outside `Running`/`Succeeded`

Any assertion failure fails the play. This role deliberately runs **last**,
after Helm platform components, so a genuinely broken cluster is caught
before being handed off to Argo CD / application teams.

## Tags
`validation`, `nodes`, `control_plane`, `api_server`, `etcd`, `coredns`, `pods`, `summary`
