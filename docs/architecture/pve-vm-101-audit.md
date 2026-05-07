# PVE VM 101 audit

Observed live from `kpihx-pve`:

```text
vmid: 101
name: fluid-node-pve
status: running
agent: enabled=1
ciuser: kpihx
ipconfig0: 10.10.10.11/24
memory: 4096
cores: 2
ostype: l26
cloud-init: yes
```

What is known:

```text
- the VM exists
- it is running
- it is Linux-class
- it has cloud-init
- it reaches a login prompt on serial console
```

What is not yet confirmed:

```text
- exact distro string from inside guest
- SSH reachability on port 22 from the PVE host
```

Read next:

```text
docs/architecture/setup-existing-node-debian.md
```
