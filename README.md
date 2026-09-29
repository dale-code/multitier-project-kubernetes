# Multi-Tier Web App — Capstone (Student Repo)

> Starter scaffold. Read `PROJECT-SPEC.md` for the full requirements and rubric.
> Everything here is a skeleton with TODOs — the implementation is yours.

## Stack (fixed)

Nginx → Tomcat (Java/Spring `.war`, built with Maven) → PostgreSQL + Memcached + RabbitMQ.

## The app is provided

A working Spring Boot app lives in `app/` — **you don't write it, you deploy it.** It builds to `capstone.war` with `mvn package` and reads all connection settings from environment variables (see `app/src/main/resources/application.properties`). Endpoints: `GET /`, `POST /notes`, `GET /notes/count` (the count endpoint reports whether it was cache-served, which is how you prove the tiers are wired). To build it locally: `cd app && mvn package`.

## Database setup is provided

`db/init.sql` creates the database, the app role, the `note` table, and seed data. It's idempotent (safe to run repeatedly). Wire it into each phase:
- **Compose:** mount it at `/docker-entrypoint-initdb.d/init.sql` (runs on first init of an empty volume).
- **Vagrant / VM:** `sudo -u postgres psql -f /vagrant/db/init.sql`.

The app also runs Hibernate with `ddl-auto=update`, so the table is ensured at boot too — the SQL and the app won't conflict. Just keep the credentials in `init.sql`, your `.env`, and your `tfvars` in sync (and change the default password before deploying to the cloud).

## The three phases

1. **Vagrant** — `Vagrantfile` + `provision/` — full stack on one VM.
2. **Docker Compose** — `docker-compose.yml` + `app/Dockerfile` — one container per service.
3. **Terraform + GCP** — deployed to the cloud via IaC. Two sibling implementations of this phase exist:
   - `terraform/` — approach (a), a single Compute Engine VM running Docker Compose.
   - `terraform-gke/` + `k8s/` — **approach (c), the one actually deployed here**: Terraform provisions a GKE cluster; the five tiers run as Kubernetes objects (Deployments, Services, ConfigMaps, Secrets, a PersistentVolumeClaim, an Ingress) inside it. See `k8s/README.md` for exactly which file demonstrates which Kubernetes concept.

## Fill this in as you go

### Running Phase 1
```
# TODO: exact commands
```

### Running Phase 2
```
# TODO: exact commands
```

### Running Phase 3 (approach c — GKE)

```bash
# 1. Provision the cluster + supporting infra
cd terraform-gke
cp terraform.tfvars.example terraform.tfvars   # fill in your project_id
terraform init && terraform apply

# 2. Point kubectl at it (also a Terraform output)
gcloud container clusters get-credentials capstone-gke --zone us-central1-a --project <your-project-id>

# 3. Build + push the app image
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t us-central1-docker.pkg.dev/<your-project-id>/capstone-images/capstone-app:v1 ./app
docker push us-central1-docker.pkg.dev/<your-project-id>/capstone-images/capstone-app:v1
# then edit k8s/06-app.yaml's image: line to match what you just pushed

# 4. Deploy the stack
cd ../k8s
kubectl apply -f 00-namespace.yaml
kubectl create configmap postgres-init-sql -n capstone --from-file=init.sql=../db/init.sql
kubectl apply -f 01-configmap.yaml
cp 02-secret.example.yaml 02-secret.yaml   # edit with real values first
kubectl apply -f 02-secret.yaml
kubectl apply -f .

# 5. Get the public address (takes a few minutes to provision)
kubectl get ingress capstone-ingress -n capstone -w
```

**Reviewer must supply:** their own GCP `project_id` (billing-enabled), and
run `gcloud auth login` / `gcloud auth application-default login` before
`terraform apply`. Everything else is scripted.

To tear down: `kubectl delete -f k8s/` then `terraform -chdir=terraform-gke destroy`
(or just `terraform destroy` — deleting the cluster takes the workloads with it).

## Decisions (you must document these)

- **Phase 3 deployment approach chosen: (c), GKE/Kubernetes.** Chosen
  because the project also requires demonstrating Kubernetes' core
  objects (Pods, Deployments, ReplicaSets, Services, ConfigMaps,
  Secrets, PersistentVolumes, Namespaces, Ingress) in the deployed
  files themselves — approach (a)'s single VM never touches any of
  those, so it can't satisfy that half of the assignment. Full
  reasoning in `terraform-gke/README.md`.
- **Where Terraform state lives:** local, per Terraform root (`terraform/`
  and `terraform-gke/` each have their own state — they provision
  independent infrastructure and were never meant to share state). A
  commented-out GCS backend is left in `terraform-gke/providers.tf` for
  anyone who wants remote state; it's off by default since it needs a
  pre-existing bucket.
- **How secrets are handled at each phase:**
  - *Vagrant:* read from the environment on the VM, never hardcoded in `provision/setup.sh`.
  - *Compose:* `.env` (gitignored), documented by `.env.example`.
  - *Terraform (a):* `terraform.tfvars` (gitignored), documented by `terraform.tfvars.example`; passed to the VM's startup script as metadata, not baked into an image.
  - *Terraform-gke + Kubernetes (c):* Terraform itself carries no app secrets at all — the GKE cluster and Artifact Registry repo it creates don't need any. App-level secrets (DB/broker passwords) live in a Kubernetes `Secret` object (`k8s/02-secret.example.yaml` is the template; the real one is created directly with `kubectl create secret` or from a gitignored `k8s/02-secret.yaml` copy) and are injected into Pods as env vars — never committed, never in a container image.

## Checklist before submitting

- [ ] `vagrant destroy -f && vagrant up` works with zero manual steps
- [ ] `docker compose down && docker compose up` works; DB data persists
- [ ] `terraform apply` yields a working public URL in outputs
- [ ] `terraform destroy` leaves nothing billable
- [ ] No secrets, state, `.env`, or `*.tfvars` committed (check `git status`!)
- [ ] `architecture.md` diagram matches what actually runs
