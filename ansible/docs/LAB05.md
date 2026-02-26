# LAB05 — Ansible Fundamentals (Report)

## 1. Architecture Overview

### Control node
- OS: Windows 11 + WSL (Ubuntu)
- Ansible version:

```bash
ansible --version
```

```text
TODO: paste output
```

### Target node
- Provisioned via: **Vagrant + VirtualBox** (Option B)
- OS:

```bash
ansible webservers -a "lsb_release -a"
```

```text
TODO: paste output
```

### Why roles instead of a single playbook?
Roles provide a clean, reusable structure:
- modular responsibilities (base OS, Docker, app deploy)
- simpler playbooks (just list roles)
- easier maintenance and testing

---

## 2. Project Structure

```text
ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── group_vars/
│   └── all.yml            # encrypted (Ansible Vault)
├── playbooks/
│   ├── provision.yml
│   ├── deploy.yml
│   └── site.yml
└── roles/
    ├── common/
    ├── docker/
    └── app_deploy/
```

---

## 3. Roles Documentation

### Role: `common`
**Purpose**
- Base OS provisioning: apt cache update + essential packages.
- Optional timezone configuration.

**Key tasks**
- `apt update_cache`
- install `common_packages`
- set timezone (optional)

**Variables (defaults)**
- `common_packages` (list)
- `common_timezone` (string)
- `common_set_timezone` (bool)

**Handlers**
- none

**Dependencies**
- `community.general` (timezone module)

---

### Role: `docker`
**Purpose**
- Install Docker Engine from the official Docker APT repository.
- Enable and start the Docker service.
- Add SSH user to the `docker` group.

**Key tasks**
- Install prerequisites (`ca-certificates`, `curl`, `gnupg`)
- Add Docker GPG key and APT repo
- Install Docker packages
- Ensure `docker` service is running + enabled
- Add user to `docker` group
- Install `python3-docker` (required for Ansible Docker modules)

**Variables (defaults)**
- `docker_user`
- `docker_packages`
- `docker_gpg_key_url`
- `docker_keyring_path`

**Handlers**
- `restart docker`

**Dependencies**
- none (uses built-in modules)

---

### Role: `app_deploy`
**Purpose**
- Log in to the container registry.
- Pull the application image.
- Run the container with a stable name, port mapping and restart policy.
- Wait for readiness and verify `/health`.

**Key tasks**
- `docker_login`
- `docker_image` pull
- `docker_container` start
- `wait_for` + HTTP checks

**Variables (defaults)**
- `app_name`
- `app_container_name`
- `app_port` / `container_port`
- `app_restart_policy`
- `app_env`
- `docker_registry` (optional)

**Vault variables (encrypted in `group_vars/all.yml`)**
- `dockerhub_username`
- `dockerhub_password` (prefer access token)
- `docker_image`
- `docker_image_tag`

**Handlers**
- `restart app container`

**Dependencies**
- `community.docker`

---

## 4. Idempotency Demonstration

### 4.1 First run

```bash
ansible-playbook playbooks/provision.yml
```

```text
TODO: paste output (or at least PLAY RECAP)
```

### 4.2 Second run

```bash
ansible-playbook playbooks/provision.yml
```

```text
TODO: paste output (or at least PLAY RECAP)
```

### 4.3 Analysis
On the first run, tasks typically show `changed` because packages/repositories/services are being installed/configured.
On the second run, Ansible should converge to `ok` for most tasks, proving idempotency (desired state already reached).

---

## 5. Ansible Vault

### 5.1 Secret storage
Docker registry credentials are stored in `ansible/group_vars/all.yml` encrypted with Ansible Vault.

### 5.2 Proof of encryption

```bash
head -n 5 ansible/group_vars/all.yml
```

```text
TODO: paste output (should start with $ANSIBLE_VAULT;...)
```

### 5.3 Vault password strategy
- Option A: `--ask-vault-pass`
- Option B: `.vault_pass` (chmod 600) and add it to `.gitignore`

---

## 6. Deployment Verification

### 6.1 Deploy run

```bash
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```

```text
TODO: paste output (or at least PLAY RECAP)
```

### 6.2 Container status

```bash
ansible webservers -a "docker ps"
```

```text
TODO: paste output
```

### 6.3 Health check

From the target VM (via Ansible):

```bash
ansible webservers -a "curl -i http://127.0.0.1:5000/health"
```

From the control node (WSL) through port forwarding (Vagrant):

```bash
WIN_HOST_IP=$(grep -m1 nameserver /etc/resolv.conf | awk '{print $2}')
curl -i "http://$WIN_HOST_IP:5000/health"
curl -i "http://$WIN_HOST_IP:5000/"
```

```text
TODO: paste output
```

---

## 7. Key Decisions (Short Answers)

1. **Why use roles instead of plain playbooks?**
   Roles keep automation modular and reusable, making playbooks shorter and easier to maintain.

2. **How do roles improve reusability?**
   The same role can be applied to different hosts/projects by changing variables, without copying task code.

3. **What makes a task idempotent?**
   Using stateful modules (`apt`, `service`, `user`, `docker_container`) that only change the system when its current state differs from the desired one.

4. **How do handlers improve efficiency?**
   Handlers run only when notified by a task that actually changed something, avoiding unnecessary service restarts.

5. **Why is Ansible Vault needed?**
   It allows storing secrets in version control safely by encrypting them, while still enabling automation to use them.

---

## 8. Challenges (Optional)

- TODO: add short bullet points if you had any issues and how you solved them.
