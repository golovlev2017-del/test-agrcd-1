# Offline Installation Guide для ArgoCD Components

Этот документ описывает процесс подготовки и установки всех компонентов в **полностью offline-окружении** (без доступа в интернет).

## Требования

1. **Локальный Helm-репозиторий**: Harbor (с поддержкой OCI), Nexus Repository, ChartMuseum или аналогичный
2. **Локальный Container Registry**: Harbor, Nexus, Docker Registry с поддержкой OCI
3. **Локальный Git-сервер**: Gitea, GitLab CE для хранения манифестов
4. **Доступ из кластера Kubernetes** к локальным репозиториям

## Структура проекта

См. основную документацию в [docs/README.md](docs/README.md)

## Шаг 1: Подготовка Helm Charts (на машине с интернетом)

На машине с доступом в интернет выполните следующие команды для скачивания всех необходимых чартов:

```bash
# Создать рабочую директорию
mkdir -p ~/offline-argocd/charts
cd ~/offline-argocd/charts

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

# ArgoCD (сам ArgoCD тоже нужен!)
helm pull argo/argo-cd --version 7.0.0
```

## Шаг 2: Подготовка Docker образов (на машине с интернетом)

Скачайте все необходимые образы:

```bash
mkdir -p ~/offline-argocd/images
cd ~/offline-argocd/images

# Создать список образов для скачивания
cat > images-list.txt <<EOF
# Cert-Manager
quay.io/jetstack/cert-manager-controller:v1.19.4
quay.io/jetstack/cert-manager-cainjector:v1.19.4
quay.io/jetstack/cert-manager-webhook:v1.19.4
quay.io/jetstack/cert-manager-startupapicheck:v1.19.4

# Istio
docker.io/istio/pilot:1.29.1
docker.io/istio/install-cni:1.29.1
docker.io/istio/proxyv2:1.29.1

# MetalLB
quay.io/metallb/controller:v0.15.3
quay.io/metallb/speaker:v0.15.3

# Grafana
docker.io/grafana/grafana:11.5.0

# VictoriaLogs
docker.io/victoriametrics/vlogs-insert:v1.36.0
docker.io/victoriametrics/vlogs-select:v1.36.0
docker.io/victoriametrics/vlogs-storage:v1.36.0
docker.io/victoriametrics/vlogs-ui:v1.36.0
docker.io/fluent/fluent-bit:3.1.9

# OPA Gatekeeper
docker.io/openpolicyagent/gatekeeper:v3.22.0
docker.io/openpolicyagent/gatekeeper-crds:v3.22.0

# ArgoCD
ghcr.io/argoproj/argocd:v2.12.0
ghcr.io/argoproj/argocd-applicationset:v0.11.0
ghcr.io/argoproj/argocd-repo-server:v2.12.0
EOF

# Скачать все образы
while IFS= read -r image; do
    [[ "$image" =~ ^#.*$ ]] && continue
    [[ -z "$image" ]] && continue
    echo "Pulling: $image"
    docker pull "$image"
done < images-list.txt

# Сохранить все образы в один tar-файл
echo "Saving images to all-images.tar..."
docker save -o all-images.tar $(cat images-list.txt | grep -v "^#" | grep -v "^$")

# Опционально: сжать для экономии места
gzip all-images.tar
```

## Шаг 3: Загрузка в локальные репозитории (на машине с интернетом или bastion)

### 3.1. Загрузка Helm charts в Harbor (OCI)

```bash
# Логин в Harbor
helm registry login harbor.local.test:8443 -u admin -p <password>

# Push чартов в OCI формат
for chart in *.tgz; do
    echo "Pushing $chart..."
    helm push "$chart" oci://harbor.local.test:8443/helm-charts
done
```

### 3.2. Загрузка Docker образов в Harbor

```bash
# Загрузить образы из tar
gunzip -c all-images.tar.gz | docker load

# Скрипт для retag и push
cat > push-images.sh <<'SCRIPT'
#!/bin/bash
REGISTRY="harbor.local.test:8443"

while IFS= read -r image; do
    [[ "$image" =~ ^#.*$ ]] && continue
    [[ -z "$image" ]] && continue
    
    # Извлечь имя образа
    image_name=$(echo "$image" | sed 's|^.*/||')
    repo_path=$(echo "$image" | cut -d'/' -f1-2)
    
    # Сформировать новое имя
    if [[ "$repo_path" == "quay.io"* ]]; then
        new_image="$REGISTRY/library/$image"
    elif [[ "$repo_path" == "docker.io"* ]]; then
        new_image="$REGISTRY/library/${image#docker.io/}"
    elif [[ "$repo_path" == "ghcr.io"* ]]; then
        new_image="$REGISTRY/library/${image#ghcr.io/}"
    else
        new_image="$REGISTRY/library/$image"
    fi
    
    echo "Tagging: $image -> $new_image"
    docker tag "$image" "$new_image"
    docker push "$new_image"
done < images-list.txt
SCRIPT

chmod +x push-images.sh
./push-images.sh
```

