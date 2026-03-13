# Lab05/Lab06 — Ansible

See:
- `labs/lab05.md` — assignment
- `ansible/docs/LAB05.md` — report template
- `labs/lab06.md` — assignment
- `ansible/docs/LAB06.md` — report
- `ansible/docs/LOCAL_VALIDATION_WINDOWS.md` — Windows + WSL2 local validation guide

## Workflow badge

After creating your GitHub repository, replace `OWNER/REPO` in the snippet below:

```md
[![Ansible Deployment](https://github.com/OWNER/REPO/actions/workflows/ansible-deploy.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/ansible-deploy.yml)
```

## Quick start

```bash
cd ansible

# Install required collections
ansible-galaxy collection install -r requirements.yml

# Connectivity test
ansible all -m ping

# Provision the target VM (run twice to prove idempotency)
ansible-playbook playbooks/provision.yml
ansible-playbook playbooks/provision.yml

# Deploy the application with Docker Compose
ansible-playbook playbooks/deploy.yml

# Useful tag examples (Lab06)
ansible-playbook playbooks/provision.yml --list-tags
ansible-playbook playbooks/provision.yml --tags "docker_install"
ansible-playbook playbooks/provision.yml --skip-tags "common"
ansible-playbook playbooks/deploy.yml --tags "web_app"

# Wipe only (double-gated: variable + tag)
ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true" --tags web_app_wipe
```

## CI/CD (GitHub Actions)

Workflow file: `.github/workflows/ansible-deploy.yml`.

For Vagrant/VirtualBox setups behind NAT, prefer a **self-hosted Linux runner** on the same machine
where you run Ansible (for example, WSL2 Ubuntu). This avoids inbound SSH exposure and stays free.

## Lab07 monitoring stack

```bash
# Deploy Loki + Promtail + Grafana + app stack on the target VM
ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
```

The monitoring role builds the Python app locally on the target VM, so you do not need to push a new
application image to Docker Hub for Lab07.
