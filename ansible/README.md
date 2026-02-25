# Lab05 — Ansible

См. `labs/lab05.md` (задание) и `ansible/docs/LAB05.md` (отчёт).

Быстрые команды:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook playbooks/provision.yml
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```
