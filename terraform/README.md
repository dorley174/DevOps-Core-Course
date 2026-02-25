# Lab04 — Terraform (Yandex Cloud)

Target: up the VM or netwwork and security group using ports **22/80/5000**.

## Before

1) Download Terraform.
2) Download YC CLI и залогиньтесь.
3) Prepare SSH-ключ (ed25519 рекомендуется):

```bash
ssh-keygen -t ed25519 -C "lab04" -f ~/.ssh/lab04_ed25519
```

## Variables settings

Copy exaample andd fill:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Check that:
- `allowed_ssh_cidr` is better to take in outter IP `/32`.
- SSH-key may transfer using `ssh_public_key` (as a string), лor `ssh_public_key_path`.

### How to transfer creds of Yandex Cloud

There are 2 ways:

**A) Using env:**
- `YC_TOKEN` или `YC_SERVICE_ACCOUNT_KEY_FILE`
- `YC_CLOUD_ID`
- `YC_FOLDER_ID`

**B) Using terraform.tfvars:**
- `cloud_id`, `folder_id`
- `service_account_key_file` or `yc_token`

## Start

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

After `apply` Terraform outputs `public_ip` и `ssh_command`.

## Delete resourses

```bash
terraform destroy
```
