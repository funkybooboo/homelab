# Proxmox Infrastructure as Code (IaC) Initiative

## Executive Summary

This document outlines the strategic approach to implementing Infrastructure as Code for a Proxmox VE cluster, following industry best practices for configuration management, automation, and operational excellence.

---

## 1. Current State Assessment

### Manual Operations (ClickOps)
- VM/Container creation via Web UI
- Inconsistent configurations across nodes
- Undocumented infrastructure decisions
- Manual disaster recovery procedures
- Configuration drift over time

### Target State
- 100% infrastructure defined as code
- Version-controlled, peer-reviewed changes
- Automated testing and deployment pipelines
- Immutable infrastructure patterns
- Self-healing and auto-scaling capabilities

---

## 2. Recommended Tool Stack

### Core IaC Layer

| Tool | Purpose | Alternative |
|------|---------|-------------|
| **Terraform** | Resource provisioning | OpenTofu, Pulumi |
| **Ansible** | Configuration management | SaltStack, Chef |
| **Packer** | Golden image building | Custom scripts |
| **Vault** | Secrets management | Infisical, SOPS |

### Supporting Tools

| Tool | Purpose |
|------|---------|
| **Git** | Version control (GitHub/GitLab/Bitbucket) |
| **CI/CD** | GitHub Actions, GitLab CI, Jenkins, or Drone |
| **Terragrunt** | Terraform wrapper for DRY configurations |
| **Pre-commit** | Code quality hooks |
| **TFLint** | Terraform linting |
| **Checkov** | Security/compliance scanning |

---

## 3. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Git Repository                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Terraform  │  │   Ansible   │  │   Packer Templates  │ │
│  │   Modules   │  │   Playbooks │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└──────────────────────┬──────────────────────────────────────┘
                       │
           ┌───────────▼───────────┐
           │     CI/CD Pipeline    │
           │  ┌─────────────────┐  │
           │  │  Validate       │  │
           │  │  Plan → Apply   │  │
           │  │  Test → Deploy  │  │
           │  └─────────────────┘  │
           └───────────┬───────────┘
                       │
           ┌───────────▼───────────┐
           │    Proxmox Cluster      │
           │  ┌─────────────────┐    │
           │  │  Node 1 (PVE)   │    │
           │  │  Node 2 (PVE)   │    │
           │  │  Node N (PVE)   │    │
           │  └─────────────────┘    │
           │  ┌─────────────────┐    │
           │  │  Shared Storage │    │
           │  │  (Ceph/NFS)     │    │
           │  └─────────────────┘    │
           └─────────────────────────┘
```

---

## 4. Directory Structure

```text
proxmox-iac/
├── README.md
├── .pre-commit-config.yaml
├── .gitignore
├── environments/
│   ├── production/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── development/
│       ├── terraform.tfvars
│       └── backend.tf
├── terraform/
│   ├── modules/
│   │   ├── proxmox-vm/
│   │   ├── proxmox-lxc/
│   │   ├── proxmox-network/
│   │   └── proxmox-storage/
│   ├── projects/
│   │   ├── infrastructure/
│   │   ├── kubernetes/
│   │   └── databases/
│   └── providers.tf
├── ansible/
│   ├── inventories/
│   │   ├── production/
│   │   ├── staging/
│   │   └── development/
│   ├── playbooks/
│   │   ├── site.yml
│   │   ├── hardening.yml
│   │   └── monitoring.yml
│   └── roles/
│       ├── common/
│       ├── docker/
│       └── nginx/
├── packer/
│   ├── templates/
│   │   ├── ubuntu-22-04.pkr.hcl
│   │   ├── debian-12.pkr.hcl
│   │   └── alpine-lxc.pkr.hcl
│   └── scripts/
│       ├── setup.sh
│       └── cleanup.sh
└── docs/
    ├── architecture.md
    ├── runbooks/
    └── adr/                    # Architecture Decision Records
