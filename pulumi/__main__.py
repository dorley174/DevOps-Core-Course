import os

import pulumi
import pulumi_yandex as yandex

cfg = pulumi.Config()

# -----------------
# Config (project)
# -----------------
zone = cfg.get("zone") or os.getenv("YC_ZONE") or "ru-central1-a"
subnet_cidr = cfg.get("subnetCidr") or "10.10.0.0/24"
allowed_ssh_cidr = cfg.get("allowedSshCidr") or "0.0.0.0/0"

ssh_user = cfg.get("sshUser") or "ubuntu"
ssh_public_key = cfg.get("sshPublicKey")
ssh_public_key_path = cfg.get("sshPublicKeyPath")

image_family = cfg.get("imageFamily") or "ubuntu-2404-lts"

vm_cores = int(cfg.get("vmCores") or 2)
vm_memory_gb = int(cfg.get("vmMemoryGb") or 1)
vm_core_fraction = int(cfg.get("vmCoreFraction") or 20)

disk_size_gb = int(cfg.get("diskSizeGb") or 10)
disk_type = cfg.get("diskType") or "network-hdd"

platform_id = cfg.get("platformId") or "standard-v2"

# SSH public key: either inline or from file
if not ssh_public_key:
    if ssh_public_key_path:
        path = os.path.expanduser(ssh_public_key_path)
        with open(path, "r", encoding="utf-8") as f:
            ssh_public_key = f.read().strip()
    else:
        raise Exception(
            "Set sshPublicKey (inline) or sshPublicKeyPath (path to .pub) via pulumi config"
        )

# -----------------
# Data: image
# -----------------
image = yandex.get_compute_image(family=image_family)

# -----------------
# Network
# -----------------
net = yandex.VpcNetwork("lab04-net")

subnet = yandex.VpcSubnet(
    "lab04-subnet",
    network_id=net.id,
    zone=zone,
    v4_cidr_blocks=[subnet_cidr],
)

# -----------------
# Security Group
# -----------------
sg = yandex.VpcSecurityGroup(
    "lab04-sg",
    network_id=net.id,
    ingresses=[
        yandex.VpcSecurityGroupIngressArgs(
            protocol="TCP",
            description="SSH",
            v4_cidr_blocks=[allowed_ssh_cidr],
            port=22,
        ),
        yandex.VpcSecurityGroupIngressArgs(
            protocol="TCP",
            description="HTTP",
            v4_cidr_blocks=["0.0.0.0/0"],
            port=80,
        ),
        yandex.VpcSecurityGroupIngressArgs(
            protocol="TCP",
            description="App 5000",
            v4_cidr_blocks=["0.0.0.0/0"],
            port=5000,
        ),
    ],
    egresses=[
        yandex.VpcSecurityGroupEgressArgs(
            protocol="ANY",
            description="Allow all outbound",
            v4_cidr_blocks=["0.0.0.0/0"],
            from_port=0,
            to_port=65535,
        )
    ],
)


# -----------------
# VM
# -----------------
vm = yandex.ComputeInstance(
    "lab04-vm",
    zone=zone,
    platform_id=platform_id,
    resources=yandex.ComputeInstanceResourcesArgs(
        cores=vm_cores,
        memory=vm_memory_gb,
        core_fraction=vm_core_fraction,
    ),
    boot_disk=yandex.ComputeInstanceBootDiskArgs(
        initialize_params=yandex.ComputeInstanceBootDiskInitializeParamsArgs(
            image_id=image.id,
            size=disk_size_gb,
            type=disk_type,
        )
    ),
    network_interfaces=[
        yandex.ComputeInstanceNetworkInterfaceArgs(
            subnet_id=subnet.id,
            nat=True,
            security_group_ids=[sg.id],
        )
    ],
    metadata={
        "ssh-keys": f"{ssh_user}:{ssh_public_key}",
    },
    allow_stopping_for_update=True,
)


def _nat_ip(network_interfaces):
    """Handle both dict-style and typed outputs."""
    ni0 = network_interfaces[0]
    if isinstance(ni0, dict):
        return ni0.get("nat_ip_address")
    return getattr(ni0, "nat_ip_address", None)


public_ip = vm.network_interfaces.apply(_nat_ip)
internal_ip = vm.network_interfaces.apply(
    lambda nis: nis[0].get("ip_address") if isinstance(nis[0], dict) else getattr(nis[0], "ip_address", None)
)

pulumi.export("public_ip", public_ip)
pulumi.export("internal_ip", internal_ip)
pulumi.export("ssh_command", public_ip.apply(lambda ip: f"ssh -i ~/.ssh/lab04_ed25519 {ssh_user}@{ip}"))
pulumi.export("http_url", public_ip.apply(lambda ip: f"http://{ip}/"))
pulumi.export("app_url", public_ip.apply(lambda ip: f"http://{ip}:5000/"))
