#!/bin/bash

# Affinity App 개발 환경 정리 스크립트

# 색깔 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo -e "${YELLOW}"
echo "=================================================="
echo "🧹 Affinity App 개발 환경 정리"
echo "=================================================="
echo -e "${NC}"

cd "$(dirname "$0")"

# 실행 중인 서버 종료
print_step "실행 중인 서버 종료 중..."
if [ -f backend.pid ]; then
    kill $(cat backend.pid) 2>/dev/null || true
    rm -f backend.pid
    print_success "백엔드 서버 종료됨"
fi

if [ -f frontend.pid ]; then
    kill $(cat frontend.pid) 2>/dev/null || true
    rm -f frontend.pid
    print_success "프론트엔드 서버 종료됨"
fi

# 로그 파일 정리
print_step "로그 파일 정리 중..."
rm -f backend.log frontend.log
print_success "로그 파일 정리 완료"

# 포트 확인 및 종료
print_step "포트 8000, 5173 확인 중..."
for port in 8000 5173; do
    PID=$(lsof -ti:$port 2>/dev/null)
    if [ ! -z "$PID" ]; then
        kill -9 $PID 2>/dev/null || true
        print_success "포트 $port 해제됨"
    fi
done

print_success "정리 작업 완료!"
echo ""