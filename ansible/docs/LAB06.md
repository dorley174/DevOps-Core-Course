# LAB06 — Advanced Ansible & CI/CD

## Overview

This lab upgrades the Lab05 Ansible project to a more production-ready setup:

- Refactored roles to use **blocks**, **rescue/always**, and a clear **tag strategy**.
- Migrated the application deployment from `docker run` to **Docker Compose v2**.
- Added **role dependency** (`web_app` depends on `docker`) to guarantee execution order.
- Implemented **safe wipe logic** (double-gated: variable + tag).
- Added a **GitHub Actions** workflow for Ansible linting + deployment.

Tech used: **Ansible 2.16+**, **community.docker**, **Docker Compose v2**, **GitHub Actions**, **Jinja2**.

---

## Blocks & Tags

### Tag strategy

- `common` — the whole common role (set at playbook role level)
- `packages` — package management tasks inside `common`
- `users` — user management tasks inside `common`

- `docker` — the whole docker role (set at playbook role level)
- `docker_install` — Docker installation + repo setup
- `docker_config` — Docker group/user configuration

- `web_app` — the whole deployment role (set at playbook role level)
- `app_deploy` — deployment block inside `web_app`
- `compose` — Docker Compose related tasks in `web_app`
- `web_app_wipe` — wipe logic tasks

### `common` role

File: `roles/common/tasks/main.yml`

What was done:

1. **Packages block** tagged `packages`.
2. **Users block** tagged `users`.
3. Added **rescue** for APT cache update failures:
   - best-effort `apt-get update --fix-missing`
   - retry cache update.
4. Added an outer **always** section that writes `/tmp/ansible_common_role_completed.log`.

Notes:

- User management is **optional** and controlled by `common_users` (default empty list => no changes).
- SSH keys are managed with `ansible.posix.authorized_key` for better collection portability.

### `docker` role

File: `roles/docker/tasks/main.yml`

What was done:

1. **Install block** tagged `docker_install`.
2. **Config block** tagged `docker_config`.
3. Added **rescue** to handle transient Docker repository / GPG failures:
   - wait 10 seconds
   - retry `apt update`
   - re-download and re-install the GPG key
   - retry install.
4. Added an outer **always** section to ensure the Docker service is enabled and started.

### How to test tags

```bash
cd ansible

# List all tags
ansible-playbook playbooks/provision.yml --list-tags

# Run only docker role tasks
ansible-playbook playbooks/provision.yml --tags docker

# Run only docker installation tasks
ansible-playbook playbooks/provision.yml --tags docker_install

# Install packages only
ansible-playbook playbooks/provision.yml --tags packages

# Skip common role
ansible-playbook playbooks/provision.yml --skip-tags common
```

---

## Docker Compose Migration

### Role rename

The deployment role was renamed from `app_deploy` to `web_app`.
The old `roles/app_deploy/` directory was removed from the final submission.

### Compose template

File: `roles/web_app/templates/docker-compose.yml.j2`

Template supports:

- `app_name`
- `docker_image`
- `docker_tag`
- `app_port` / `app_internal_port`
- `app_env` (dict of extra env vars)
- optional `app_secret_key` (Vault-friendly)

It also sets sane defaults for the provided Flask app:

- `HOST=0.0.0.0`
- `PORT={{ app_internal_port }}`

### Role dependency

File: `roles/web_app/meta/main.yml`

`web_app` depends on `docker`, so a playbook that runs the whole `web_app` role will install Docker first.

Important practical note:

- `ansible-playbook playbooks/deploy.yml` is the safest default.
- `ansible-playbook playbooks/deploy.yml --tags web_app` also works for selective role execution.
- `ansible-playbook playbooks/deploy.yml --tags app_deploy` targets only the deployment block and is **not** the best choice if you expect role dependencies to be selected by tag filtering.

### Deployment implementation

File: `roles/web_app/tasks/main.yml`

Deployment flow:

1. Create `/opt/{{ app_name }}`.
2. Render `docker-compose.yml`.
3. Optional `docker login` (only if password is provided).
4. Pull the image using `community.docker.docker_image`.
5. Run `community.docker.docker_compose_v2` (`state: present`).
6. Verify app responds on `/health` and `/`.

Idempotency test:

```bash
ansible-playbook playbooks/deploy.yml
ansible-playbook playbooks/deploy.yml
```

The second run should show mostly `ok` tasks, and no container recreation unless inputs changed.

---

## Wipe Logic

Files:

- `roles/web_app/defaults/main.yml`
- `roles/web_app/tasks/wipe.yml`
- `roles/web_app/tasks/main.yml` (includes wipe first)

### Why variable + tag?

This is a **double safety mechanism**:

- Variable (`web_app_wipe=true`) prevents accidental wipe during normal runs.
- Tag (`--tags web_app_wipe`) enables a wipe-only run that does not deploy.

### Test scenarios

```bash
# 1) Normal deployment (wipe does NOT run)
ansible-playbook playbooks/deploy.yml

# 2) Wipe only
ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true" --tags web_app_wipe

# 3) Clean reinstall (wipe -> deploy)
ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true"

# 4a) Safety check: tag without variable => wipe skipped
ansible-playbook playbooks/deploy.yml --tags web_app_wipe
```

---

## CI/CD Integration

File: `.github/workflows/ansible-deploy.yml`

### Workflow architecture

Two-stage pipeline:

