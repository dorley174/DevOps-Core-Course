# LAB05 — Ansible Fundamentals (отчёт)

> Этот файл — готовый шаблон. Выполните команды из инструкции и вставьте выводы в отмеченные места.

## 1. Architecture Overview

- **Ansible version**: 
  - Команда: `ansible --version`
  - Вывод:

```text
PASTE_HERE
```

- **Target VM**:
  - OS (команда `lsb_release -a`):

```text
PASTE_HERE
```

- **Роли (roles) vs монолитный playbook**
  - Роли дают переиспользуемость, чистую структуру, читаемость и возможность тестировать/переносить куски автоматизации между проектами.

## 2. Roles Documentation

### role: common
- **Purpose:** базовая подготовка ОС (обновление apt cache, утилиты, часовой пояс).
- **Variables (defaults):** `common_packages`, `common_timezone`.
- **Handlers:** нет.
- **Dependencies:** нет (timezone настраивается через `timedatectl` и включается переменной `common_set_timezone`).

### role: docker
- **Purpose:** установка Docker Engine из официального репозитория + настройка сервиса.
- **Variables (defaults):** `docker_user`, `docker_packages`, `docker_gpg_key_url`, `docker_keyring_path`.
- **Handlers:** `restart docker`.
- **Dependencies:** нет (используются builtin модули).

### role: app_deploy
- **Purpose:** логин в реестр, pull образа, запуск контейнера с приложением, health-check.
- **Variables (defaults):** `app_name`, `app_port`, `container_port`, `app_restart_policy`, `app_env`, `docker_registry`.
- **Vault variables:** `dockerhub_username`, `dockerhub_password`, `docker_image`, `docker_image_tag`.
- **Handlers:** `restart app container`.
- **Dependencies:** `community.docker`.

## 3. Idempotency Demonstration

### 3.1 Первый запуск provision.yml
Команда:

```bash
ansible-playbook playbooks/provision.yml
```

Вывод:

```text
PASTE_PROVISION_RUN_1
```

### 3.2 Второй запуск provision.yml
Команда:

```bash
ansible-playbook playbooks/provision.yml
```

Вывод:

```text
PASTE_PROVISION_RUN_2
```

### 3.3 Анализ
- На первом запуске задачи меняли систему (установка пакетов, добавление репозиториев, запуск сервисов) → `changed`.
- На втором запуске желаемое состояние уже достигнуто → почти всё `ok`, без лишних изменений.

## 4. Ansible Vault Usage

### 4.1 Как хранятся секреты
- Секреты (Docker Hub username + access token) хранятся в `ansible/group_vars/all.yml`, зашифрованном Ansible Vault.

### 4.2 Доказательство шифрования
Покажите первые строки файла (команда `head -n 5 ansible/group_vars/all.yml`):

```text
PASTE_VAULT_HEADER
```

### 4.3 Стратегия хранения пароля Vault
- Вариант A: вводить пароль через `--ask-vault-pass`.
- Вариант B: `.vault_pass` (права 600) + добавление в `.gitignore`.

## 5. Deployment Verification

### 5.1 Запуск deploy.yml
Команда:

```bash
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```

Вывод:

```text
PASTE_DEPLOY_OUTPUT
```

### 5.2 Проверка контейнера
Команда:

```bash
ansible webservers -a "docker ps"
```

Вывод:

```text
PASTE_DOCKER_PS
```

### 5.3 Проверка health endpoint
Команды:

```bash
curl http://<VM-IP-or-localhost>:5000/health
curl http://<VM-IP-or-localhost>:5000/
```

Вывод:

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
- PASTE_YOUR_NOTES
