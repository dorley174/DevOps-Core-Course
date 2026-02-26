# LAB05 — Ansible Fundamentals (Report)

## 1. Architecture Overview

### Control node
- OS: Windows 11 + WSL (Ubuntu)
- Ansible is executed inside WSL
- Ansible version:

```bash
ansible --version
```

```text
ansible [core 2.20.3]
  config file = /home/dorley/projects/DevOps-Core-Course/ansible/ansible.cfg
  configured module search path = ['/home/dorley/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /home/dorley/.local/share/pipx/venvs/ansible-core/lib/python3.12/site-packages/ansible
  ansible collection location = /home/dorley/.ansible/collections:/usr/share/ansible/collections
  executable location = /home/dorley/.local/bin/ansible
  python version = 3.12.3 (main, Jan 22 2026, 20:57:42) [GCC 13.3.0] (/home/dorley/.local/share/pipx/venvs/ansible-core/bin/python)
  jinja version = 3.1.6
  pyyaml version = 6.0.3 (with libyaml v0.2.5)
```

### Target node
- Provisioned via: **Vagrant + VirtualBox**
- SSH access: forwarded port (guest 22 -> host 2222)
- OS (queried via Ansible):

```bash
ansible -i inventory/hosts.ini webservers -a "lsb_release -a"
```

```text
vagrant1 | CHANGED | rc=0 >>
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.5 LTS
Release:        22.04
Codename:       jammyNo LSB modules are available.
```

### Networking note (WSL + Windows)
From WSL, SSH access to the VM uses the **Windows host LAN IP** (not 127.0.0.1).

Example values used in this lab:
- Windows host IP: `192.168.31.32`
- SSH forwarded port: `2222`
- App forwarded port: `5000`

> If your Windows host IP differs, replace `192.168.31.32` accordingly.

---

## 2. Project Structure (Ansible)

```text
ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── group_vars/
│   └── webservers.yml      # non-secret variables (public image)
├── playbooks/
│   ├── provision.yml
│   └── deploy.yml
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
- Update apt cache
- Install common packages
- Set timezone (optional)

**Variables**
- `common_packages` (list)
- `common_timezone` (string)
- `common_set_timezone` (bool)

---

### Role: `docker`
**Purpose**
- Install Docker Engine from the official Docker APT repository.
- Enable and start Docker.
- Add SSH user to the `docker` group.
- Install `python3-docker` for Ansible Docker modules.

**Key tasks**
- Add Docker GPG key + repo
- Install Docker packages
- Ensure `docker` service is enabled and running
- Add user to docker group
- Install Docker SDK for Python (`python3-docker`)

**Variables**
- `docker_user`
- `docker_packages`

---

### Role: `app_deploy`
**Purpose**
- Pull the application image.
- Run the container with a stable name, port mapping and restart policy.
- Wait for readiness and verify `/health` and `/`.

**Key tasks**
- Optional `docker_login` (executed only if password is provided)
- `docker_image` pull
- `docker_container` start
- `wait_for` + HTTP checks

**Variables**
- `dockerhub_username`
- `dockerhub_password` (empty for public image)
- `docker_image`
- `docker_image_tag`
- `app_name`
- `app_container_name`
- `app_port` / `container_port`
- `app_restart_policy`
- `app_env`

---

## 4. Idempotency Demonstration (Provisioning)

### 4.1 First run

```bash
ansible-playbook -i inventory/hosts.ini playbooks/provision.yml
```

```text

PLAY [Provision web servers] *************************************************************************************************************************

TASK [Gathering Facts] *******************************************************************************************************************************
ok: [vagrant1]

TASK [common : Update apt cache] *********************************************************************************************************************
ok: [vagrant1]

TASK [common : Install common packages] **************************************************************************************************************
ok: [vagrant1]

TASK [common : Set timezone] *************************************************************************************************************************
skipping: [vagrant1]

TASK [docker : Install prerequisites for Docker repository] ******************************************************************************************
ok: [vagrant1]

TASK [docker : Ensure /etc/apt/keyrings exists] ******************************************************************************************************
ok: [vagrant1]

TASK [docker : Download Docker GPG key (ASCII)] ******************************************************************************************************
ok: [vagrant1]

TASK [docker : Check if Docker keyring already exists] ***********************************************************************************************
ok: [vagrant1]

TASK [docker : Convert (dearmor) Docker GPG key to keyring] ******************************************************************************************
skipping: [vagrant1]

TASK [docker : Set correct permissions on Docker keyring] ********************************************************************************************
ok: [vagrant1]

TASK [docker : Set Docker APT architecture mapping] **************************************************************************************************
[WARNING]: Deprecation warnings can be disabled by setting `deprecation_warnings=False` in ansible.cfg.
[DEPRECATION WARNING]: INJECT_FACTS_AS_VARS default to `True` is deprecated, top-level facts will not be auto injected after the change. This feature will be removed from ansible-core version 2.24.
Origin: /home/dorley/projects/DevOps-Core-Course/ansible/roles/docker/tasks/main.yml:42:22

