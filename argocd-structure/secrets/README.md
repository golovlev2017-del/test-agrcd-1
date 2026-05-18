# Управление секретами в ArgoCD

Безопасное хранение и управление секретами критически важно для production-окружения.

## Доступные методы

### 1. Sealed Secrets

Шифрование секретов с помощью kubeseal для безопасного хранения в Git.

**Установка контроллера:**
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

**Создание зашифрованного секрета:**
```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml
```

### 2. SOPS + Age/GPG

Шифрование файлов на месте с использованием Mozilla SOPS.

**Установка:**
```bash
# Для Age
age-keygen -o age-key.txt
export AGE_KEY=$(cat age-key.txt)

# Для GPG
gpg --full-generate-key
```

**Создание зашифрованного файла:**
```bash
sops --encrypt --age <AGE_PUBLIC_KEY> secret.yaml.enc.yaml
```

**Интеграция с ArgoCD:**
- Установите secrets-operator или sops-operator
- Настройте decryption в ArgoCD через plugin

### 3. External Secrets Operator

Получение секретов из внешних систем (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault).

**Пример для AWS Secrets Manager:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-external-secret
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: my-secret
  data:
    - secretKey: password
      remoteRef:
        key: /myapp/prod/password
```

### 4. ArgoCD Vault Plugin

Интеграция с HashiCorp Vault для динамического получения секретов.

**Настройка:**
```yaml
# В configmap argocd-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  application.resourceTrackingMethod: annotation
  vault.address: https://vault.example.com
  vault.auth.method: kubernetes
```

## Рекомендации по безопасности

1. **Никогда не храните plaintext секреты в Git**
2. Используйте разные ключи шифрования для разных окружений
3. Регулярно ротируйте ключи шифрования
4. Настройте RBAC для доступа к расшифровке
5. Включите audit logging для всех операций с секретами
6. Используйте short-lived токены где возможно

## Пример структуры

```
secrets/
├── base/                    # Базовые шаблоны
├── production/              # Production секреты (зашифрованные)
│   ├── database.yaml.enc
│   └── api-keys.yaml.enc
├── staging/                 # Staging секреты (зашифрованные)
│   └── ...
└── keys/                    # Ключи шифрования (.gitignore!)
    ├── age-key.txt
    └── gpg-keys/
```

## Отладка

**Проверка расшифровки SOPS:**
```bash
sops --decrypt secret.yaml.enc.yaml
```

**Проверка Sealed Secrets:**
```bash
kubeseal --verify < sealed-secret.yaml
```

**Логи контроллера:**
```bash
kubectl logs -n sealed-secrets-system -l app=sealed-secrets
kubectl logs -n sops-system -l app=sops-operator
```
