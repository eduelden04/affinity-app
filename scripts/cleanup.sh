#!/bin/bash

# Affinity App - 리소스 정리 스크립트
# 배포된 리소스 그룹 삭제

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🗑️  Affinity App - 리소스 정리${NC}"

# 매개변수 확인
RESOURCE_GROUP=$1

if [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${YELLOW}사용법: $0 <리소스-그룹-이름>${NC}"
    echo ""
    echo -e "${BLUE}배포된 리소스 그룹 목록:${NC}"
    az group list --query "[?starts_with(name, 'affinityapp-')].{Name:name, Location:location, Created:tags.\"created-by\"}" --output table
    exit 1
fi

# Azure CLI 로그인 확인
echo -e "${BLUE}🔐 Azure 인증 확인...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Azure에 로그인이 필요합니다.${NC}"
    az login
fi

# 리소스 그룹 존재 확인
echo -e "${BLUE}📋 리소스 그룹 확인...${NC}"
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${RED}❌ 리소스 그룹 '$RESOURCE_GROUP'를 찾을 수 없습니다.${NC}"
    exit 1
fi

# 리소스 그룹 내 리소스 목록 표시
echo -e "${BLUE}📦 삭제될 리소스 목록:${NC}"
az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type, Location:location}" --output table

echo ""
echo -e "${YELLOW}⚠️  리소스 그룹 '$RESOURCE_GROUP'와 모든 리소스를 삭제하시겠습니까?${NC}"
echo -e "${RED}    이 작업은 되돌릴 수 없습니다! (y/N)${NC}"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✅ 삭제가 취소되었습니다.${NC}"
    exit 0
fi

# 리소스 그룹 삭제
echo -e "${BLUE}🗑️  리소스 그룹 삭제 중...${NC}"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo -e "${GREEN}✅ 리소스 그룹 '$RESOURCE_GROUP' 삭제 요청이 전송되었습니다.${NC}"
echo -e "${YELLOW}📝 백그라운드에서 삭제가 진행됩니다. 완료까지 몇 분이 소요될 수 있습니다.${NC}"

# 삭제 상태 확인 옵션
echo ""
echo -e "${BLUE}삭제 상태 확인: az group show --name '$RESOURCE_GROUP'${NC}"
echo -e "${BLUE}모든 리소스 그룹 목록: az group list --query \"[?starts_with(name, 'affinityapp-')].name\" --output table${NC}"