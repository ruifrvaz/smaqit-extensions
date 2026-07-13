# Provisioning Checklist

10 checks for infrastructure repeatability, backup coverage, and secrets management.

| Check | Pass Condition |
|-------|----------------|
| IaC present (Ansible, Terraform, or equivalent) | At least one IaC file present that describes the deployment environment |
| Systemd unit for autostart present | Inventory `provisioning.systemd_unit` is `true` — a `.service` unit file targets the compose stack or application |
| Backup script deployment path matches actual deployment | The hardcoded path variable in the backup script matches the path documented in project materials |
| Backup script covers database | Inventory `backup.covers_database` is `true` — a database dump utility is invoked |
| Backup script covers `.env` / secrets | Inventory `backup.covers_config` is `true` — `.env` or equivalent config file is included |
| Backup script covers application-specific config | Application-specific configuration (e.g. agent config export, settings dump) exported or backed up |
| Backup script covers data volumes | Inventory `backup.covers_volumes` is `true` — data volumes or external service data directories included |
| Backup rotation configured | Old backup directories pruned automatically (e.g. `find ... -mtime`, `rm` of aged backups) |
| Secrets at rest are encrypted | Inventory `provisioning.secret_tool` is not `"none"` (e.g. SOPS, Ansible Vault, HashiCorp Vault) |
| First-deploy / onboarding documentation exists | Onboarding or first-deploy documentation present and references current stack components |
