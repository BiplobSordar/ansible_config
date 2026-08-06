# Role: containerd

Verifies the containerd container runtime that ships pre-installed on the
Golden AMI. Does **not** install containerd.

## Responsibilities
- Verify containerd binary/version meets minimum requirement
- Verify the `containerd` systemd service is running
- Verify `SystemdCgroup = true` in `/etc/containerd/config.toml`, correcting
  drift with a single idempotent line replacement (restarts only on change)
- Create `/etc/crictl.yaml` **only if it does not already exist**

## Handlers
- `Restart containerd` — fired only when the SystemdCgroup line actually changes.

## Tags
`containerd`, `verify`, `config`, `crictl`
