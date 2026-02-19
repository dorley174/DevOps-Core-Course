# LAB04 — Infrastructure as Code (Terraform + Pulumi)

## 0) Почему Yandex Cloud (я из РФ)

From Russia is better to work with **Yandex Cloud** (registry, billing, accessability). As a zone i use `ru-central1-a`.

Alternatives: VK Cloud / Selectel

---

## 1) Terraform

### 1.1. hat to create

- VPC Network
- Subnet
- Security Group с inbound rules:
  - **22/tcp** (SSH) — using my IP (`allowed_ssh_cidr`)
  - **80/tcp** — open out
  - **5000/tcp** — open out
- VM (Compute Instance) with public IP (NAT)

### 1.2. Repo structure

```
terraform/
  main.tf
  providers.tf
  variables.tf
  locals.tf
  outputs.tf
  versions.tf
  .gitignore
  terraform.tfvars.example
  .tflint.hcl
```

### 1.3. Prepare

1) Download Terraform.
2) Download `yc` CLI.
3) Create an SSH key:

```bash
ssh-keygen -t ed25519 -C "lab04" -f ~/.ssh/lab04_ed25519
```

4) How to know my IP (example):

```bash
curl ifconfig.me
```

### 1.4. Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# filling terraform.tfvars

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

**Output after apply** (вставьте сюда ваш вывод):

- `terraform version`
- `terraform plan` output
- `terraform apply` output
- `public_ip` / `ssh_command`

### 1.5. Access check

```bash
ssh -i ~/.ssh/lab04_ed25519 ubuntu@<PUBLIC_IP>
```

### 1.6. Delete resourses

```bash
terraform destroy
```

---

## 2) Pulumi

### 2.1. What to create

Same is in Terraform (Network/Subnet/SG/VM).

### 2.2. Structure

```
pulumi/
  Pulumi.yaml
  requirements.txt
  __main__.py
  README.md
  .gitignore
```

### 2.3. Authorization YC

Using env (`YC_TOKEN`, `YC_CLOUD_ID`, `YC_FOLDER_ID`, `YC_ZONE`) or using `pulumi config` keys `yandex:*`.

### 2.4. Start

```bash
cd pulumi
python -m venv venv
# Windows:
#   .\venv\Scripts\activate
# Linux/macOS:
#   source venv/bin/activate
pip install -r requirements.txt

pulumi login
pulumi stack init dev

# Provider config (пример):
pulumi config set yandex:cloudId <cloud_id>
pulumi config set yandex:folderId <folder_id>
pulumi config set yandex:zone ru-central1-a
pulumi config set --secret yandex:token <token>

# Project config:
pulumi config set zone ru-central1-a
pulumi config set subnetCidr 10.10.0.0/24
pulumi config set allowedSshCidr "<ваш_IP>/32"
pulumi config set sshUser ubuntu
pulumi config set sshPublicKeyPath "~/.ssh/lab04_ed25519.pub"

pulumi preview
pulumi up
```

**Output after up**:

- `pulumi version`
- `pulumi up` output
- `public_ip` / `ssh_command`

### 2.5. Delete resourses

```bash
pulumi destroy
```

---

## 3) Comparison Terraform vs Pulumi 

| Criteria | Terraform | Pulumi |
|---|---|---|
| Language | HCL | Python |
| Reusing | modules | full language abstraction |
| entry threshold | lower | upper (needed) |
| State | loval / remote backend | Pulumi Cloud / local |

---

## Bonus 1 — Terraform CI (fmt/validate/tflint)

There are workflow `.github/workflows/terraform-ci.yml`.

all logs in lab04 folder

---

