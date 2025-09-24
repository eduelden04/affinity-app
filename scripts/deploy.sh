#!/bin/bash

# Affinity App - Azure Container Apps 배포 스크립트
# 리소스 그룹 자동 생성 및 Container Apps 배포

set -e  # 오류 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Affinity App - Azure Container Apps 배포 시작${NC}"

# 매개변수 확인
CONTAINER_IMAGE=${1:-"ghcr.io/asomi7007/affinity-app:latest"}
LOCATION=${2:-"koreasouth"}

# 현재 날짜 및 랜덤 문자열 생성
DATE=$(date +"%Y%m%d")
RANDOM_SUFFIX=$(openssl rand -hex 2)  # 4자리 hex 문자열
RESOURCE_GROUP="affinityapp-${DATE}-${RANDOM_SUFFIX}"

echo -e "${YELLOW}📋 배포 설정:${NC}"
echo "  - 리소스 그룹: ${RESOURCE_GROUP}"
echo "  - 위치: ${LOCATION}"
echo "  - 컨테이너 이미지: ${CONTAINER_IMAGE}"
echo ""

# Azure CLI 로그인 확인
echo -e "${BLUE}🔐 Azure 인증 확인...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Azure에 로그인이 필요합니다.${NC}"
    az login
fi

# 현재 구독 정보 표시
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)
echo -e "${GREEN}✅ 현재 구독: ${SUBSCRIPTION_NAME}${NC}"

# 리소스 그룹 생성
echo -e "${BLUE}📦 리소스 그룹 생성...${NC}"
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --tags "project=affinity-app" "environment=production" "created-by=deploy-script"

echo -e "${GREEN}✅ 리소스 그룹 '${RESOURCE_GROUP}' 생성 완료${NC}"

# 배포 미리보기 (What-If)
echo -e "${BLUE}🔍 배포 미리보기 실행...${NC}"
az deployment group what-if \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "infra/azure/main.bicep" \
    --parameters containerImage="${CONTAINER_IMAGE}"

# 사용자 확인
echo -e "${YELLOW}⚠️  위 변경사항으로 배포를 진행하시겠습니까? (y/N)${NC}"
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ 배포가 취소되었습니다.${NC}"
    exit 1
fi

# Bicep 템플릿 배포
echo -e "${BLUE}🚀 Container Apps 배포 중...${NC}"
DEPLOYMENT_NAME="affinity-app-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${DEPLOYMENT_NAME}" \
    --template-file "infra/azure/main.bicep" \
    --parameters containerImage="${CONTAINER_IMAGE}" \
    --verbose

# 배포 결과 확인
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 배포 완료!${NC}"
    
    # 애플리케이션 URL 조회
    APP_URL=$(az deployment group show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${DEPLOYMENT_NAME}" \
        --query properties.outputs.containerAppUrl.value \
        --output tsv)
    
    echo -e "${GREEN}🌐 애플리케이션 URL: ${APP_URL}${NC}"
    echo -e "${GREEN}📊 Azure Portal에서 리소스 확인: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id --output tsv)/resourceGroups/${RESOURCE_GROUP}${NC}"
    
    # 배포 정보를 파일로 저장
    cat > deployment-info.txt << EOF
배포 정보 - $(date)
========================
리소스 그룹: ${RESOURCE_GROUP}
배포 이름: ${DEPLOYMENT_NAME}
애플리케이션 URL: ${APP_URL}
컨테이너 이미지: ${CONTAINER_IMAGE}
위치: ${LOCATION}
EOF
    
    echo -e "${BLUE}📄 배포 정보가 deployment-info.txt에 저장되었습니다.${NC}"
    
else
    echo -e "${RED}❌ 배포 실패${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 배포 완료! 애플리케이션이 준비되었습니다.${NC}"