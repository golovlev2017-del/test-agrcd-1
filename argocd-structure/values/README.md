# ArgoCD с Helm Values Files - Полная документация
# ==================================================

## Обзор

Проект адаптирован для использования **Helm Values Files** - рекомендованного способа управления конфигурацией в ArgoCD.
Все параметры (версии, репозитории, пулы адресов, образы и т.д.) вынесены в отдельные YAML файлы.

## Структура проекта

```
argocd-structure/
├── bootstrap/                    # Bootstrap приложения ArgoCD
│   ├── root-app.yaml            # Корневое приложение (App of Apps)
│   └── argocd-config/           # Конфигурация самого ArgoCD
├── applications/                 # Приложения ArgoCD
│   └── components/
│       └── infrastructure-components.yaml  # ApplicationSet для всех компонентов
├── values/                       # Helm Values Files (НОВОЕ!)
│   ├── README.md                # Документация по использованию
│   ├── global-values.yaml       # Глобальные настройки
│   ├── calico-values.yaml       # Calico параметры
│   ├── cert-manager-values.yaml # Cert-Manager параметры
│   ├── istio-values.yaml        # Istio параметры
│   ├── victoriametrics-values.yaml
│   ├── vmagent-values.yaml
│   ├── grafana-values.yaml
│   ├── victorialogs-values.yaml
│   ├── node-exporter-values.yaml
│   ├── kube-state-metrics-values.yaml
│   ├── opa-gatekeeper-values.yaml
│   └── metallb-values.yaml      # MetalLB параметры (с пулом адресов!)
├── components/                   # Legacy директорию можно удалить
├── charts/                       # Локальные Helm чарты (синк из git.local.test)
├── projects/                     # ArgoCD Projects
├── secrets/                      # Документы по управлению секретами
├── images/                       # Скрипты импорта образов
└── docs/                         # Дополнительная документация
```

## Что изменилось

### До изменений
- Параметры были "зашиты" прямо в манифесты Application/ApplicationSet
- Для изменения версии или образа нужно было редактировать несколько файлов
- Высокий риск ошибок при обновлении параметров

### После изменений
✅ Все параметры вынесены в `values/*.yaml` файлы
✅ Единый источник истины для каждого компонента
✅ Легко изменять версии, образы, ресурсы, пулы адресов
✅ Поддержка глобальных настроек через `global-values.yaml`
✅ Полная совместимость с offline режимом

## Как использовать

### 1. Изменение версии компонента

Откройте соответствующий values файл и измените tag:

```yaml
# values/cert-manager-values.yaml
image:
  repository: harbor.local.test:8443/library/quay.io/jetstack/cert-manager-controller
  tag: v1.20.0  # Было v1.19.4
```

Также обновите версию чарта в ApplicationSet:

```yaml
# applications/components/infrastructure-components.yaml
- component: cert-manager
  chartVersion: "v1.20.0"  # Было v1.19.4
```

### 2. Изменение пула адресов MetalLB

```yaml
# values/metallb-values.yaml
ipAddressPools:
  - name: default-pool
    addresses:
      - "192.168.100.50-192.168.100.150"  # Новый диапазон
    autoAssign: true
```

### 3. Изменение registry для всех компонентов

Отредактируйте `global-values.yaml`:

```yaml
global:
  harborRegistry: "new-registry.local.test:5000"
  harborPathPrefix: "mirrors"
```

Затем обновите пути к образам в компонентных files или используйте шаблонизацию.

### 4. Добавление нового компонента

1. Создайте `values/new-component-values.yaml`
2. Добавьте элемент в список generators в `infrastructure-components.yaml`:

```yaml
- component: new-component
  chart: new-component-chart
  chartVersion: "1.0.0"
  valuesFile: "values/new-component-values.yaml"
  namespace: default
  repoURL: https://git.local.test/k8s/charts.git
  targetRevision: 1.0.0
  syncWave: "50"
  prune: "true"
```

3. Закоммитьте изменения в Git

## Порядок установки (Sync Waves)