40 - name: Set Docker APT architecture mapping
41   ansible.builtin.set_fact:
42     docker_apt_arch: "{{ {'x86_64':'amd64','aarch64':'arm64'}.get(ansible_architecture, ansible_architecture) }}"
                        ^ column 22

Use `ansible_facts["fact_name"]` (no `ansible_` prefix) instead.

ok: [vagrant1]

TASK [docker : Add official Docker APT repository] ***************************************************************************************************
[DEPRECATION WARNING]: INJECT_FACTS_AS_VARS default to `True` is deprecated, top-level facts will not be auto injected after the change. This feature will be removed from ansible-core version 2.24.
Origin: /home/dorley/projects/DevOps-Core-Course/ansible/roles/docker/tasks/main.yml:46:11

44 - name: Add official Docker APT repository
45   ansible.builtin.apt_repository:
46     repo: "deb [arch={{ docker_apt_arch }} signed-by={{ docker_keyring_path }}] https://download.docker.com/linux/...
             ^ column 11

Use `ansible_facts["fact_name"]` (no `ansible_` prefix) instead.

ok: [vagrant1]

TASK [docker : Install Docker Engine packages] *******************************************************************************************************
ok: [vagrant1]

TASK [docker : Ensure Docker service is enabled and running] *****************************************************************************************
ok: [vagrant1]

TASK [docker : Ensure docker group exists] ***********************************************************************************************************
ok: [vagrant1]

TASK [docker : Add user to docker group] *************************************************************************************************************
ok: [vagrant1]

TASK [docker : Install Docker SDK for Python on target (for Ansible docker modules)] *****************************************************************
ok: [vagrant1]

PLAY RECAP *******************************************************************************************************************************************
vagrant1                   : ok=15   changed=0    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```

### 4.2 Second run

```bash
ansible-playbook -i inventory/hosts.ini playbooks/provision.yml
```

```text
PLAY [Provision web servers] *************************************************************************************************************************

TASK [Gathering Facts] *******************************************************************************************************************************
ok: [vagrant1]

TASK [common : Update apt cache] *********************************************************************************************************************
ok: [vagrant1]

TASK [common : Install common packages] **************************************************************************************************************
ok: [vagrant1]

TASK [common : Set timezone] *************************************************************************************************************************
skipping: [vagrant1]

TASK [docker : Install prerequisites for Docker repository] ******************************************************************************************
ok: [vagrant1]

TASK [docker : Ensure /etc/apt/keyrings exists] ******************************************************************************************************
ok: [vagrant1]

TASK [docker : Download Docker GPG key (ASCII)] ******************************************************************************************************
ok: [vagrant1]

TASK [docker : Check if Docker keyring already exists] ***********************************************************************************************
ok: [vagrant1]

TASK [docker : Convert (dearmor) Docker GPG key to keyring] ******************************************************************************************
skipping: [vagrant1]

TASK [docker : Set correct permissions on Docker keyring] ********************************************************************************************
ok: [vagrant1]

TASK [docker : Set Docker APT architecture mapping] **************************************************************************************************
[WARNING]: Deprecation warnings can be disabled by setting `deprecation_warnings=False` in ansible.cfg.
[DEPRECATION WARNING]: INJECT_FACTS_AS_VARS default to `True` is deprecated, top-level facts will not be auto injected after the change. This feature will be removed from ansible-core version 2.24.
Origin: /home/dorley/projects/DevOps-Core-Course/ansible/roles/docker/tasks/main.yml:42:22

40 - name: Set Docker APT architecture mapping
41   ansible.builtin.set_fact:
42     docker_apt_arch: "{{ {'x86_64':'amd64','aarch64':'arm64'}.get(ansible_architecture, ansible_architecture) }}"
                        ^ column 22

Use `ansible_facts["fact_name"]` (no `ansible_` prefix) instead.

ok: [vagrant1]

TASK [docker : Add official Docker APT repository] ***************************************************************************************************
[DEPRECATION WARNING]: INJECT_FACTS_AS_VARS default to `True` is deprecated, top-level facts will not be auto injected after the change. This feature will be removed from ansible-core version 2.24.
Origin: /home/dorley/projects/DevOps-Core-Course/ansible/roles/docker/tasks/main.yml:46:11

44 - name: Add official Docker APT repository
45   ansible.builtin.apt_repository:
46     repo: "deb [arch={{ docker_apt_arch }} signed-by={{ docker_keyring_path }}] https://download.docker.com/linux/...
             ^ column 11

Use `ansible_facts["fact_name"]` (no `ansible_` prefix) instead.

ok: [vagrant1]

TASK [docker : Install Docker Engine packages] *******************************************************************************************************
ok: [vagrant1]

TASK [docker : Ensure Docker service is enabled and running] *****************************************************************************************
ok: [vagrant1]

TASK [docker : Ensure docker group exists] ***********************************************************************************************************
ok: [vagrant1]

TASK [docker : Add user to docker group] *************************************************************************************************************
ok: [vagrant1]

TASK [docker : Install Docker SDK for Python on target (for Ansible docker modules)] *****************************************************************
ok: [vagrant1]