1. **lint** (GitHub-hosted runner)
   - installs Ansible + ansible-lint
   - installs collections from `ansible/requirements.yml`
   - runs `ansible-lint -p .` inside the `ansible/` directory.

2. **deploy** (self-hosted Linux runner)
   - runs on `runs-on: [self-hosted, linux]`
   - installs Ansible on the runner
   - installs collections from `ansible/requirements.yml`
   - runs `ansible-playbook playbooks/deploy.yml`
   - verifies the app with `curl /health` and `curl /`.

### Why a Linux self-hosted runner?

For a local Vagrant/VirtualBox environment behind NAT, a **Linux self-hosted runner** on the same machine is the simplest free option.
Using WSL2 Ubuntu is practical because:

- the workflow already uses Bash and Linux paths
- Ansible is easier to maintain on Linux
- no public inbound SSH exposure is required
- it matches the local, free, Windows-friendly lab setup

### Secrets

Recommended secrets (Actions → Secrets):

- `ANSIBLE_VAULT_PASSWORD` — only needed if you use Vault-encrypted files
- `VM_HOST` — host/IP used by the verification curl step (default fallback: `127.0.0.1`)

If you later move to a public VM and a GitHub-hosted deploy job, add:

- `SSH_PRIVATE_KEY`
- `VM_USER`

---

## Testing Results Checklist

Collect evidence for submission:

- `ansible-playbook playbooks/provision.yml --list-tags`
- `ansible-playbook playbooks/provision.yml --tags docker_install`
- `ansible-playbook playbooks/deploy.yml`
- second deployment run for idempotency proof
- wipe-only run:
  - `ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true" --tags web_app_wipe`
- clean reinstall run:
  - `ansible-playbook playbooks/deploy.yml -e "web_app_wipe=true"`
- rendered file:
  - `/opt/{{ app_name }}/docker-compose.yml`
- app responses:
  - `curl http://<HOST>:{{ app_port }}/health`
  - `curl http://<HOST>:{{ app_port }}/`
- GitHub Actions logs for `lint` and `deploy`

---

## Challenges & Solutions

- **Compose v2 on Ubuntu**: the docker role installs `docker-compose-plugin` so `docker compose` is available.
- **Idempotency vs pull policy**: image pulling is done explicitly via `docker_image`, while Compose uses `pull: never`.
- **Safety for destructive operations**: wipe logic requires both a boolean variable and, for wipe-only mode, an explicit tag.
- **Collection portability**: `ansible.posix` was added explicitly so `authorized_key` does not depend on the full `ansible` meta-package.

---

## Research Answers

### Blocks & Tags

1. **What happens if the rescue block also fails?**
   - The whole block is considered failed and Ansible stops the play (unless errors are ignored).
   - The `always` section still runs.

2. **Can you have nested blocks?**
   - Yes. This lab uses an outer block with an `always` section, and inner blocks for `packages` / `users`.

3. **How do tags inherit to tasks within blocks?**
   - Tags defined at a block level are applied to all tasks in that block.
   - Tags defined at role level (in playbooks) also apply to all tasks in the role.

### Docker Compose

1. **Difference between `restart: always` and `restart: unless-stopped`?**
   - `always` restarts containers even if you manually stopped them.
   - `unless-stopped` restarts containers automatically except when they were explicitly stopped by an operator.

2. **How do Compose networks differ from Docker bridge networks?**
   - Compose creates and manages networks as part of an application project, with predictable naming.
   - A classic Docker bridge network is a lower-level primitive not tied to a Compose project.

3. **Can you reference Ansible Vault variables in the template?**
   - Yes. Vault-encrypted variables are decrypted at runtime and can be used like normal variables in templates.

### Wipe logic

1. **Why use both variable AND tag?**
   - The variable protects normal runs.
   - The tag enables a wipe-only execution that skips deployment tasks.

2. **Difference between `never` tag and this approach?**
   - `never` requires explicit `--tags never` (or another selected tag on the same task) and can be confusing.
   - Variable + tag is explicit and easier to reason about for safety-critical operations.

3. **Why must wipe logic come BEFORE deployment?**
   - It enables the clean reinstall flow: remove old state first, then deploy from scratch.

4. **When do you want clean reinstall vs rolling update?**
   - Clean reinstall: broken state, changed config/layout, major upgrades, testing fresh installs.
   - Rolling update: keep service available, minimize downtime, gradual rollout.

5. **How to extend wipe to remove images/volumes too?**
   - Add Compose options such as `remove_volumes: true` when needed.
   - Remove images via `community.docker.docker_image state: absent`.
   - Remove named volumes explicitly with Docker modules or CLI commands.

### CI/CD

1. **Security implications of storing SSH keys in GitHub Secrets?**
   - Secrets can be exfiltrated if workflows are compromised.
   - Limit key scope, use dedicated deploy keys, restrict repo access, and rotate regularly.

2. **How to implement staging → production pipeline?**
   - Use separate environments, separate inventories, and manual approvals for production.
   - Another option is separate workflows triggered on tags/releases.

3. **What to add for rollbacks?**
   - Pin image tags, keep the previous known-good tag, and add a rollback job that redeploys it.

4. **How does a self-hosted runner improve security compared to GitHub-hosted?**
   - SSH keys/secrets do not need to be sent to GitHub-hosted machines.
   - The runner stays inside your controlled network perimeter.
