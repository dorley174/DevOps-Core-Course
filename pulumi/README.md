# Lab04 — Pulumi (Yandex Cloud, Python)

## Before

1) Download Pulumi.
2) Download Python 3.10+.
3) Download project requirements:

```bash
python -m venv venv
# Windows:
#   .\venv\Scripts\activate
# macOS/Linux:
#   source venv/bin/activate
pip install -r requirements.txt
```

## Auth using Yandex Cloud

Pulumi provider Yandex uses same env/confic as Terrarform
Simplier
 
- add env variables `YC_TOKEN`, `YC_CLOUD_ID`, `YC_FOLDER_ID`, `YC_ZONE`

or (using pulumi config):

```bash
pulumi config set yandex:cloudId <cloud_id>
pulumi config set yandex:folderId <folder_id>
pulumi config set yandex:zone ru-central1-a
pulumi config set --secret yandex:token <token>
```

## Project settings (my vaaariables)

```bash
pulumi config set zone ru-central1-a
pulumi config set subnetCidr 10.10.0.0/24
pulumi config set allowedSshCidr "<ваш_IP>/32"

pulumi config set sshUser ubuntu
pulumi config set sshPublicKeyPath "~/.ssh/lab04_ed25519.pub"
# либо:
# pulumi config set sshPublicKey "ssh-ed25519 AAAA... lab04"

pulumi config set imageFamily ubuntu-2404-lts
```

## Start

```bash
pulumi preview
pulumi up
```

After `pulumi up` in output will be `public_ip` and `ssh_command`.

## Delete resourses

```bash
pulumi destroy
```
