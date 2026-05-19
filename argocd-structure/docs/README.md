# ArgoCD Structure для полностью изолированного окружения (Offline)

Эта директория содержит структуру для управления Kubernetes-ресурсами с помощью ArgoCD в **полностью изолированном контуре без доступа в интернет**.

## Структура директорий

```
argocd-structure/
├── bootstrap/                 # Базовая настройка ArgoCD (App of Apps)
│   ├── argocd-config/         # Конфигурация самого ArgoCD
│   │   ├── argocd-cm.yaml     # ConfigMap ArgoCD
│   │   ├── argocd-rbac-cm.yaml # RBAC настройки
│   │   └── repositories.yaml  # Определение репозиториев
│   └── root-app.yaml          # Корневое приложение (App of Apps)
├── applications/              # Определения приложений ArgoCD
│   ├── components/            # Инфраструктурные компоненты
│   └── workloads/             # Пользовательские приложения
├── projects/                  # AppProject для изоляции окружений
├── components/                # Helm charts и манифесты компонентов
│   ├── cert-manager/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── istio/
│   ├── metallb/
│   ├── grafana/
│   ├── victorialogs/
│   └── opa-gatekeeper/
├── charts/                    # Локальные Helm charts (оффлайн)
│   └── *.tgz                  # Упакованные чарты
├── images/                    # Скрипты для импорта образов
│   └── import-images.sh
├── secrets/                   # Управление секретами (Sealed Secrets, SOPS)
└── docs/                      # Документация
```

## Ключевые особенности для offline-окружения

### 1. Локальные репозитории

Все зависимости должны быть доступны внутри контура:

| Тип | Решение | Пример URL |
|-----|---------|-----------|
| Git-репозиторий | Gitea / GitLab CE | `https://git.local.test` |
| Helm-репозиторий | Harbor / Nexus / ChartMuseum | `http://harbor.local.test:8443/chartrepo/library` |
| Container Registry | Harbor / Nexus / Docker Registry | `harbor.local.test:8443` |

### 2. Подготовка к переносу в offline

**На машине с интернетом:**

```bash
# 1. Скачать все Helm charts
helm pull jetstack/cert-manager --version v1.19.4
helm pull istio/base --version 1.29.1
# ... остальные чарты

# 2. Скачать все Docker образы
docker pull quay.io/jetstack/cert-manager-controller:v1.19.4
# ... остальные образы

# 3. Сохранить образы в tar
docker save -o all-images.tar <список всех образов>

# 4. Упаковать всё для переноса
tar czf offline-package.tar.gz \
  *.tgz \
  all-images.tar \
  manifests/
```

**На offline-машине:**

```bash
# 1. Загрузить образы в локальный registry
./images/import-images.sh all-images.tar harbor.local.test:8443

# 2. Загрузить Helm charts в Harbor/Nexus
helm push cert-manager-v1.19.4.tgz oci://harbor.local.test:8443/helm-charts

# 3. Применить конфигурацию ArgoCD
kubectl apply -f bootstrap/argocd-config/
kubectl apply -f bootstrap/root-app.yaml
```

### 3. App of Apps паттерн

Используется для каскадного развертывания всех компонентов:

```
root-app (bootstrap/root-app.yaml)
├── infrastructure-components (ApplicationSet)
│   ├── cert-manager
│   ├── metallb
│   ├── istio
│   ├── grafana
│   ├── victorialogs
│   └── opa-gatekeeper
└── workloads
    └── my-app
```

## Быстрый старт

### 1. Установка ArgoCD (offline)

```bash
# Предварительно скачайте манифесты ArgoCD на машине с интернетом:
# curl -LO https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl create namespace argocd
kubectl apply -n argocd -f install.yaml
```

### 2. Первый вход

```bash
# Получить начальный пароль
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Войти через CLI (укажите внутренний адрес ArgoCD)
argocd login argocd.local.test --username admin --password <PASSWORD> --insecure
```

### 3. Применение корневой конфигурации

```bash
# Применить конфигурацию ArgoCD
kubectl apply -f bootstrap/argocd-config/

# Применить корневое приложение
kubectl apply -f bootstrap/root-app.yaml
```

### 4. Проверка статуса

```bash
# Проверить статус всех приложений
argocd app list

# Проверить статус корневого приложения
argocd app get root-app

# Просмотреть логи синхронизации
argocd app logs root-app
```

## Основные возможности

### SyncPolicy параметры

- `prune` - автоматическое удаление ресурсов, отсутствующих в Git
- `selfHeal` - автоматический возврат к состоянию из Git при изменениях
- `allowEmpty` - запрет на пустое состояние (важно для production)
- `syncOptions`:
  - `CreateNamespace=true` - создание namespace автоматически
  - `PrunePropagationPolicy=foreground` - приоритетное удаление
  - `PruneLast=true` - удаление в конце синхронизации
  - `RespectIgnoreDifferences=true` - игнорирование указанных различий
  - `ApplyOutOfSyncOnly=true` - применение только к рассинхронизированным ресурсам

### AppProject

Используется для изоляции приложений по:
- источникам репозиториев
- целевым кластерам и namespace
- правам доступа пользователей

## Production рекомендации

1. **App of Apps** - паттерн для управления множеством приложений
2. **Управление секретами**:
   - Sealed Secrets (рекомендуется для offline)
   - SOPS + Age/GPG
   - External Secrets Operator (если есть Vault внутри контура)
3. **Версионирование** - используйте конкретные теги вместо HEAD/main в production
4. **Мониторинг** - интеграция с Prometheus/Grafana внутри контура
5. **Резервное копирование** - регулярно бэкапьте:
   - Все tar-файлы с образами
   - Helm charts
   - Конфигурацию ArgoCD (etcd backup)

## Отладка

Полезные команды CLI:

```bash
argocd app list                    # Список приложений
argocd app get <app-name>          # Детали приложения
argocd app sync <app-name>         # Ручная синхронизация
argocd app diff <app-name>         # Показать различия
argocd app logs <app-name>         # Логи синхронизации
argocd repo list                   # Список репозиториев
argocd cluster list                # Список кластеров
```

Проверка внутри кластера:

```bash
# Статус Application CRD
kubectl get applications -n argocd

# Логи контроллера ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Статус синхронизации
kubectl describe application <app-name> -n argocd
```

## Интеграции

В данной структуре предусмотрены компоненты для:
- **cert-manager** - автоматические SSL/TLS сертификаты (с локальным CA)
- **Istio** - service mesh
- **MetalLB** - load balancer для bare-metal кластеров
- **Grafana** - дашборды мониторинга
- **VictoriaLogs** - централизованное логирование
- **OPA Gatekeeper** - политики безопасности

## Безопасность

1. Используйте AppProject для ограничения доступа
2. Настройте RBAC для разных команд
3. Храните секреты в зашифрованном виде (Sealed Secrets/SOPS)
4. Включите audit logging
5. Регулярно обновляйте образы и чарты (через процедуру обновления offline)
6. Используйте TLS для всех внутренних сервисов

## Обновление в offline-режиме

1. На машине с интернетом скачать новые версии
2. Протестировать на staging-контуре
3. Перенести архивы в production-контур
4. Обновить версии в манифестах
5. Выполнить sync через ArgoCD
