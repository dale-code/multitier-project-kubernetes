Phase 3 Terraform lives here.

You decide the file layout, but a sane starting split is:
  providers.tf   - google provider + version pinning
  variables.tf   - inputs (project_id, region, db_password, ...)
  main.tf        - network, firewall, compute (and/or managed services)
  outputs.tf     - MUST output the public URL/IP of the app
  terraform.tfvars.example - documents required vars (real tfvars gitignored)

Non-negotiables (see PROJECT-SPEC.md section 5):
  - Only the proxy is public. DB/cache/broker stay internal.
  - No secrets in .tf files or git.
  - `terraform destroy` leaves nothing billable behind.
  - Be able to explain where your state lives.
