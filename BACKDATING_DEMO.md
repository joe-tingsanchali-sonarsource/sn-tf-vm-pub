# SonarQube Issue Backdating Demonstration

## What is Issue Backdating?

When SonarQube detects a "new" issue during analysis, it normally stamps the issue with the **analysis date**. However, in certain cases the code containing the issue was committed much earlier. In those situations, SonarQube **backdates** the issue: instead of using the analysis date, it uses the **git blame date** of the line where the issue was found.

This ensures that issues appearing on old code are not incorrectly counted as new code debt. Without backdating, activating a new rule or analyzing a branch for the first time would flood the "new code" view with issues that actually existed for months or years.

Reference: [SonarQube docs — Issue Backdating](https://docs.sonarsource.com/sonarqube-cloud/discovering-sonarcloud/analysis-process-overview/analysis-process#issue-backdating)

## When Does Backdating Occur?

SonarQube backdates an issue identified as new when **the date of the last change to the line is available** and one of the following conditions is met:

1. **First analysis of a project or branch** — all issues are technically "new" since there is no prior analysis to compare against.
2. **A rule is new in the quality profile** — either a brand-new rule was activated, or a previously deactivated rule was re-enabled, or a rule parameter was changed.
3. **SonarQube was recently upgraded** — rule implementations may have improved, detecting issues that were previously missed.
4. **The rule is external** — managed and applied by a third-party analyzer.
5. **Previously excluded files are now analyzed** — files that were out of scope are brought into the analysis.

## How This Demo Works

This branch (`feature/backdating-demo`) contains two commits with deliberately different git dates:


| Commit | File                 | Git Date             | Purpose                                                                                           |
| ------ | -------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| 1      | `demo_backdating.tf` | **January 15, 2023** | Terraform file with intentional IaC security issues, committed with a manually backdated git date |
| 2      | `BACKDATING_DEMO.md` | **April 29, 2026**   | This documentation file, committed with today's real date                                         |


### The Backdated File: `demo_backdating.tf`

This file introduces two Azure resources with intentional security issues:

**Network Security Group with unrestricted SSH access (S6321)**

```hcl
security_rule {
  name                       = "SSH"
  source_address_prefix      = "*"    # Allows inbound SSH from any IP
  destination_port_range     = "22"
}
```

**Storage Account with weak TLS (S4423)**

```hcl
resource "azurerm_storage_account" "demo_backdating_storage" {
  min_tls_version = "TLS1_0"          # Should be TLS1_2
}
```

The commit was created with manipulated git dates:

```bash
GIT_AUTHOR_DATE="2023-01-15T10:00:00-05:00" \
GIT_COMMITTER_DATE="2023-01-15T10:00:00-05:00" \
git commit -m "feat: add storage account and secondary NSG configuration"
```

### What SonarQube Does

Since this is the **first analysis of the `feature/backdating-demo` branch**, all issues are considered "new" by SonarQube. The backdating algorithm then:

1. Runs `git blame` on each file to determine when each line was last modified.
2. For issues found in `demo_backdating.tf`, it sees the commit date is **January 15, 2023**.
3. Instead of assigning today's analysis date, it **backdates** those issues to January 15, 2023.
4. Issues found in files committed with today's real date (like existing `.tf` files or this `.md` file) retain the actual analysis date.

## Verified Results

The analysis ran on April 30, 2026. Both issues in `demo_backdating.tf` were assigned `creationDate: 2023-01-15` — not the analysis date — confirming backdating worked.

| Issue key | Rule | File | Line | `creationDate` |
|-----------|------|------|------|----------------|
| `AZ3bpm-boMUcc9uIyK8R` | `terraform:S6321` | `demo_backdating.tf` | 14 | **2023-01-15** |
| `AZ3bpm-boMUcc9uIyK8T` | `terraform:S4423` | `demo_backdating.tf` | 25 | **2023-01-15** |

Verified via the SonarCloud API:

```
https://sonarcloud.io/api/issues/search?componentKeys=joe-tingsanchali-sonarsource_sn-tf-vm-pub&branch=feature%2Fbackdating-demo&resolved=false
```

## How to View in the UI

1. Open the [Issues page](https://sonarcloud.io/project/issues?id=joe-tingsanchali-sonarsource_sn-tf-vm-pub&branch=feature%2Fbackdating-demo&resolved=false) on the `feature/backdating-demo` branch.
2. Each issue row shows a **relative timestamp** on the right (e.g. "3 years ago") — that is the `creationDate`, backdated to the commit date.
3. Hovering over the relative timestamp shows the full date: **Jan 15, 2023**.
4. Direct links to the issues:
   - [S6321 — Unrestricted SSH access](https://sonarcloud.io/project/issues?id=joe-tingsanchali-sonarsource_sn-tf-vm-pub&branch=feature%2Fbackdating-demo&open=AZ3bpm-boMUcc9uIyK8R)
   - [S4423 — Weak TLS version](https://sonarcloud.io/project/issues?id=joe-tingsanchali-sonarsource_sn-tf-vm-pub&branch=feature%2Fbackdating-demo&open=AZ3bpm-boMUcc9uIyK8T)

This confirms that SonarQube used `git blame` to backdate the issue creation date to the commit date of the line, rather than stamping it with the analysis date.

## Key Prerequisite: Full Git History

For backdating to work, SonarQube needs access to the full git history. The CI workflow at `.github/workflows/build.yml` uses:

```yaml
- uses: actions/checkout@v3
  with:
    fetch-depth: 0  # Full clone, not shallow
```

If `fetch-depth` were set to `1` (shallow clone), `git blame` would attribute all lines to the single fetched commit and backdating would not reflect the true commit dates.

---

## How to Reproduce

**Prerequisites:** A SonarCloud-connected repo with `fetch-depth: 0` in CI and a valid `SONAR_TOKEN` secret.

**1. Create a new branch** (first analysis of a branch triggers backdating):

```bash
git checkout -b feature/my-backdating-test
```

**2. Create a file with a detectable issue and commit it with a backdated date:**

```bash
cat > demo_backdating.tf << 'EOF'
resource "azurerm_network_security_group" "demo" {
  name                = "demo-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.sn_tf_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
EOF

git add demo_backdating.tf
GIT_AUTHOR_DATE="2020-06-01T10:00:00-05:00" \
GIT_COMMITTER_DATE="2020-06-01T10:00:00-05:00" \
git commit -m "feat: add NSG configuration"
```

**3. Push to trigger analysis:**

```bash
git push -u origin feature/my-backdating-test
```

**4. Verify** — once CI completes, query the SonarCloud API (no auth needed for public projects):

```bash
curl -s "https://sonarcloud.io/api/issues/search?componentKeys=<YOUR_PROJECT_KEY>&branch=feature%2Fmy-backdating-test&resolved=false" \
  | jq '[.issues[] | {rule, line, creationDate, component}]'
```

**Expected:** `creationDate` matches the backdated commit date (e.g. `2020-06-01`), not today's date.