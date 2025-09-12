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
@description('컨테이너 이미지 (예: ghcr.io/owner/affinity-app:latest)')
param containerImage string
@description('컨테이너 포트 (프론트엔드 리버스프록시 포함 시 8000 또는 80)')
param containerPort int = 8000
@description('SKU (Basic B1, 무료 플랜은 Linux 컨테이너에 제한)')
param planSku string = 'B1'
@description('App Service 계획 용량 (기본 1)')
param planCapacity int = 1

var planName = '${projectName}-plan${nameSuffix}'
var webAppName = '${projectName}-app${nameSuffix}'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: planSku
    capacity: planCapacity
    tier: planSku == 'B1' ? 'Basic' : 'Standard'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImage}'
      appCommandLine: ''
      alwaysOn: true
      http20Enabled: true
      use32BitWorkerProcess: false
      applicationLogs: {
        fileSystem: {
          level: 'Information'
          retentionInMb: 35
          retentionInDays: 5
        }
      }
      containerRegistryUseManagedIdentity: true
      healthCheckPath: '/docs'
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: string(containerPort)
        }
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output webAppUrl string = 'https://${webAppName}.azurewebsites.net'
