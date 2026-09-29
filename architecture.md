# Architecture

Two Phase-3 deployment targets exist for this repo (see root README's
"Decisions" section for why). This document describes both, but the
one actually deployed is the GKE/Kubernetes path.

## Diagram — GKE / Kubernetes (approach c, deployed)

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

## Diagram — VM/Compose-on-GCE (approach a, alternate, not deployed)

    Internet
       |
       v
    [ Nginx ]  :80/:443  <-- only public tier, on a single Compute Engine VM
       |
       v
    [ Tomcat / App ]
       |     |     |
       v     v     v
    [ DB ] [Cache] [Broker]   <-- all internal only, same VM, own containers

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

## Where each secret comes from

| Phase | Secret source |
|---|---|
| Vagrant | Environment variables on the VM, read by `provision/setup.sh`. Never hardcoded in the script. |
| Compose | `.env` file (gitignored), documented by `.env.example`. |
| Terraform (a) — GCE VM | `terraform.tfvars` (gitignored), documented by `terraform.tfvars.example`; passed to the VM as startup-script metadata. |
| Terraform-gke + Kubernetes (c) | A Kubernetes `Secret` object in the `capstone` namespace (`k8s/02-secret.example.yaml` is the template — copy to a gitignored `k8s/02-secret.yaml`, or create directly with `kubectl create secret generic app-secrets ...`). Injected into Pods as env vars via `secretKeyRef`/`secretRef`; never baked into the app image, never committed. |

See `k8s/README.md` for the full map of which file demonstrates which
required Kubernetes concept (Pod, Service, ReplicaSet, Deployment,
ConfigMap, Secret, PersistentVolume, Namespace, Ingress).