PLAY RECAP *******************************************************************************************************************************************
vagrant1                   : ok=15   changed=0    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```

### 4.3 Analysis
First run changes the system (packages, repositories, services). Second run converges to the desired state and should show `changed=0` (or close to it), proving idempotency.

---

## 5. Secrets / Vault

This lab uses a **public Docker Hub image**, therefore no registry password is required for `docker pull`.

Variables are stored in `group_vars/webservers.yml` and `dockerhub_password` is set to an empty string.

Optional: Ansible Vault can still be used for secrets (e.g., if using a private image), but is not required for this public-image setup.

---

## 6. Deployment Verification

### 6.1 Deploy run

```bash
ansible-playbook -i inventory/hosts.ini playbooks/deploy.yml
```

```text

PLAY [Deploy application] ****************************************************************************************************************************

TASK [Gathering Facts] *******************************************************************************************************************************
ok: [vagrant1]

TASK [app_deploy : Ensure Docker SDK for Python is installed on target] ******************************************************************************
ok: [vagrant1]

TASK [app_deploy : Login to Docker registry] *********************************************************************************************************
skipping: [vagrant1]

TASK [app_deploy : Pull application image] ***********************************************************************************************************
ok: [vagrant1]

TASK [app_deploy : Check current container (if exists)] **********************************************************************************************
ok: [vagrant1]

TASK [app_deploy : Decide if redeploy is needed] *****************************************************************************************************
ok: [vagrant1]

TASK [app_deploy : Stop existing container (only if redeploy needed)] ********************************************************************************
skipping: [vagrant1]

TASK [app_deploy : Remove existing container (only if redeploy needed)] ******************************************************************************
skipping: [vagrant1]

TASK [app_deploy : Run application container] ********************************************************************************************************
ok: [vagrant1]

TASK [app_deploy : Wait for the application port to become available] ********************************************************************************
ok: [vagrant1]

TASK [app_deploy : Health check (/health)] ***********************************************************************************************************
ok: [vagrant1]

TASK [app_deploy : Verify main endpoint (/)] *********************************************************************************************************
ok: [vagrant1]

PLAY RECAP *******************************************************************************************************************************************
vagrant1                   : ok=9    changed=0    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
```

### 6.2 Container status

```bash
ansible -i inventory/hosts.ini webservers -a "docker ps"
```

```text
vagrant1 | CHANGED | rc=0 >>
CONTAINER ID   IMAGE                                  COMMAND           CREATED          STATUS          PORTS                    NAMES
a0a73f77e763   dorley174/devops-info-service:latest   "python app.py"   35 minutes ago   Up 34 minutes   0.0.0.0:5000->5000/tcp   devops-info-service 
```

### 6.3 Health check

From the target VM (via Ansible):

```bash
ansible -i inventory/hosts.ini webservers -a "curl -i http://127.0.0.1:5000/health"
```

From the control node (WSL) via Windows host forwarding:

```bash
curl -i "http://192.168.31.32:5000/health"
curl -i "http://192.168.31.32:5000/"
```

```text
curl -i "http://192.168.31.32:5000/"
HTTP/1.1 200 OK
Server: Werkzeug/3.1.5 Python/3.13.1
Date: Thu, 26 Feb 2026 20:05:00 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 82
Connection: close

{"status":"healthy","timestamp":"2026-02-26T20:05:00.236Z","uptime_seconds":2111}
HTTP/1.1 200 OK
Server: Werkzeug/3.1.5 Python/3.13.1
Date: Thu, 26 Feb 2026 20:05:00 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 675
Connection: close

{"endpoints":[{"description":"Service information","method":"GET","path":"/"},{"description":"Health check","method":"GET","path":"/health"}],"request":{"client_ip":"192.168.31.32","method":"GET","path":"/","user_agent":"curl/8.5.0"},"runtime":{"current_time":"2026-02-26T20:05:00.254Z","timezone":"UTC","uptime_human":"0 hours, 35 minutes","uptime_seconds":2111},"service":{"description":"DevOps course info service","framework":"Flask","name":"devops-info-service","version":"1.0.0"},"system":{"architecture":"x86_64","cpu_count":2,"hostname":"a0a73f77e763","platform":"Linux","platform_version":"Linux-5.15.0-170-generic-x86_64-with-glibc2.36","python_version":"3.13.1"}}
```

---

## 7. Key Decisions (Short Answers)

1. **Why use roles instead of plain playbooks?**  
   Roles keep automation modular and reusable, making playbooks shorter and easier to maintain.

2. **How do roles improve reusability?**  
   The same role can be applied to different hosts/projects by changing variables without copying tasks.

3. **What makes a task idempotent?**  
   Stateful modules that only change the system if the current state differs from desired state.

4. **How do handlers improve efficiency?**  
   Handlers run only when notified, avoiding unnecessary restarts.

5. **Why would Ansible Vault be needed?**  
   To store sensitive credentials safely in version control when secrets are required.

---

## 8. Challenges (Optional)

- VirtualBox/Vagrant leftovers caused VM name conflicts; fixed by removing stale VMs from VirtualBox.
- WSL could not access `127.0.0.1:2222` forwarded port; fixed by using Windows LAN IP (e.g., `192.168.31.32`).