## Шаг 4: Перенос в offline-контур

Сохраните всё в архив для переноса:

```bash
cd ~/offline-argocd
tar czf offline-package.tar.gz \
  charts/*.tgz \
  images/all-images.tar.gz \
  images/images-list.txt \
  images/push-images.sh

# Перенесите offline-package.tar.gz в offline-контур
# Например, через scp на bastion-хост:
# scp offline-package.tar.gz user@bastion:/tmp/
```

## Шаг 5: Установка в offline-контуре

### 5.1. Распаковка и загрузка

```bash
# На машине внутри offline-контура
cd /tmp
tar xzf offline-package.tar.gz

# Загрузить образы в локальный registry
cd images
../scripts/import-images.sh all-images.tar.gz harbor.local.test:8443
```

### 5.2. Установка ArgoCD

```bash
# Создать namespace
kubectl create namespace argocd

# Применить манифесты ArgoCD (предварительно скачанные)
kubectl apply -n argocd -f argocd-install.yaml

# Дождаться запуска
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
```

### 5.3. Применение конфигурации из этого репозитория

```bash
# Клонируйте локальный git-репозиторий с манифестами
git clone https://git.local.test/infrastructure/manifests.git
cd manifests

# Применить базовую конфигурацию ArgoCD
kubectl apply -f bootstrap/argocd-config/

# Применить корневое приложение
kubectl apply -f bootstrap/root-app.yaml
```

## Шаг 6: Проверка установки

```bash
# Проверить статус приложений ArgoCD
argocd app list

# Проверить статус корневого приложения
argocd app get root-app

# Проверить поды всех компонентов
kubectl get pods -n cert-manager
kubectl get pods -n istio-system
kubectl get pods -n metallb-system
kubectl get pods -n monitoring
kubectl get pods -n logging
kubectl get pods -n gatekeeper-system
```

## Troubleshooting

### ImagePullBackOff

Проверьте доступность образов в локальном registry:

```bash
# Через crane (если установлен)
crane ls harbor.local.test:8443/library

# Или через curl API Harbor
curl -k -u admin:password https://harbor.local.test:8443/api/v2.0/projects/library/repositories
```

### Helm chart not found

Проверьте наличие чарта в репозитории:

```bash
helm repo add local http://harbor.local.test:8443/chartrepo/library
helm search repo local
helm pull local/cert-manager --version v1.19.4
```

### Network connectivity

Убедитесь, что все ноды кластера имеют доступ к локальным репозиториям:

```bash
kubectl run test --rm -it --image=busybox -- wget http://harbor.local.test:8443
kubectl run test-git --rm -it --image=alpine/git -- clone https://git.local.test/infrastructure/manifests.git
```

### Проблемы с синхронизацией ArgoCD

```bash
# Логи application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Логи repo server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Проверка подключения к репозиторию
argocd repo get <repo-name>
argocd repo test <repo-name>
```

## Важные замечания

1. **Версионирование**: Все версии чартов и образов зафиксированы в манифестах. Не используйте `latest`!
2. **Обновление**: Для обновления повторите шаги 1-4 с новыми версиями на машине с интернетом
3. **Безопасность**: 
   - Используйте TLS для доступа к локальным репозиториям в production
   - Настройте аутентификацию между ArgoCD и репозиториями
4. **Резервное копирование**: 
   - Сохраните все tar-файлы с образами и чартами
   - Регулярно бэкапьте etcd кластера
   - Бэкапьте конфигурацию ArgoCD (Applications, AppProjects, Repositories)
5. **Тестирование**: Всегда тестируйте новые версии на staging-контуре перед production

## Матрица совместимости версий

| Компонент | Версия | Образы | Helm Chart |
|-----------|--------|--------|------------|
| Cert-Manager | v1.19.4 | v1.19.4 | v1.19.4 |
| Istio | 1.29.1 | 1.29.1 | 1.29.1 |
| MetalLB | 0.15.3 | v0.15.3 | 0.15.3 |
| Grafana | 11.5.0 | 11.5.0 | 7.3.6 |
| VictoriaLogs | v1.36.0 | v1.36.0 | 0.8.0 |
| OPA Gatekeeper | v3.22.0 | v3.22.0 | 3.22.0 |
| ArgoCD | v2.12.0 | v2.12.0 | 7.0.0 |
