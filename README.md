# K8S-infra
Проект для работы с кластерами Kubernetes, создания неймспейсов, квот, сетевых политик, сервисных аккаунтов, секретов к ним, а также деплоя инфраструктурных приложений.

# Настройка
1. Необходимо задать следующие переменные:
    - AWS_ACCESS_KEY_ID (от вашего s3 бакета, для хранения tfstate)
    - AWS_SECRET_ACCESS_KEY (от вашего s3 бакета, для хранения tfstate)
    - KUBE_HOST (url кластера кубера, например https://k3s.local:6443)
    - KUBE_TOKEN (токен от кластера кубера)
2. Настроить конфигурационные файлы:
    - backend.tf (в нем настраивается backend тераформа для хранения tfstate)
3. Скачать необходимые провайдеры terraform и положить их в директорию providers в соответствующие папки, необходимые версии указаны в txt файлах, для того что бы провайдеры каждый раз не качались из интернета. Если в этом нет необходимости то можно удалить файл .terraform.lock.hcl, директорию config/providers и внести изменения в .gitlab-ci.yml.

# Создание кастомный сервисных аккаунтов
Для создания сервисного аккаунта с гибкими правами нужно создать yaml файл в директории CUSTOM_PROJECTS\service_accounts, имя файла будет именем сервисного аккаунта. При добавление неймспейса в userEditServiceAccounts, создается roleBinding и привязывает аккаунт к ClusterRole edit для указанного неймспейса, для userViewServiceAccounts все полностью аналогично. 

_Пример YAML файла, для создания проекта:_
```
userEditServiceAccounts:
  namespaces:
  - testns-test
userViewServiceAccounts:
  namespaces:
  - testns-dev
  - testns-stage
```

# Создание неймспейсов
Для создания нового неймспейсаили нескольких, а вместе с ним сервисных аккаунтов и при необходимости resourcequota, limitrange, networkPolicy нужно создать yaml файлы (по аналогии с values.yaml в helm чартах) в одной или нескольких поддиректориях директории PROJECTS_CHARTS и название поддиректории будет постфиксом к имени неймспейса. 
Например, разработчикам для разработки и тестирования приложения нужны два неймспейса в окружениях test и dev, но что бы для деплоя использовался один токен, мы создаем два yaml файла в директориях PROJECTS_CHARTS/test и PROJECTS_CHARTS/dev с одинаковым названием, например testns.yaml, так же в нем можно указать разные квоты, сетевые политики доступа и тд. После этого создадутся два разных неймспейса testns-test и testns-dev, но с доступом по одному токену.
При необходимости, например для инфраструктурных проектов можно создать неймспейс без постфикса, для этого нужно создать yaml файл (по аналогии с values.yaml в helm чартах) в директории CUSTOM_PROJECTS/namespaces.

_Описание переменных для заполнения в yaml файле._

-  **namespace**: при необходимости неймспейс можно отключить, и он будет удален, если вместо enable поставить false. Так же это можно сделать, удалив yaml файл или сменив ему расширение на любое другое, например, txt.
-  **limitRange**: включение или отключения лимитов подов для создаваемого неймспейса (https://kubernetes.io/docs/concepts/policy/limit-range/)
-  **NetworkPolicies**: включение или отключения сетевых политик для создаваемого неймспейса (https://kubernetes.io/docs/concepts/services-networking/network-policies/)
-  **resourceQuota**: включение или отключения квот на ресурсы для создаваемого неймспейса (https://kubernetes.io/docs/concepts/policy/resource-quotas/)
-  **roleBinding**: включение или отключения привязки сервисного аккаунта к создаваемому неймспейсу .(https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

_Пример YAML файла, для создания проекта:_
```
limitRange: enable
namespace: enable
NetworkPolicies: enable
resourceQuota: enable
roleBinding: enable

resourcequota:
  cpu: '1.0'
  memory: 1Gi
  storage: 0Gi
  persistentvolumeclaims: '0'
  requests_ephemeral_storage: '0'
  services: '10'
  pods: '20'
  replicationcontrollers: '0'
  statefulsets_apps: '0'
  services_loadbalancers: '0'
  services_nodeports: '0'
  jobs: '30'
  cronjobs: '10'

limitrange:
  cpu:
    requests: 50m
    limit: 100m
  memory:
    requests: 64Mi
    limit: 128Mi

networkPolicy:
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
      to:
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
          namespaceSelector:
            matchLabels: {}
        - ipBlock:
            cidr: 10.43.0.10/32  # ip dns
    - ports:
        - port: 3128
          protocol: TCP
      to:
        - ipBlock:
            cidr: 192.168.1.204/32 #Proxy
    - ports:
        - port: 443
          protocol: TCP
        - port: 80
          protocol: TCP
      to:
        - ipBlock:
            cidr: 192.168.1.201/32 #harbor.local
        - ipBlock:
            cidr: 192.168.1.202/32 #vault.local
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              projectName: prometheus
          podSelector:
            matchLabels:
              app: prometheus
              component: server
```
# Деплой инфраструктурных приложений
Для деплоя инфраструктурных приложений в директории INFRA_RELEASES нужно создать yaml файл для его деплоя и половить например его helm chart или yaml файлы в отдельную созданную для него директорию в INFRA_RELEASES/projects. Примеры можно посмотреть в проекте в директории INFRA_RELEASES/projects.
Например, нужно задеплоить в кластер kubegraf, для этого создаем файл INFRA_RELEASES/kubegraf.tf
```
resource "k8s_manifest" "kubegraf-deploy" {
  for_each = fileset(path.module, "INFRA_RELEASES/projects/kubegraf/*.yaml")
  content  = file(each.value)
}
```
и далее создаем директорию INFRA_RELEASES/projects/kubegraf копируем в нее все необходимые файлы.
