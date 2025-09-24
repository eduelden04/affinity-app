# Affinity App - Azure Container Apps 배포 스크립트 (PowerShell)
# 리소스 그룹 자동 생성 및 Container Apps 배포

param(
    [string]$ContainerImage = "ghcr.io/asomi7007/affinity-app:latest",
    [string]$Location = "koreasouth"
)

# 오류 발생 시 스크립트 중단
$ErrorActionPreference = "Stop"

# 색상 함수
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green" 
        "Yellow" = "Yellow"
        "Blue" = "Cyan"
        "White" = "White"
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

Write-ColorOutput "🚀 Affinity App - Azure Container Apps 배포 시작" "Blue"

# 현재 날짜 및 랜덤 문자열 생성
$Date = Get-Date -Format "yyyyMMdd"
$RandomBytes = New-Object byte[] 2
$Random = New-Object System.Random
$Random.NextBytes($RandomBytes)
$RandomSuffix = [System.BitConverter]::ToString($RandomBytes).Replace("-", "").ToLower()
$ResourceGroup = "affinityapp-$Date-$RandomSuffix"

Write-ColorOutput "📋 배포 설정:" "Yellow"
Write-Host "  - 리소스 그룹: $ResourceGroup"
Write-Host "  - 위치: $Location"
Write-Host "  - 컨테이너 이미지: $ContainerImage"
Write-Host ""

# Azure CLI 로그인 확인
Write-ColorOutput "🔐 Azure 인증 확인..." "Blue"
try {
    $null = az account show 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged in"
    }
} catch {
    Write-ColorOutput "Azure에 로그인이 필요합니다." "Yellow"
    az login
    if ($LASTEXITCODE -ne 0) {
        throw "Azure 로그인 실패"
    }
}

# 현재 구독 정보 표시
$SubscriptionName = az account show --query name --output tsv
Write-ColorOutput "✅ 현재 구독: $SubscriptionName" "Green"

# 리소스 그룹 생성
Write-ColorOutput "📦 리소스 그룹 생성..." "Blue"
az group create `
    --name $ResourceGroup `
    --location $Location `
    --tags "project=affinity-app" "environment=production" "created-by=deploy-script"

if ($LASTEXITCODE -ne 0) {
    throw "리소스 그룹 생성 실패"
}

Write-ColorOutput "✅ 리소스 그룹 '$ResourceGroup' 생성 완료" "Green"

# 배포 미리보기 (What-If)
Write-ColorOutput "🔍 배포 미리보기 실행..." "Blue"
az deployment group what-if `
    --resource-group $ResourceGroup `
    --template-file "infra/azure/main.bicep" `
    --parameters containerImage=$ContainerImage

if ($LASTEXITCODE -ne 0) {
    throw "배포 미리보기 실패"
}

# 사용자 확인
Write-ColorOutput "⚠️  위 변경사항으로 배포를 진행하시겠습니까? (y/N)" "Yellow"
$Confirm = Read-Host
if ($Confirm -notmatch "^[Yy]$") {
    Write-ColorOutput "❌ 배포가 취소되었습니다." "Red"
    exit 1
}

# Bicep 템플릿 배포
Write-ColorOutput "🚀 Container Apps 배포 중..." "Blue"
$DeploymentName = "affinity-app-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --template-file "infra/azure/main.bicep" `
    --parameters containerImage=$ContainerImage `
    --verbose

# 배포 결과 확인
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ 배포 완료!" "Green"
    
    # 애플리케이션 URL 조회
    $AppUrl = az deployment group show `
        --resource-group $ResourceGroup `
        --name $DeploymentName `
        --query properties.outputs.containerAppUrl.value `
        --output tsv
    
    $SubscriptionId = az account show --query id --output tsv
    
    Write-ColorOutput "🌐 애플리케이션 URL: $AppUrl" "Green"
    Write-ColorOutput "📊 Azure Portal에서 리소스 확인: https://portal.azure.com/#@/resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" "Green"
    
    # 배포 정보를 파일로 저장
    @"
배포 정보 - $(Get-Date)
========================
리소스 그룹: $ResourceGroup
배포 이름: $DeploymentName
애플리케이션 URL: $AppUrl
컨테이너 이미지: $ContainerImage
위치: $Location
"@ | Out-File -FilePath "deployment-info.txt" -Encoding UTF8
    
    Write-ColorOutput "📄 배포 정보가 deployment-info.txt에 저장되었습니다." "Blue"
    
} else {
    Write-ColorOutput "❌ 배포 실패" "Red"
    exit 1
}

Write-ColorOutput "🎉 배포 완료! 애플리케이션이 준비되었습니다." "Green"