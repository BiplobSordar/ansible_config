# Role: kubernetes

Verifies kubeadm/kubelet (and kubectl on control-plane nodes) that ship
pre-installed on the Golden AMI. Does **not** install any Kubernetes package.

## Responsibilities
- Verify kubeadm/kubelet/kubectl versions match `kubernetes_expected_version`
- Verify kubeadm, kubelet, and kubectl (control-plane only) are apt-marked `hold`
- Verify the `kubelet.service` systemd unit exists (does not require it to be
  `running`, since kubelet legitimately crash-loops before `kubeadm init/join`)

## Tags
`kubernetes`, `verify`, `kubeadm`, `kubelet`, `kubectl`, `hold`, `service`
