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

## Verifying the five tiers actually talk to each other

Same proof the other phases ask for — hit the app through the public
entry point and confirm it touches every tier:

```bash
INGRESS_IP=$(kubectl get ingress capstone-ingress -n capstone -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP/                 # touches Tomcat/app
curl -X POST http://$INGRESS_IP/notes -d '...'   # touches Postgres + RabbitMQ
curl http://$INGRESS_IP/notes/count      # reports cache-served or not — proves Memcached is wired in
```
  NetworkPolicies to also stop, say, the app tier from being able to
  reach the RabbitMQ management port. Not required here, so left out
  rather than added unexplained.
