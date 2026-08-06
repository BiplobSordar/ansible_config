# Role: common

Verification-only role. Confirms that the Golden AMI's baseline OS
configuration (OS/kernel version, swap disabled, kernel modules, sysctl
flags, chrony, Python, required packages) matches expectations.

**This role installs nothing.** Any drift from the expected state causes an
`ansible.builtin.assert` failure so that broken AMIs are caught before
`kubeadm init`/`join` ever run.

## Variables (see `defaults/main.yml`)

| Variable | Purpose |
|---|---|
| `common_expected_swap_kb` | Expected swap size in kB (0 = disabled) |
| `common_expected_kernel_modules` | Kernel modules that must be loaded |
| `common_expected_sysctl` | Required sysctl key/value pairs |
| `common_expected_packages` | apt packages that must already be installed |
| `common_chrony_service_name` | systemd unit name for chrony |

## Tags

`common`, `verify`, `os`, `swap`, `kernel`, `sysctl`, `chrony`, `python`, `packages`
