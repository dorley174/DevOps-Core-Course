# Lab05 — Ansible

Check `labs/lab05.md` (task) ans `ansible/docs/LAB05.md` (report).

Быстрые команды:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook playbooks/provision.yml
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```
