#!/bin/bash

# Affinity App 실행 스크립트
# 백엔드와 프론트엔드를 동시에 실행합니다.

set -e  # 에러 발생시 스크립트 중단

# 색깔 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
print_step() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 타이틀 출력
echo -e "${GREEN}"
echo "=================================================="
echo "🚀 Affinity Diagram App 실행 스크립트"
echo "=================================================="
echo -e "${NC}"

# 프로젝트 루트 디렉토리로 이동
cd "$(dirname "$0")"

# 백엔드 의존성 확인 및 설치
print_step "백엔드 환경 설정 중..."
if [ ! -d "backend/venv" ]; then
    print_step "Python 가상환경 생성 중..."
    cd backend
    python3 -m venv venv
    cd ..
fi

print_step "Python 의존성 설치 중..."
cd backend
source venv/bin/activate
pip install -r requirements.txt > /dev/null 2>&1 || {
    print_warning "pip 설치 실패, --break-system-packages 옵션으로 재시도..."
    pip install -r requirements.txt --break-system-packages
}
cd ..

# 프론트엔드 의존성 확인 및 설치
print_step "프론트엔드 환경 설정 중..."
if [ ! -d "frontend/node_modules" ]; then
    print_step "Node.js 의존성 설치 중..."
    cd frontend
    npm install
    cd ..
else
    print_step "Node.js 의존성이 이미 설치되어 있습니다."
fi

# PID 파일 정리 함수
cleanup() {
    print_step "서버 종료 중..."
    if [ -f backend.pid ]; then
        kill $(cat backend.pid) 2>/dev/null || true
        rm -f backend.pid
    fi
    if [ -f frontend.pid ]; then
        kill $(cat frontend.pid) 2>/dev/null || true
        rm -f frontend.pid
    fi
    exit 0
}

# Ctrl+C 처리
trap cleanup SIGINT SIGTERM

print_success "환경 설정 완료!"
echo ""

# 백엔드 실행
print_step "FastAPI 백엔드 서버 시작 중... (포트 8000)"
cd backend
source venv/bin/activate
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > ../backend.log 2>&1 &
echo $! > ../backend.pid
cd ..

# 잠시 대기 (백엔드 시작 시간)
sleep 3

# 프론트엔드 실행
print_step "React 프론트엔드 서버 시작 중... (포트 5173)"
cd frontend
nohup npm run dev -- --host > ../frontend.log 2>&1 &
echo $! > ../frontend.pid
cd ..

# 잠시 대기 (프론트엔드 시작 시간)
sleep 5

print_success "모든 서버가 성공적으로 시작되었습니다!"
echo ""
echo -e "${GREEN}=================================================="
echo "📱 서비스 접속 정보"
echo "=================================================="
echo -e "🌐 프론트엔드: ${BLUE}http://localhost:5173${NC}"
echo -e "🔧 백엔드 API: ${BLUE}http://localhost:8000${NC}"
echo -e "📚 API 문서: ${BLUE}http://localhost:8000/docs${NC}"
echo -e "📡 WebSocket: ${BLUE}ws://localhost:8000/ws/board/{board_id}${NC}"
echo "=================================================="
echo -e "${NC}"

# 로그 표시 옵션
echo -e "${YELLOW}실시간 로그를 보려면:${NC}"
echo "  백엔드 로그: tail -f backend.log"
echo "  프론트엔드 로그: tail -f frontend.log"
echo ""
echo -e "${YELLOW}서버를 종료하려면 Ctrl+C를 누르세요.${NC}"
echo ""

# 서버 상태 확인
check_servers() {
    while true; do
        if ! kill -0 $(cat backend.pid 2>/dev/null) 2>/dev/null; then
            print_error "백엔드 서버가 종료되었습니다."
            cleanup
        fi
        if ! kill -0 $(cat frontend.pid 2>/dev/null) 2>/dev/null; then
            print_error "프론트엔드 서버가 종료되었습니다."
            cleanup
        fi
        sleep 5
    done
}

# 서버 상태 모니터링 시작
check_servers