```

---

## 5. Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
**Goal:** Establish tooling and version control

- [ ] Set up Git repository with branch protection rules
- [ ] Configure remote state backend (S3/MinIO + DynamoDB/consul)
- [ ] Create Proxmox API tokens with least-privilege access
- [ ] Set up CI/CD pipeline skeleton
- [ ] Implement pre-commit hooks (TFLint, terraform fmt, checkov)

**Deliverables:**
- Working Terraform backend
- CI/CD pipeline with validation
- Documented authentication strategy

### Phase 2: Image Pipeline (Weeks 3-4)
**Goal:** Build golden images with Packer

- [ ] Create base VM templates (Ubuntu LTS, Debian, Alpine)
- [ ] Create base LXC templates
- [ ] Integrate cloud-init for initialization
- [ ] Automate template publishing to Proxmox
- [ ] Document image update process

**Deliverables:**
- Automated image building pipeline
- 3+ base templates ready for deployment
- Image versioning strategy

### Phase 3: Core Infrastructure (Weeks 5-7)
**Goal:** Provision shared infrastructure

- [ ] Network configuration (VLANs, bridges)
- [ ] Storage pools and permissions
- [ ] Shared services (DNS, NTP, monitoring)
- [ ] Backup infrastructure (Proxmox Backup Server)
- [ ] Firewall rules and security groups

**Deliverables:**
- Reusable Terraform modules
- Network topology as code
- Shared services deployed

### Phase 4: Workload Automation (Weeks 8-10)
**Goal:** Deploy application workloads

- [ ] VM provisioning workflows
- [ ] LXC container workflows
- [ ] Kubernetes cluster (if applicable)
- [ ] Database servers
- [ ] Load balancers and reverse proxies

**Deliverables:**
- Production-ready workload modules
- Auto-scaling capabilities
- Health checks and monitoring integration

### Phase 5: Configuration Management (Weeks 11-12)
**Goal:** Post-provisioning automation

- [ ] Ansible integration with Terraform
- [ ] Configuration hardening playbooks
- [ ] Monitoring agent deployment
- [ ] Log aggregation setup
- [ ] Certificate management

**Deliverables:**
- End-to-end automation pipeline
- Hardened baseline configurations
- Monitoring stack operational

### Phase 6: Operations & Optimization (Ongoing)
**Goal:** Production readiness

- [ ] Disaster recovery runbooks
- [ ] Automated backup verification
- [ ] Cost optimization reviews
- [ ] Security auditing automation
- [ ] Documentation maintenance

**Deliverables:**
- Operational runbooks
- Automated DR testing
- Compliance reports

---

## 6. Industry Best Practices

### Security
1. **Never commit secrets** — Use Vault or encrypted SOPS files
2. **Least privilege** — API tokens scoped to specific resources
3. **State encryption** — Encrypt Terraform state at rest
4. **Network segmentation** — VLANs for management, workloads, storage
5. **Immutable infrastructure** — Replace rather than modify

### Operations
1. **GitOps workflow** — All changes via PR, no manual edits
2. **Immutable tags** — Pin provider and module versions
3. **Idempotent deployments** — Same input = same output
4. **Drift detection** — Scheduled runs to detect manual changes
5. **Blue/green deployments** — For critical infrastructure

### Development
1. **Modular design** — Reusable, composable modules
2. **Documentation** — Self-documenting code + READMEs
3. **Testing** — Terratest or kitchen-terraform for modules
4. **Linting** — Automated code quality checks
5. **ADRs** — Document architectural decisions

---

## 7. Key Configuration Patterns

### Terraform Backend (S3-Compatible)

```hcl
terraform {
  backend "s3" {
    bucket                      = "proxmox-terraform-state"
    key                         = "infrastructure/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "https://minio.example.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

### Proxmox Provider Configuration

```hcl
provider "proxmox" {
  pm_api_url          = "https://pve.example.com:8006/api2/json"
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_tls_insecure     = false
  
  # Enable parallel operations
  pm_parallel         = 4
}
```

### Resource Tagging Strategy

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team_name
    CostCenter  = var.cost_center
  }
}
```

---

## 8. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| State corruption | Remote backend with locking, state backups |
| Configuration drift | Scheduled drift detection, policy enforcement |
| Secret leakage | Vault integration, pre-commit secrets scanning |
| Provider breaking changes | Version pinning, automated testing |
| Disaster recovery | Automated backups, documented restore procedures |

---

## 9. Success Metrics

- **Deployment Frequency:** Time from commit to production deployment
- **Lead Time:** Time to provision new infrastructure
- **Change Failure Rate:** Percentage of changes requiring rollback
- **MTTR:** Mean time to recovery from failures
- **Drift Detection:** Time to detect manual changes

**Target:** 100% infrastructure coverage, <5 min provisioning time, zero manual production changes

---

## 10. Next Steps

1. **Immediate:** Set up Git repository and Terraform backend
2. **Week 1:** Configure Proxmox API access and test connectivity
3. **Week 2:** Implement first module (simple VM deployment)
4. **Week 3:** Expand to full stack and establish CI/CD

---

## References

- [Proxmox Terraform Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Ansible Proxmox Modules](https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_module.html)
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/plugins/builders/proxmox)

---

*Document Version: 1.0*
*Last Updated: 2026-07-28*