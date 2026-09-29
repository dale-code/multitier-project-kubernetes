# Multi-Tier Notes App — Kubernetes on GKE

A five-tier web application, containerized and deployed to Google Cloud
with Terraform (infrastructure) and Kubernetes (workload).

## Stack

```
Nginx  ->  Tomcat (Java/Spring, .war built with Maven)  ->  PostgreSQL + Memcached + RabbitMQ
```

- **Nginx** — reverse proxy, the only public-facing tier.
- **App** — a Spring Boot app packaged as a WAR and run on Tomcat. Endpoints: `GET /`, `POST /notes`, `GET /notes/count` (the count endpoint reports whether it was served from cache, which is how you can prove the tiers are actually wired together).
- **PostgreSQL** — persistent storage for notes.
- **Memcached** — caches the note count.
- **RabbitMQ** — publishes an event on every new note.

The app itself lives in `app/` — source, `Dockerfile`, and
`application.properties`, which reads every connection setting from
environment variables (see `app/src/main/resources/application.properties`).
The same image runs unmodified regardless of what supplies those
variables; only the environment changes.

`db/init.sql` creates the database, the app role, the `note` table, and
seed data. It's idempotent (safe to run more than once) and is loaded
into the cluster as a ConfigMap that Postgres runs on first init — see
`k8s/03-postgres.yaml`. The app also runs Hibernate with
`ddl-auto=update`, so the table is ensured at boot too; the SQL and the
app won't conflict.

## How it's deployed

Two layers, kept deliberately separate:

- **`terraform-gke/`** — provisions the actual Google Cloud
  infrastructure: a dedicated VPC-native VPC/subnet, a GKE Standard
  cluster with an autoscaling node pool, and an Artifact Registry repo
  for the app image. See `terraform-gke/README.md` for the reasoning
  behind each choice.
- **`k8s/`** — the five tiers as Kubernetes objects: a `Namespace`,
  `ConfigMap`s, a `Secret`, per-tier `Deployment`s and `Service`s, a
  `PersistentVolumeClaim` for Postgres, a `HorizontalPodAutoscaler` on
  the app tier, and an `Ingress` in front of Nginx. See
  `k8s/README.md` for exactly which file demonstrates which core
  Kubernetes concept (Pod, ReplicaSet, Deployment, Service, ConfigMap,
  Secret, PersistentVolume, Namespace, Ingress), and
  `KUBERNETES-TEACHING-GUIDE.md` for a full line-by-line walkthrough of
  every file in the project.

## Running it

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

You'll need your own GCP `project_id` (billing-enabled), and to run
`gcloud auth login` / `gcloud auth application-default login` before
`terraform apply`. Everything else is scripted.

Full, dated command history — including the troubleshooting along the
way — is in `COMMANDS.md`.

To tear down: `kubectl delete -f k8s/` then `terraform -chdir=terraform-gke destroy`
(or just `terraform destroy` — deleting the cluster takes the workloads with it).

## Design decisions

- **Kubernetes over a single VM.** The whole point of this deployment
  is for the required Kubernetes objects (Pods, Deployments,
  ReplicaSets, Services, ConfigMaps, Secrets, PersistentVolumes,
  Namespaces, Ingress) to be real, working parts of the system — not
  just described. A single-VM deployment never touches any of those.
- **Terraform for infrastructure, `kubectl` for workload.** The
  cluster is slow/expensive to recreate and changes rarely; the
  Kubernetes objects change constantly while iterating. Splitting them
  means editing a probe timeout doesn't require touching cluster
  state. Full reasoning in `terraform-gke/README.md`.
- **Where Terraform state lives:** local (no backend configured). A
  commented-out GCS backend is left in `terraform-gke/providers.tf`
  for remote state — off by default since it needs a pre-existing
  bucket.
- **How secrets are handled:** Terraform itself carries no app
  secrets — the cluster and registry it creates don't need any.
  App-level secrets (DB/broker passwords) live in a Kubernetes
  `Secret` object (`k8s/02-secret.example.yaml` is the template; the
  real one is a gitignored `k8s/02-secret.yaml`, or created directly
  with `kubectl create secret`) and are injected into Pods as
  environment variables — never committed, never baked into the image.
