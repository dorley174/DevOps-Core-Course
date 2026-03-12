# LAB05 — Ansible Fundamentals (report)

> LAB05 - DevOps

## 1. Architecture Overview

- **Ansible version**: 
  - Command: `ansible --version`
  - Вывод:

```text
ansible [core 2.20.3]
  config file = None
  configured module search path = ['/home/dorley/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /home/dorley/.local/share/pipx/venvs/ansible-core/lib/python3.12/site-packages/ansible
  ansible collection location = /home/dorley/.ansible/collections:/usr/share/ansible/collections
  executable location = /home/dorley/.local/bin/ansible
  python version = 3.12.3 (main, Jan 22 2026, 20:57:42) [GCC 13.3.0] (/home/dorley/.local/share/pipx/venvs/ansible-core/bin/python)
  jinja version = 3.1.6
  pyyaml version = 6.0.3 (with libyaml v0.2.5)
```

- **Target VM**:
  - OS (command `lsb_release -a`):

```text
PASTE_HERE
```

- **Roles vs monolyte playbook**
  - Roles give reusing, clean arch,, readability and ability to test or move automatization parts between projects

## 2. Roles Documentation

### role: common
- **Purpose:** base ОС setup (update apt cache, utilits).
- **Variables (defaults):** `common_packages`, `common_timezone`.
- **Handlers:** - no.
- **Dependencies:** -no  (timezone setups using `timedatectl` and starts with `common_set_timezone`).

### role: docker
- **Purpose:** setup Docker Engine from repo + service setup.
- **Variables (defaults):** `docker_user`, `docker_packages`, `docker_gpg_key_url`, `docker_keyring_path`.
- **Handlers:** `restart docker`.
- **Dependencies:** no.

### role: app_deploy
- **Purpose:** login in reestr, pull of image, container start, health-check.
- **Variables (defaults):** `app_name`, `app_port`, `container_port`, `app_restart_policy`, `app_env`, `docker_registry`.
- **Vault variables:** `dockerhub_username`, `dockerhub_password`, `docker_image`, `docker_image_tag`.
- **Handlers:** `restart app container`.
- **Dependencies:** `community.docker`.

## 3. Idempotency Demonstration

### 3.1 First start of provision.yml
Command:

```bash
ansible-playbook playbooks/provision.yml
```

Output:

```text
PASTE_PROVISION_RUN_1
```

### 3.2 Secondary start of provision.yml
Command:

```bash
ansible-playbook playbooks/provision.yml
```

Output:

```text
PASTE_PROVISION_RUN_2
```

### 3.3 Analize
- While pulling at first time, i changed the system (packet setup, repo adding) → `changed`.
- WWhile pulling at 2nd time, wishing state has been reached -> almost all `ok` without any chhanges

## 4. Ansible Vault Usage

### 4.1 How to store secrets
- Secrets (Docker Hub username + access token) stores at `ansible/group_vars/all.yml`, encrypted by Ansible Vault.

### 4.2 Proof of encryption
just use `head -n 5 ansible/group_vars/all.yml`:

```text
PASTE_VAULT_HEADER
```

### 4.3 Password Storage Strategy Vault
- Option A: enter the password via `--ask-vault-pass`.
- Option B: `.vault_pass` (rights 600) + add to `.gitignore`.

## 5. Deployment Verification

### 5.1 Start deploy.yml
Command:

```bash
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```

Output:

```text
PASTE_DEPLOY_OUTPUT
```

### 5.2 Container check
Command:

```bash
ansible webservers -a "docker ps"
```

Output:

```text
PASTE_DOCKER_PS
```

### 5.3 Check health endpoint
Command:

```bash
curl http://<VM-IP-or-localhost>:5000/health
curl http://<VM-IP-or-localhost>:5000/
```

Output:

```text
PASTE_CURL_OUTPUT
```

## 6. Key Decisions

- **Почему roles вместо plain playbooks?**
  - Чтобы логика была модульной: роли можно переиспользовать, проще сопровождать, структура предсказуема.

- **Как роли улучшают переиспользуемость?**
  - Роль можно подключить к любому playbook’у и переиспользовать в других проектах, меняя только переменные.

- **Что делает задачу идемпотентной?**
  - Использование stateful-модулей (apt/service/user/docker_container), которые меняют состояние только если оно отличается от желаемого.

- **Как handlers повышают эффективность?**
  - Handler запускается только если его notified задача реально изменила что-то (например, установки/конфиг), уменьшая лишние рестарты.

- **Зачем нужен Ansible Vault?**
  - Чтобы секреты не хранились в открытом виде в репозитории, но могли использоваться в автоматизации.

## 7. Challenges (optional)
- probably have not. the hardest challenge is to understand lab4 and lab5 work principle: why we need a lot of utilities, vm's, clouds an so on. it is harder than just setup ansible folder using stack.overflow guides from advices of some guys who recommended some features. =\
