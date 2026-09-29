# Architecture

## Diagram

    Internet
       |
       v
    [ GCP HTTP(S) Load Balancer ]   <- created by k8s/08-ingress.yaml
       |
       v
    [ Service: nginx ]  (ClusterIP + NEG)         :80
       |
       v
    [ Deployment: nginx ]  x2 replicas             :80
       |
       v
    [ Service: app ]  (ClusterIP)                  :8080
       |
       v
    [ Deployment: app (Tomcat/Spring) ]  x2-5 replicas (HPA)   :8080
       |         |            |
       v         v            v
    [ Service:  [ Service:   [ Service:
      postgres]   memcached]   rabbitmq]
       :5432       :11211       :5672
       |            |            |
       v            v            v
    [ Deployment: [ Deployment: [ Deployment:
      postgres]     memcached]    rabbitmq]
      + PVC          (ephemeral)   (ephemeral)
      (1 replica)    (1 replica)   (1 replica)

    All of the above lives inside one Kubernetes Namespace: "capstone".

## Public vs internal

- **Public:** only the GCP Load Balancer created by the Ingress, which
  forwards to the `nginx` Service/Deployment. Nothing else has a public
  IP, a `NodePort`, or a `LoadBalancer`-type Service.
- **Internal only:** `app`, `postgres`, `memcached`, `rabbitmq` — all
  `type: ClusterIP` Services, reachable only from inside the cluster.
  RabbitMQ's management UI (port 15672) is likewise internal-only;
  reach it with `kubectl port-forward`, never publicly.
- **Node-level access:** SSH to GKE nodes is allowed only via
  Identity-Aware Proxy (`terraform-gke/network.tf`), not the open
  internet, and is for node debugging — it has nothing to do with the
  app's data path.

## Persistent data

Only Postgres needs data to survive a restart. It gets a
`PersistentVolumeClaim` (`k8s/03-postgres.yaml`), which GKE dynamically
backs with a real GCE Persistent Disk. Deleting the `postgres`
Deployment/Pod does **not** delete this disk — only deleting the PVC
does. Memcached and RabbitMQ are deliberately left without persistent
storage (a cache and, in this scope, a queue are both treated as
disposable/rebuildable) — see the "intentionally not here" note in
`k8s/README.md`.

## Scaling and self-healing

- The app tier's `Deployment` keeps 2–5 Pods alive via its
  `ReplicaSet`; a `HorizontalPodAutoscaler` (`k8s/06-app.yaml`) moves
  the replica count within that range based on CPU usage.
- The GKE node pool (`terraform-gke/gke.tf`) autoscales nodes between
  `node_min_count` and `node_max_count`, and has `auto_repair`
  enabled — Google replaces nodes that fail health checks.
- Every tier's Deployment carries liveness/readiness probes, so a
  wedged container gets restarted and a not-yet-ready one is pulled
  out of its Service's rotation automatically.

## Where each secret comes from

Terraform carries no application secrets — the cluster and Artifact
Registry repo it creates don't need any. App-level secrets
(DB/broker passwords) live in a Kubernetes `Secret` object in the
`capstone` namespace (`k8s/02-secret.example.yaml` is the template —
copy to a gitignored `k8s/02-secret.yaml`, or create directly with
`kubectl create secret generic app-secrets ...`). They're injected
into Pods as env vars via `secretKeyRef`/`secretRef`; never baked into
the app image, never committed.

See `k8s/README.md` for the full map of which file demonstrates which
Kubernetes concept (Pod, Service, ReplicaSet, Deployment, ConfigMap,
Secret, PersistentVolume, Namespace, Ingress), and
`KUBERNETES-TEACHING-GUIDE.md` for a line-by-line walkthrough of every
file in the project.
