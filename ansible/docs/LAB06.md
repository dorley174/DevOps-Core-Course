# Lab 06 — Ansible Roles Refactoring and Local Deployment Validation

## Summary

This lab was implemented and validated in a fully local and free environment on Windows 11 using VirtualBox, Vagrant, WSL2 Ubuntu, Ansible, and Docker.

The infrastructure provisioning flow works correctly, static validation passes, and the deployment playbook reaches the final Docker Compose stage. The remaining issue is a Docker Compose YAML rendering error in the generated `docker-compose.yml`, which prevents the application from being started successfully.

## Environment

- Host OS: Windows 11
- Virtualization: VirtualBox
- VM orchestration: Vagrant
- Automation runtime: WSL2 Ubuntu
- Configuration management: Ansible
- Container runtime: Docker Engine + Docker Compose plugin
- CI approach: prepared for self-hosted Linux runner
- Validation model: fully local, no paid cloud resources used

## Implemented Changes

### Task 1 — Refactor existing roles with `block`, `rescue`, and `always`
- Refactored `common` role to use structured error handling blocks.
- Refactored `docker` role to use structured error handling blocks.
- Added meaningful tags to role tasks.

### Task 2 — Create a deploy role based on Docker Compose
- Replaced the old deployment logic with a `web_app` role.
- Added Docker dependency through role metadata.
- Implemented application deployment using Docker Compose v2.
- Added optional wipe logic with dedicated tags and safety checks.

### Task 3 — Add selective wipe support
- Implemented wipe-only workflow using `web_app_wipe` tags.
- Added safety condition to prevent accidental destructive cleanup.

### Task 4 — Prepare local free execution model
- Configured the project to work against a Vagrant VM.
- Validated SSH access from WSL2 to the VM through forwarded port `2222`.
- Used Windows host IP from WSL2 (`172.19.144.1`) for Ansible connectivity.

### Task 5 — Documentation
- Added local validation instructions.
- Prepared reproducible local execution steps for Windows + WSL2.

## Validation Results

### Static Validation
The following checks completed successfully:

- `ansible all -i inventory/hosts.ini -m ping`
- `ansible-playbook -i inventory/hosts.ini playbooks/provision.yml --syntax-check`
- `ansible-playbook -i inventory/hosts.ini playbooks/deploy.yml --syntax-check`
- `ansible-lint --format=pep8 playbooks/*.yml roles`

### Provisioning Validation
`playbooks/provision.yml` completed successfully.

Validated outcomes:
- base packages installed
- Docker repository configured
- Docker Engine installed
- Docker service enabled and running
- target host reachable and manageable by Ansible

### Deployment Validation
`playbooks/deploy.yml` was executed successfully up to the application deployment stage.

Validated outcomes:
- Docker role dependency executed correctly
- application directory was created
- `docker-compose.yml` was rendered and copied to target host
- Docker image reference was resolved correctly
- image pull from Docker Hub succeeded after transient network timeout recovery

### Final Blocking Issue
The deployment currently stops at the Docker Compose execution stage with the following error:

`yaml: line 12, column 30: mapping values are not allowed in this context`

This indicates that the generated `docker-compose.yml` still contains a YAML formatting issue and requires one final template fix before the application can be started successfully.

## Issues Encountered During Validation

### 1. WSL2 to localhost forwarding
WSL2 could not reach the forwarded SSH port on `127.0.0.1:2222`.
This was resolved by using the Windows host IP visible from WSL2:

- `172.19.144.1:2222`

### 2. Ansible configuration ignored in writable directory
When the project was executed from a Windows-mounted path, Ansible ignored the local `ansible.cfg`.
This was resolved by copying the project to the native WSL filesystem and explicitly exporting:

`ANSIBLE_CONFIG=/home/dorley/work/ansible/ansible.cfg`

### 3. Missing deployment variable
Initial deployment failed because `dockerhub_username` was undefined.
This was resolved by defining the variable in inventory group variables.

### 4. Transient Docker Hub network timeout
One deployment attempt failed with a TLS handshake timeout when pulling the image from Docker Hub.
Manual pull confirmed that the image reference was correct and the issue was transient.

### 5. Final Docker Compose YAML error
The remaining unresolved issue is a YAML syntax problem in the generated Compose file.
This is the last known blocker preventing the application from starting.

## Conclusion

The lab is largely completed and validated:

- provisioning works
- role refactoring is implemented
- static checks pass
- deployment logic is mostly correct
- the local free execution model on Windows + WSL2 + Vagrant is valid

The only remaining issue is the final Docker Compose YAML rendering error in the generated application manifest. Once the template is corrected, the deployment should complete successfully.