| Wave | Компонент          | Критичность | Prune |
|------|--------------------|-------------|-------|
| -10  | Calico             | Критично    | ❌    |
| 0    | Cert-Manager       | Высокая     | ✅    |
| 10   | Istio              | Высокая     | ✅    |
| 20   | VictoriaMetrics    | Средняя     | ✅    |
| 21   | VMAgent            | Средняя     | ✅    |
| 22   | Grafana            | Низкая      | ✅    |
| 23   | VictoriaLogs       | Средняя     | ✅    |
| 24   | Node Exporter      | Низкая      | ✅    |
| 25   | Kube-State-Metrics | Низкая      | ✅    |
| 30   | OPA Gatekeeper     | Высокая     | ✅    |
| 40   | MetalLB            | Высокая     | ✅    |

## Offline режим

Все значения настроены для работы в полностью изолированном контуре:

### Registry
```yaml
harbor.local.test:8443/library/<original-image-path>
```

### Git Repository
```yaml
https://git.local.test/k8s/charts.git
```

### Image Pull Policy
```yaml
global:
  imagePullPolicy: IfNotPresent
```

## Примеры изменений

### Пример 1: Увеличение размера PVC для VictoriaMetrics

```yaml
# values/victoriametrics-values.yaml
server:
  persistentVolume:
    enabled: true
    size: 100Gi  # Было 50Gi
    storageClass: nfs-storage
```

### Пример 2: Изменение ресурсов Grafana

```yaml
# values/grafana-values.yaml
resources:
  requests:
    cpu: 200m      # Было 100m
    memory: 512Mi  # Было 256Mi
  limits:
    cpu: 1000m     # Было 500m
    memory: 2Gi    # Было 1Gi
```

### Пример 3: Включение BGP режима для MetalLB

```yaml
# values/metallb-values.yaml
mode: bgp  # Было layer2

bgpAdvertisement:
  enabled: true
  
bgpPeers:
  - myASN: 64512
    peerASN: 64513
    peerAddress: 192.168.100.1
```

### Пример 4: Добавление tolerations для работы на master нодах

```yaml
# values/node-exporter-values.yaml
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: dedicated
    operator: Equal
    value: monitoring
    effect: NoSchedule
```

## Безопасность

### ⚠️ НЕ храните секреты в values файлах!

Используйте внешние системы управления секретами:

```yaml
# values/grafana-values.yaml
# ПЛОХО:
adminPassword: "SuperSecret123"

# ХОРОШО:
adminPasswordSecret:
  name: grafana-admin-secret
  key: password
```

Интеграция с:
- Sealed Secrets
- External Secrets Operator
- HashiCorp Vault
- SOPS

## Версионирование и GitOps

1. Все values файлы находятся под версионным контролем Git
2. Изменения в values → commit → push → ArgoCD автоматически применяет
3. Возможность отката к предыдущей версии через `git revert`

### Workflow обновления

```bash
# 1. Клонируем репозиторий
git clone https://git.local.test/k8s/argocd-structure.git
cd argocd-structure

# 2. Редактируем values файл
vim values/victoriametrics-values.yaml

# 3. Проверяем изменения
git diff

# 4. Коммитим и пушим
git add values/victoriametrics-values.yaml
git commit -m "feat: увеличить PVC VictoriaMetrics до 100Gi"
git push

# 5. ArgoCD автоматически применит изменения через 3 минуты
```

## Troubleshooting

### Проблема: Компонент не устанавливается

**Решение:**
```bash
# Проверить статус Application
kubectl get application -n argocd <component-name>

# Посмотреть логи синхронизации
argocd app logs <component-name> -n argocd

# Проверить значения в values файле
cat values/<component>-values.yaml
```

### Проблема: Образы не pull'ятся

**Решение:**
1. Проверьте путь к образу в values файле
2. Убедитесь, что образ существует в Harbor:
   ```bash
   curl -k https://harbor.local.test:8443/api/v2.0/projects/library/repositories
   ```
3. Импортируйте образ если отсутствует:
   ```bash
   ./images/import-images.sh
   ```

### Проблема: Неправильный порядок установки

**Решение:**
Проверьте syncWave в `applications/components/infrastructure-components.yaml`.
Меньшие значения устанавливаются первыми.

## Миграция со старой структуры

Старые файлы в директории `components/` больше не используются ApplicationSet.
Рекомендуется:

1. Удалить старые `components/*/application.yaml` файлы
2. Оставить только `values/*.yaml` файлы
3. Обновить документацию

## Дополнительные ресурсы

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Proposal](https://github.com/argoproj/proposals/blob/master/applicationset.md)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
