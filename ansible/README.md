# Lab05 — Ansible

Check `labs/lab05.md` (task) ans `ansible/docs/LAB05.md` (report).

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

# Deploy the application (uses Ansible Vault)
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```
