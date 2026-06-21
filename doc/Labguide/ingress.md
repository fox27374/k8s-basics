# Ingress

Expose HTTP services by hostname/path. k3s bundles the Traefik ingress controller.

## Commands
| Command | Description |
| --- | --- |
| kubectl get ingress | list Ingress resources |
| kubectl get svc -n kube-system traefik | show the bundled Traefik controller |
---

## Tasks
### 1. Deploy an app with a Deployment and a Service
### 2. Create an Ingress with a host rule
### 3. Resolve the host (e.g. via /etc/hosts or a nip.io name)
### 4. Reach the app through the Ingress with curl
