@description('프로젝트 이름 (리소스 접두사)')
param projectName string = 'affinity'
@description('리소스 이름 뒤에 자동으로 붙는 4자리 랜덤(고정) suffix 사용 여부')
param enableRandomSuffix bool = true

// 동일 리포/다중 사용자 배포 시 이름 충돌 방지용.
// resourceGroup().id + projectName 기반 uniqueString 은 배포 위치에 따라 항상 같은 결과.
// 매 배포 마다 바뀌는 완전 랜덤 필요 시는 dateTime utcNow() 등을 seed 로 concat 하는 모듈을 추가해야 하지만
// 여기서는 재배포 시에도 동일 접두사가 유지되며 충돌만 피하는 deterministic unique 를 선택.
var rawSuffix = substring(uniqueString(resourceGroup().id, projectName), 0, 4)
var suffix = toLower(rawSuffix)
var nameSuffix = enableRandomSuffix ? '-${suffix}' : ''
@description('배포 위치')
param location string = resourceGroup().location
@description('컨테이너 이미지 (예: ghcr.io/asomi7007/affinity-app:latest) - 실제 배포 전 latest 이미지를 먼저 푸시해야 함')
param containerImage string = 'ghcr.io/asomi7007/affinity-app:latest'
@description('컨테이너 타겟 포트 (FastAPI 기본값: 8000)')
param targetPort int = 8000
@description('외부 노출 여부 (external 또는 internal)')
param ingress string = 'external'
@description('CPU 제한 (코어 단위, 기본 0.5)')
param cpu string = '0.5'
@description('메모리 제한 (Gi 단위, 기본 1.0)')
param memory string = '1.0Gi'
@description('최소 레플리카 수')
param minReplicas int = 0
@description('최대 레플리카 수')
param maxReplicas int = 5

var environmentName = '${projectName}-env${nameSuffix}'
var containerAppName = '${projectName}-app${nameSuffix}'
var logAnalyticsName = '${projectName}-logs${nameSuffix}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: ingress == 'external'
        targetPort: targetPort
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: containerImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            {
              name: 'PORT'
              value: string(targetPort)
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output environmentName string = environment.name
output containerAppName string = containerApp.name
