# Offline Installation Guide для ArgoCD Components

Этот документ описывает процесс подготовки и установки всех компонентов в **полностью offline-окружении** (без доступа в интернет).

## Требования

1. **Локальный Helm-репозиторий**: Harbor, Nexus Repository, ChartMuseum или аналогичный
2. **Локальный Container Registry**: Harbor, Nexus, Docker Registry с поддержкой OCI
3. **Доступ из кластера Kubernetes** к локальным репозиториям

## Шаг 1: Подготовка Helm Charts

На машине с доступом в интернет выполните следующие команды для скачивания всех необходимых чартов:

```bash
# Cert-Manager
helm pull jetstack/cert-manager --version v1.19.4

# Istio
helm pull istio/base --version 1.29.1
helm pull istio/istiod --version 1.29.1
helm pull istio/gateway --version 1.29.1

# MetalLB
helm pull metallb/metallb --version 0.15.3

# Grafana
helm pull grafana/grafana --version 7.3.6

# VictoriaLogs
helm pull victoriametrics/victorialogs-cluster --version 0.8.0

# OPA Gatekeeper
helm pull gatekeeper/gatekeeper --version 3.22.0
```

## Шаг 2: Загрузка Helm Charts в локальный репозиторий

### Для Harbor (через helm push):

```bash
# Логин в Harbor
helm registry login harbor.local.test:8443 -u admin -p password

# Push чартов
helm push cert-manager-v1.19.4.tgz oci://harbor.local.test:8443/helm-charts
helm push base-1.29.1.tgz oci://harbor.local.test:8443/helm-charts
helm push istiod-1.29.1.tgz oci://harbor.local.test:8443/helm-charts
helm push gateway-1.29.1.tgz oci://harbor.local.test:8443/helm-charts
helm push metallb-0.15.3.tgz oci://harbor.local.test:8443/helm-charts
helm push grafana-7.3.6.tgz oci://harbor.local.test:8443/helm-charts
helm push victorialogs-cluster-0.8.0.tgz oci://harbor.local.test:8443/helm-charts
helm push gatekeeper-3.22.0.tgz oci://harbor.local.test:8443/helm-charts
```

### Для Nexus/ChartMuseum (HTTP):

```bash
#curl --upload-file cert-manager-v1.19.4.tgz https://nexus.local/repository/helm-charts/
# Повторить для всех чартов
```

## Шаг 3: Подготовка Docker образов

Скачайте все необходимые образы на машине с интернетом:

```bash
# Cert-Manager
docker pull quay.io/jetstack/cert-manager-controller:v1.19.4
docker pull quay.io/jetstack/cert-manager-cainjector:v1.19.4
docker pull quay.io/jetstack/cert-manager-webhook:v1.19.4
docker pull quay.io/jetstack/cert-manager-startupapicheck:v1.19.4

# Istio
docker pull docker.io/istio/pilot:1.29.1
docker pull docker.io/istio/install-cni:1.29.1

# MetalLB
docker pull quay.io/metallb/controller:v0.15.3
docker pull quay.io/metallb/speaker:v0.15.3

# Grafana
docker pull grafana/grafana:11.5.0

# VictoriaLogs
docker pull victoriametrics/vlogs-insert:v1.36.0
docker pull victoriametrics/vlogs-select:v1.36.0
docker pull victoriametrics/vlogs-storage:v1.36.0
docker pull victoriametrics/vlogs-ui:v1.36.0
docker pull fluent/fluent-bit:3.1.9

# OPA Gatekeeper
docker pull openpolicyagent/gatekeeper:v3.22.0
```

Сохраните образы в tar-файлы:

```bash
docker save -o cert-manager-images.tar \
  quay.io/jetstack/cert-manager-controller:v1.19.4 \
  quay.io/jetstack/cert-manager-cainjector:v1.19.4 \
  quay.io/jetstack/cert-manager-webhook:v1.19.4 \
  quay.io/jetstack/cert-manager-startupapicheck:v1.19.4

# Повторить для всех компонентов или объединить в один большой файл
docker save -o all-images.tar <список всех образов>
```

## Шаг 4: Загрузка образов в локальный Registry

Перенесите tar-файлы на машину с локальным registry и загрузите:

```bash
# Загрузка в Harbor
docker load -o cert-manager-images.tar

# Retag для локального registry
docker tag quay.io/jetstack/cert-manager-controller:v1.19.4 harbor.local.test:8443/library/quay.io/jetstack/cert-manager-controller:v1.19.4
docker tag quay.io/jetstack/cert-manager-cainjector:v1.19.4 harbor.local.test:8443/library/quay.io/jetstack/cert-manager-cainjector:v1.19.4
docker tag quay.io/jetstack/cert-manager-webhook:v1.19.4 harbor.local.test:8443/library/quay.io/jetstack/cert-manager-webhook:v1.19.4
docker tag quay.io/jetstack/cert-manager-startupapicheck:v1.19.4 harbor.local.test:8443/library/quay.io/jetstack/cert-manager-startupapicheck:v1.19.4

# Push в Harbor
docker push harbor.local.test:8443/library/quay.io/jetstack/cert-manager-controller:v1.19.4
docker push harbor.local.test:8443/library/quay.io/jetstack/cert-manager-cainjector:v1.19.4
docker push harbor.local.test:8443/library/quay.io/jetstack/cert-manager-webhook:v1.19.4
docker push harbor.local.test:8443/library/quay.io/jetstack/cert-manager-startupapicheck:v1.19.4

# Повторить для всех образов
```

## Шаг 5: Настройка манифестов

Все манифесты в этой папке уже настроены на использование:
- Локального Helm репозитория: `http://harbor.local.test:8443/chartrepo/library`
- Локального Container Registry: `harbor.local.test:8443`

При необходимости измените URL на ваши актуальные адреса.

## Шаг 6: Установка через ArgoCD

1. Создайте namespace для каждого компонента
2. Примените HelmRepository манифесты
3. Примените HelmRelease манифесты
4. Дождитесь синхронизации в ArgoCD UI

```bash
# Пример для cert-manager
kubectl apply -f components/cert-manager/install.yaml

# Проверка статуса
kubectl get helmrelease -n cert-manager
kubectl get pods -n cert-manager
```

## Проверка установки

```bash
# Cert-Manager
kubectl get pods -n cert-manager

# Istio
kubectl get pods -n istio-system

# MetalLB
kubectl get pods -n metallb-system

# Grafana
kubectl get pods -n monitoring

# VictoriaLogs
kubectl get pods -n logging

# OPA Gatekeeper
kubectl get pods -n gatekeeper-system
```

## Troubleshooting

### ImagePullBackOff
Проверьте доступность образов в локальном registry:
```bash
crane ls harbor.local.test:8443/library
```

### Helm chart not found
Проверьте наличие чарта в репозитории:
```bash
helm repo add local http://harbor.local.test:8443/chartrepo/library
helm search repo local
```

### Network connectivity
Убедитесь, что все ноды кластера имеют доступ к локальным репозиториям:
```bash
kubectl run test --rm -it --image=busybox -- wget http://harbor.local.test:8443
```

## Важные замечания

1. **Версионирование**: Все версии чартов и образов зафиксированы в манифестах
2. **Обновление**: Для обновления повторите шаги 1-4 с новыми версиями
3. **Безопасность**: Используйте TLS для доступа к локальным репозиториям в production
4. **Резервное копирование**: Сохраните все tar-файлы с образами и чартами
