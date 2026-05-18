# ArgoCD Structure

Эта директория содержит структуру для управления Kubernetes-ресурсами с помощью ArgoCD.

## Структура директорий

```
argocd-structure/
├── applications/          # Определения приложений ArgoCD
├── projects/              # AppProject для изоляции окружений
├── components/            # Базовые компоненты
│   ├── cert-manager/      # Управление сертификатами
│   ├── istio/             # Service mesh
│   ├── metallb/           # LoadBalancer для bare-metal
│   ├── grafana/           # Визуализация метрик
│   ├── victorialogs/      # Логирование
│   └── opa-gatekeeper/    # Политики безопасности
├── secrets/               # Управление секретами (Sealed Secrets, SOPS)
└── docs/                  # Документация
```

## Быстрый старт

### 1. Установка ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Первый вход

```bash
# Получить начальный пароль
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Войти через CLI
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>
```

### 3. Создание первого приложения

Пример приложения с автосинхронизацией:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
```

## Основные возможности

### SyncPolicy параметры

- `prune` - автоматическое удаление ресурсов, отсутствующих в Git
- `selfHeal` - автоматический возврат к состоянию из Git при изменениях
- `syncOptions`:
  - `CreateNamespace=true` - создание namespace автоматически
  - `PrunePropagationPolicy=foreground` - приоритетное удаление
  - `PruneLast=true` - удаление в конце синхронизации

### AppProject

Используется для изоляции приложений по:
- источникам репозиториев
- целевым кластерам и namespace
- правам доступа пользователей

## Production рекомендации

1. **App of Apps** - паттерн для управления множеством приложений
2. **Управление секретами**:
   - Sealed Secrets
   - SOPS + Age/GPG
   - External Secrets Operator
   - ArgoCD Vault Plugin
3. **Версионирование** - используйте теги вместо HEAD в production
4. **Мониторинг** - интеграция с Prometheus/Grafana

## Отладка

Полезные команды CLI:

```bash
argocd app list                    # Список приложений
argocd app get <app-name>          # Детали приложения
argocd app sync <app-name>         # Ручная синхронизация
argocd app diff <app-name>         # Показать различия
argocd app logs <app-name>         # Логи синхронизации
```

## Интеграции

В данной структуре предусмотрены компоненты для:
- cert-manager - автоматические SSL/TLS сертификаты
- Istio - service mesh
- MetalLB - load balancer для bare-metal кластеров
- Grafana - дашборды мониторинга
- VictoriaLogs - централизованное логирование
- OPA Gatekeeper - политики безопасности

## Безопасность

- Используйте AppProject для ограничения доступа
- Настройте RBAC для разных команд
- Храните секреты в зашифрованном виде
- Включите audit logging
