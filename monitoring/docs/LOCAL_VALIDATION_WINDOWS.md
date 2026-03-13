# Lab07 Local Validation on Windows 11 (WSL2 + Vagrant-friendly)

This guide is tailored for the same environment used in earlier labs:
- Windows 11 host
- WSL2 Ubuntu for Linux commands
- VirtualBox + Vagrant for the free local VM option
- Russia / unstable access to Docker registries is possible, so retries are expected

## Option A — Run the stack directly from WSL (if you already have a Linux Docker engine)

1. Copy the example environment file:
   ```bash
   cd monitoring
   cp .env.example .env
   ```
2. Edit `.env` and set a real Grafana password.
3. Start the stack:
   ```bash
   docker compose up -d --build
   docker compose ps
   ```
4. Verify endpoints:
   ```bash
   curl http://127.0.0.1:3100/ready
   curl http://127.0.0.1:9080/targets
   curl http://127.0.0.1:8000/health
   ```
5. Open Grafana in a browser: `http://127.0.0.1:3000`
   - user: `admin`
   - password: value from `.env`

## Option B — 100% free path using the Vagrant VM and Ansible bonus automation

1. Reload Vagrant to apply the new forwarded ports:
   ```powershell
   vagrant reload
   vagrant status
   vagrant port
   ```
2. Make sure the VM is reachable from WSL. If forwarded ports do not work via `127.0.0.1` inside WSL, use the current Windows host IP from the `vEthernet (WSL...)` adapter.
3. From WSL, activate your Python environment and run:
   ```bash
   source ~/venvs/devops-lab/bin/activate
   export ANSIBLE_CONFIG=/home/<your-user>/work/ansible/ansible.cfg
   cd /path/to/repo/ansible
   ansible-galaxy collection install -r requirements.yml
   ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
   ```
4. From Windows open:
   - Grafana: `http://127.0.0.1:3000`
   - Loki ready endpoint: `http://127.0.0.1:3100/ready`
   - App health: `http://127.0.0.1:8000/health`
5. From WSL, if `127.0.0.1` forwarding does not work, use the current Windows host IP instead of localhost.

## Generate example traffic

### Bash / WSL
```bash
for i in {1..20}; do curl -s http://127.0.0.1:8000/ > /dev/null; done
for i in {1..20}; do curl -s http://127.0.0.1:8000/health > /dev/null; done
curl -s http://127.0.0.1:8000/does-not-exist > /dev/null
```

### PowerShell
```powershell
1..20 | ForEach-Object { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/ | Out-Null }
1..20 | ForEach-Object { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health | Out-Null }
try { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/does-not-exist | Out-Null } catch {}
```

## Useful LogQL checks

```logql
{job="docker"}
{app="devops-python"}
{app="devops-python"} | json | level="INFO"
{app="devops-python"} | json | level="ERROR"
sum by (app) (rate({app=~"devops-.*"}[1m]))
sum by (level) (count_over_time({app=~"devops-.*"} | json [5m]))
```
