# Role: join_workers

Targets `groups['workers']`, resolved dynamically from the AWS EC2 Auto
Scaling Group via the `amazon.aws.aws_ec2` inventory plugin.

## Responsibilities
1. `kubeadm join` using the worker join command fetched by
   `bootstrap_control_plane`, guarded by a per-node marker file
2. Wait for `Ready`, checked by delegating `kubectl` to the first
   control-plane node (workers do not carry kubectl/admin.conf)

## ASG-safety
Because group membership comes from live EC2 tags rather than a static
inventory file, simply re-running the play (e.g. from a cron/Jenkins hook
after a scale-out event) joins any new instances automatically. Already-
joined nodes are no-ops.

## Tags
`join_workers`
