# Phase 3 (approach c) — Kubernetes manifests

Apply everything with:

```bash
kubectl create configmap postgres-init-sql -n capstone --from-file=init.sql=../db/init.sql \
  --dry-run=client -o yaml | kubectl apply -f -   # namespace must exist first, see below

kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-secret.yaml        # your filled-in copy — see 02-secret.example.yaml
kubectl apply -f .                     # applies the rest (numbered so this is deterministic)
```

(`kubectl apply -f .` re-applying files you already applied above is
harmless — Kubernetes objects are declared as desired state, so
applying the same file twice is a no-op if nothing changed.)

Check it's actually up:

```bash
kubectl get all -n capstone
kubectl get ingress -n capstone      # wait for an ADDRESS to appear, then curl it
```

## Where each required concept lives

| Concept | File(s) | What to look at |
|---|---|---|
| **Namespace** | `00-namespace.yaml` | Every other object below is scoped into `capstone`. |
| **Pod** | `06-app.yaml` (and every `template:` block elsewhere) | The `spec.template` inside each Deployment *is* the Pod spec. Explained in full at the top of `06-app.yaml`. |
| **Deployment** | `03-postgres.yaml`, `04-memcached.yaml`, `05-rabbitmq.yaml`, `06-app.yaml`, `07-nginx.yaml` | One per tier. `03-postgres.yaml` has the deep-dive comment on Deployment → ReplicaSet → Pod, and on `strategy: Recreate` vs the default rolling update. |
| **ReplicaSet** | Created automatically by every Deployment above — not hand-written | See the comment in `03-postgres.yaml`. Verify it yourself: `kubectl get rs -n capstone`, then `kubectl delete pod -n capstone -l app=capstone-app` and watch the app ReplicaSet replace it — that's the self-healing the assignment is pointing at. |
| **Service** | `03-postgres.yaml`, `04-memcached.yaml`, `05-rabbitmq.yaml`, `06-app.yaml`, `07-nginx.yaml` | Every internal Service is `type: ClusterIP` — only `07-nginx.yaml`'s is fronted by an Ingress. Full explanation of *why* Services exist (stable name vs. disposable Pod IPs) is in `03-postgres.yaml`. |
| **ConfigMap** | `01-configmap.yaml` (env vars for every tier), `07-nginx.yaml` (a whole mounted file, `nginx.conf`) | Two different consumption patterns of the same concept — env-var injection vs. file mount — both explained where they're used. |
| **Secret** | `02-secret.example.yaml` | Template only — copy to `02-secret.yaml` (gitignored) or create with `kubectl create secret` directly. Consumed by `03-postgres.yaml`, `05-rabbitmq.yaml`, and `06-app.yaml` via `secretKeyRef`/`secretRef`. |
| **PersistentVolume** | `03-postgres.yaml` (PersistentVolumeClaim) | Only the database gets one — memcached and rabbitmq deliberately don't, explained in their own files. GKE dynamically provisions the backing PV + real GCE disk from the PVC; you never hand-write the PV object. |
| **Ingress** | `08-ingress.yaml` | The one object that actually causes GKE to provision a public Google Cloud Load Balancer — the cloud-facing counterpart to `terraform-gke/`'s cluster provisioning. |

## Verifying the five tiers actually talk to each other

Same proof the other phases ask for — hit the app through the public
entry point and confirm it touches every tier:

```bash
INGRESS_IP=$(kubectl get ingress capstone-ingress -n capstone -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP/                 # touches Tomcat/app
curl -X POST http://$INGRESS_IP/notes -d '...'   # touches Postgres + RabbitMQ
curl http://$INGRESS_IP/notes/count      # reports cache-served or not — proves Memcached is wired in
```

## What's intentionally NOT here

- **StatefulSet** — Postgres uses a plain Deployment + PVC (single
  replica) rather than a StatefulSet. A StatefulSet is the
  production-correct choice for a database (stable network identity,
  ordered/rolling storage per replica) but isn't one of the nine
  required concepts, and a single-replica Deployment demonstrates the
  same PVC + Deployment relationship more simply. Worth knowing the
  gap exists.
- **NetworkPolicy** — nothing here restricts which Pods can talk to
  which. All isolation is at the Service level (nothing except nginx
  has a public path) and the GCP firewall level (`terraform-gke/network.tf`),
  not Pod-to-Pod. A real production namespace would likely add
  NetworkPolicies to also stop, say, the app tier from being able to
  reach the RabbitMQ management port. Not required here, so left out
  rather than added unexplained.
