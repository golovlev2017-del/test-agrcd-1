# Cert Manager для ArgoCD

Cert-manager автоматически управляет SSL/TLS сертификатами в Kubernetes.

## Установка

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
```

## ClusterIssuer для Let's Encrypt

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

## Certificate для ArgoCD

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-server-cert
  namespace: argocd
spec:
  secretName: argocd-server-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - argocd.your-domain.com
  duration: 2160h # 90 дней
  renewBefore: 360h # 15 дней
```

## Интеграция с ArgoCD

После создания секрета обновите конфигурацию ArgoCD:

```bash
kubectl patch deployment argocd-server -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "tls", "mountPath": "/app/config/server/tls"}}]'
```
