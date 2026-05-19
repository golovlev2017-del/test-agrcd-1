# Calico CNI Manifests для offline-режима
# 
# Этот файл содержит подготовленные манифесты Calico v3.30.7
# для использования в изолированном контуре без интернета.
#
# Инструкция по подготовке:
# 1. Скачать официальный calico.yaml:
#    curl -O https://docs.tigera.io/calico/latest/manifests/calico.yaml
# 2. Заменить все образы на локальные в harbor.local.test:8443
# 3. Проверить ключевые параметры:
#    - CALICO_IPV4POOL_IPIP: Never
#    - CALICO_IPV4POOL_VXLAN: CrossSubnet
#    - IP_AUTODETECTION_METHOD: interface=enp1s0
#    - FELIX_VXLANMTU: 1450
#    - Health probes: exec (не httpGet)
# 4. Поместить файл в этот каталог
#
# Для установки через ArgoCD создать Application с source.path, указывающим на этот файл
