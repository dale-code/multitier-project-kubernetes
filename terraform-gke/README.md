# Phase 3 — approach (c): GKE / Kubernetes

This root provisions **only the infrastructure**: VPC, subnet, GKE
cluster, node pool, and an Artifact Registry repo. It does not create
the app's Kubernetes objects — see `../k8s/` for those, and `../k8s/README.md`
for how each of the nine required Kubernetes concepts maps to a file.

## Run it

```bash
cd terraform-gke
cp terraform.tfvars.example terraform.tfvars   # fill in your project_id
terraform init
terraform apply

# Point kubectl at the new cluster (also printed as a Terraform output):
gcloud container clusters get-credentials capstone-gke --zone us-central1-a --project <your-project-id>

# Build + push the app image (from the repo root):
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t us-central1-docker.pkg.dev/<your-project-id>/capstone-images/capstone-app:v1 ./app
docker push us-central1-docker.pkg.dev/<your-project-id>/capstone-images/capstone-app:v1

# Then deploy the stack onto the cluster:
kubectl apply -f ../k8s/
```

Tear down with `terraform destroy` — this removes the cluster, node
pool, network, and registry. Run `kubectl delete -f ../k8s/` (or just
let the cluster deletion take everything with it) first if you want a
clean `kubectl` state on your machine too.

## Decisions (documented, as the root README asks)

- **Deployment approach chosen: (c), GKE.** Chosen because the project
  explicitly asks the Kubernetes-level concepts (Pods, Services,
  ReplicaSets, Deployments, ConfigMaps, Secrets, PersistentVolumes,
  Namespaces, Ingress) to be demonstrated *in the deployed files
  themselves* — a single Compose-on-a-VM deployment (approach a) never
  exercises any of those objects, so it can't satisfy that requirement.
- **Where Terraform state lives:** local, on whichever machine runs
  `apply` (default; no backend configured). That's acceptable for a
  single learner working from one machine. A commented-out `gcs`
  backend block is left in `providers.tf` for the "remote state"
  stretch goal — enabling it requires a pre-existing GCS bucket, so it
  isn't turned on by default.
- **Infra (Terraform) vs. workload (kubectl) split:** see the top of
  `providers.tf`. Short version: the cluster is expensive/slow to
  recreate and changes rarely; the Deployments/Services change often
  while you iterate. Splitting them means editing a probe timeout
  doesn't require touching cluster state.
- **Node pool sizing:** `e2-medium`, autoscaling 1-3 nodes. Five
  lightweight tiers with room for a rolling update comfortably fit;
  the max of 3 is a deliberate cost ceiling for a learning project, not
  a capacity plan.
- **Security:** the only rule this root adds beyond GKE's own managed
  rules is SSH via Identity-Aware Proxy (for node debugging), scoped to
  nodes tagged `capstone-node`. There is no rule opening the database,
  cache, or broker (or any node port) to `0.0.0.0/0` — the only public
  path is the load balancer that GKE provisions from the Ingress
  object in `../k8s/08-ingress.yaml`.
