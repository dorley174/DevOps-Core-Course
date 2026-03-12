# Local Validation Guide (Windows + WSL2 + Vagrant + VirtualBox)

This guide is designed for a **fully local and free** Lab06 workflow on **Windows**.
It assumes:

- Windows 10/11
- VirtualBox
- Vagrant
- WSL2 with Ubuntu
- GitHub repository (optional, only for CI/CD)

---

## 1. Recommended Setup

### Windows side

Install and verify:

```powershell
vagrant --version
VBoxManage --version
git --version
```

Recommended Vagrant plugins check:

```powershell
vagrant plugin list
```

### WSL2 Ubuntu side

Install and verify:

```bash
wsl --status
python3 --version
pip3 --version
ssh -V
git --version
```

Install Ansible in WSL2 if missing:

```bash
python3 -m pip install --user --upgrade pip
python3 -m pip install --user ansible ansible-lint
printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> ~/.bashrc
source ~/.bashrc
ansible --version
ansible-lint --version
```

---

## 2. Start the VM

Run in **PowerShell** from the repository root:

```powershell
vagrant up
vagrant status
vagrant port
```

Expected important forwarded ports:

- guest SSH `22` -> host `2222`
- guest app `8000` -> host `8000`

If ports changed because of `auto_correct`, update the inventory accordingly.

---

## 3. Prepare the SSH key for Ansible

The Vagrant private key is usually stored under the project directory on Windows.
Copy it into WSL and fix permissions.

Example from WSL:

```bash
mkdir -p ~/.ssh
cp /mnt/c/path/to/your/repo/.vagrant/machines/default/virtualbox/private_key ~/.ssh/lab05_vagrant_key
chmod 600 ~/.ssh/lab05_vagrant_key
```

Check SSH connectivity:

```bash
ssh -i ~/.ssh/lab05_vagrant_key -p 2222 vagrant@127.0.0.1
```

If `127.0.0.1` does not work from WSL2, detect the Windows host IP and try again:

```bash
WIN_HOST_IP=$(grep -m1 nameserver /etc/resolv.conf | awk '{print $2}')
echo "$WIN_HOST_IP"
ssh -i ~/.ssh/lab05_vagrant_key -p 2222 vagrant@"$WIN_HOST_IP"
```

---

## 4. Inventory Settings

Default local-friendly inventory example:

```ini
[webservers]
vagrant1 ansible_host=127.0.0.1 ansible_port=2222 ansible_user=vagrant ansible_ssh_private_key_file=~/.ssh/lab05_vagrant_key

[webservers:vars]
ansible_python_interpreter=/usr/bin/python3
```

If WSL2 cannot reach `127.0.0.1:2222`, replace `ansible_host` with the detected Windows host IP.

---

## 5. Install Ansible collections

Run in WSL2 from the repository root:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

Verify installed collections:

```bash
ansible-galaxy collection list | grep -E 'community.docker|community.general|ansible.posix'
```

---

## 6. Basic validation commands

### Connectivity

```bash
cd ansible
ansible all -m ping
```

### Syntax and task listing

```bash
ansible-playbook playbooks/provision.yml --syntax-check
ansible-playbook playbooks/deploy.yml --syntax-check
ansible-playbook playbooks/provision.yml --list-tags
ansible-playbook playbooks/deploy.yml --list-tasks
ansible-playbook playbooks/deploy.yml --list-tasks --tags web_app
```

### Lint

```bash
ansible-lint -p .
```

---

## 7. Provisioning validation

```bash
cd ansible
ansible-playbook playbooks/provision.yml
ansible-playbook playbooks/provision.yml
```

The second run should be mostly idempotent.

Selective tag checks:

```bash
ansible-playbook playbooks/provision.yml --tags docker
ansible-playbook playbooks/provision.yml --tags docker_install
ansible-playbook playbooks/provision.yml --tags packages
ansible-playbook playbooks/provision.yml --skip-tags common
```

---

## 8. Deployment validation

```bash
cd ansible
ansible-playbook playbooks/deploy.yml
ansible-playbook playbooks/deploy.yml
```

Verify on the target VM:

```bash
ssh -i ~/.ssh/lab05_vagrant_key -p 2222 vagrant@127.0.0.1
sudo docker ps
sudo docker compose -f /opt/devops-info-service/docker-compose.yml ps
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/
```

From WSL2 / host side:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/
```

If WSL2 cannot reach Windows localhost, replace `127.0.0.1` with the Windows host IP.

---

## 9. Wipe logic validation

### Wipe only

```bash
cd ansible
ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true" --tags web_app_wipe
```

### Clean reinstall

```bash
ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true"
```

### Safety check

```bash
ansible-playbook playbooks/deploy.yml --tags web_app_wipe
```

Expected result: wipe tasks are selected by tag but skipped by the boolean guard.

---

## 10. GitHub Actions self-hosted runner (free local option)

Recommended approach:

- Create the self-hosted runner in **WSL2 Ubuntu**, not in native Windows.
- Use labels that include `self-hosted` and `linux`.
- Run the runner only when you want to test CI locally.

Why this is preferred:

- the workflow uses Bash and Linux paths
- Ansible support is simpler on Linux
- no cloud VM is required
- no paid service is required

Useful checks on the runner machine:

```bash
python3 --version
ansible --version
ansible-galaxy collection list | grep -E 'community.docker|community.general|ansible.posix'
curl --version
```

Suggested repository secrets:

- `ANSIBLE_VAULT_PASSWORD` (only if you really use Vault)
- `VM_HOST` with value `127.0.0.1` or the Windows host IP

---

## 11. What to capture for submission

Recommended evidence:

1. `ansible-playbook playbooks/provision.yml --list-tags`
2. `ansible-playbook playbooks/provision.yml --tags docker_install`
3. First and second `ansible-playbook playbooks/deploy.yml` runs
4. Wipe-only run
5. Clean reinstall run
6. `docker compose ps` output on the VM
7. `curl /health` and `curl /` output
8. GitHub Actions `lint` and `deploy` job logs
