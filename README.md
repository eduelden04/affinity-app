# Affinity Diagram Web App

FastAPI + React (Vite) 기반 실시간 어피니티 다이어그램 협업 도구 초기 스켈레톤.

## 🚀 GitHub Codespaces에서 시작하기

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/asomi7007/affinity-app)

**Codespaces에서 자동으로 설정됩니다:**
- Python 3.12 + Node.js 18
- 필요한 VS Code 확장 프로그램
- 백엔드/프론트엔드 의존성 자동 설치
- 포트 포워딩 (5173, 8000)

**Codespaces 실행 후:**
```bash
./start.sh  # 앱 실행
```

## 구조
```
affinity-app/
  backend/        # FastAPI, WebSocket
  frontend/       # React Vite TypeScript
  infra/azure/    # Azure 배포 문서
  .github/workflows/ci-cd.yml
```

## 로컬 실행

### 🚀 간편 실행 (권장)
```bash
# 한 번에 백엔드와 프론트엔드 모두 실행
./start.sh

# 서버 종료
./stop.sh
```

### 📋 실행 정보
- **프론트엔드**: http://localhost:5173
- **백엔드 API**: http://localhost:8000 (Swagger: /docs)
- **WebSocket**: ws://localhost:8000/ws/board/{board_id}

### 🔧 수동 실행 (개발용)
```bash
# Backend
cd backend
python3 -m venv venv  # 가상환경 생성 (최초 1회)
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Frontend (새 터미널)
cd frontend
npm install
npm run dev -- --host
```

### 외부 IP / 같은 네트워크 접속
개발 PC IP가 `192.168.x.x` 라면 다른 단말 브라우저에서:

1. 백엔드 실행 시 `--host 0.0.0.0` 지정
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
2. 프론트 실행(기본 Vite dev 서버 5173 포트 노출)
```bash
npm run dev -- --host
```
3. 다른 PC에서 접속
```
http://192.168.x.x:5173
```
자동으로 `http://192.168.x.x:8000` 을 API 베이스로 추론(포트 5173 → 8000 변환)합니다.

프록시/포트가 다르면 환경변수로 직접 지정:
```bash
# Windows PowerShell 예시
$env:VITE_API_BASE="http://192.168.x.x:9000"
npm run dev
```

### 환경 변수 정리
| 이름 | 용도 | 기본값 |
|------|------|--------|
| `VITE_API_BASE` | REST & WS 베이스 URL | `window.location.hostname` + 추론 포트(5173→8000) |

### 실시간 동기화 & 버전 정책(LWW)
- 서버는 보드별 인메모리 상태(`notes`, `gridMode`, `sectionTitles`, `version`) 유지
- 클라이언트 최초 연결 시 `sync.request` → 서버 `sync.state` 응답
- 변경 이벤트 발생 시 서버가 version 증가 후 `version` 필드 포함 브로드캐스트
- 클라이언트는 수신 이벤트 `version <= localVersion` 이면 무시 (LWW: Last Writer Wins)
- 충돌 가능성 낮은 단순 편집 모델 (동일 노트 동시 편집 시 마지막 수신이 승리)

향후 개선 아이디어:
- 부분 필드 CRDT(Text) 적용
- Optimistic Lock (클라이언트가 보낸 baseVersion 불일치 시 재동기화)
- Redis Pub/Sub or Azure Web PubSub 확장


## GitHub Actions
- 테스트, 프론트 빌드, 컨테이너 이미지(GHCR) 빌드 & 푸시
- Azure 배포 스텁 (Secrets 필요)

## Azure Container Apps로 배포하기

이 프로젝트는 FastAPI(백엔드)와 React(Vite, 프론트엔드)가 통합된 컨테이너 이미지를 Azure Container Apps에 배포하는 구조입니다.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fasomi7007%2Faffinity-app%2Fmain%2Finfra%2Fazure%2Fmain.json)

> 중요: 위 버튼은 `infra/azure/main.json` (Bicep 컴파일 결과) 파일이 repo main 브랜치에 존재해야 정상 동작합니다. Container Apps 리소스를 생성합니다.

### 리소스 이름 충돌 방지 (랜덤 suffix)
동일한 `projectName` 으로 여러 사람이 같은 구독/리소스그룹에 배포할 경우 이름 충돌을 막기 위해 기본적으로 `-xxxx` 형태(4글자 소문자 hex)의 suffix 가 자동 부여됩니다. (예: `affinity-app-ab12`)

- Bicep 파라미터 `enableRandomSuffix` = true (기본) 시 적용
- suffix 는 `uniqueString(resourceGroup().id, projectName)` 기반 deterministic 값 → 같은 RG/같은 projectName 재배포 시 동일 이름 유지
- 완전 재배포마다 다른 임의값(비결정) 원하면 추가 모듈/utcNow() seed 로직 필요 (현재 템플릿은 안정적 재배포 우선)

### 1) 컨테이너 이미지 빌드 및 푸시
GitHub Actions 또는 로컬에서 이미지 빌드 및 푸시:
```bash
docker build -t ghcr.io/asomi7007/affinity-app:latest .
echo $CR_PAT | docker login ghcr.io -u asomi7007 --password-stdin
docker push ghcr.io/asomi7007/affinity-app:latest
```
- GHCR(Public/Private) 사용 시 권한 설정을 확인하세요.

### 2) Bicep → ARM 템플릿 변환 (CI 또는 수동)
Azure 포털 Deploy 버튼은 ARM(JSON) URL을 요구하므로 Bicep을 JSON으로 사전 변환해야 합니다:
```bash
az bicep build --file infra/azure/main.bicep --outdir infra/azure
```
생성된 `main.json` 을 main 브랜치에 커밋하세요.

### 3) 🚀 자동 배포 스크립트 (권장)

코드스페이스나 로컬 환경에서 한 번의 명령으로 리소스 그룹 생성부터 배포까지 자동화:

```bash
# 실행 권한 부여
chmod +x scripts/deploy.sh

# 기본 설정으로 배포 (이미지: ghcr.io/asomi7007/affinity-app:latest, 위치: koreasouth)  
./scripts/deploy.sh

# 사용자 정의 설정으로 배포
./scripts/deploy.sh "ghcr.io/asomi7007/affinity-app:v1.0" "koreacentral"
```

**PowerShell 사용 시:**
```powershell
# 기본 설정으로 배포
.\scripts\deploy.ps1

# 사용자 정의 설정으로 배포
.\scripts\deploy.ps1 -ContainerImage "ghcr.io/asomi7007/affinity-app:v1.0" -Location "koreacentral"
```

**배포 스크립트 특징:**
- 🎯 **자동 리소스 그룹 생성**: `affinityapp-YYYYMMDD-XXXX` 형식 (날짜 + 랜덤 4자리)
- 🔍 **배포 미리보기**: What-If 분석으로 변경사항 미리 확인
- 📊 **배포 정보 저장**: `deployment-info.txt`에 URL, 리소스 그룹 등 저장
- 🎨 **컬러 출력**: 진행 상황을 시각적으로 확인
- ⚡ **리소스 정리**: `./scripts/cleanup.sh <리소스그룹명>` 으로 간편 삭제

### 4) Azure CLI로 수동 배포 (고급 사용자)
```bash
# 리소스 그룹 생성
az group create --name affinity-app-rg --location koreasouth

# 배포 미리보기
az deployment group what-if \
  --resource-group affinity-app-rg \
  --template-file infra/azure/main.bicep \
  --parameters containerImage=ghcr.io/asomi7007/affinity-app:latest

# Container Apps 배포
az deployment group create \
  --resource-group affinity-app-rg \
  --template-file infra/azure/main.bicep \
  --parameters containerImage=ghcr.io/asomi7007/affinity-app:latest
```

### 4) 포털 배포 시 파라미터
| 파라미터 | 설명 | 예시 |
|----------|------|------|
| projectName | 리소스 접두사 | affinity | 
| location | 배포 지역 | koreacentral |
| containerImage | 풀 이미지 경로 | ghcr.io/asomi7007/affinity-app:latest |
| targetPort | 컨테이너 노출 포트 | 8000 (FastAPI) |
| ingress | 외부 노출 여부 | external |

### 5) GitHub Actions로 자동 배포 (선택)

`.github/workflows/` 에 아래 스니펫을 추가하면 main push 시 Container Apps 자동 배포 가능.

```yaml
name: deploy-container-apps
on:
  push:
    branches: [ main ]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: Deploy to Container Apps
        run: |
          az containerapp update \
            --name ${{ secrets.CONTAINER_APP_NAME }} \
            --resource-group ${{ secrets.AZURE_RG }} \
            --image ${{ secrets.CONTAINER_IMAGE }} \
            --target-port 8000 \
            --ingress external
```

필요 Secrets

| 이름 | 설명 |
|------|------|
| `AZURE_CLIENT_ID` | Federated Credential이 연결된 App Registration 클라이언트 ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | 구독 ID |
| `AZURE_RG` | 리소스 그룹 이름 |
| `CONTAINER_IMAGE` | 배포할 컨테이너 이미지 (예: ghcr.io/asomi7007/affinity-app:latest) |
| `CONTAINER_APP_NAME` | Container App 리소스 이름 |

### 6) 환경 변수 및 포트 설정

- FastAPI는 기본적으로 8000 포트에서 실행되어야 하며, `targetPort`와 일치해야 합니다.
- 환경 변수는 `--env-vars` 옵션 또는 Bicep 템플릿에서 지정합니다.

### 7) 배포 후 확인 및 커스텀 도메인

- 배포가 완료되면 Azure Portal 또는 CLI에서 Container Apps의 URL을 확인할 수 있습니다.
- 필요 시 [커스텀 도메인 및 SSL](https://learn.microsoft.com/ko-kr/azure/container-apps/custom-domains) 설정을 진행하세요.

> 참고: Bicep 템플릿의 `containerImage` 파라미터는 기본값(`ghcr.io/asomi7007/affinity-app:latest`)을 포함합니다. 다른 레지스트리를 사용하거나 버전 태그를 고정하려면 배포 화면에서 값만 교체하면 됩니다.

### 8) 문제 해결

| 증상 | 점검 항목 |
|------|-----------|
| 앱 502/기동 실패 | 컨테이너 로그: `az containerapp logs show --name <app> --resource-group <rg>` |
| 포트 바인딩 오류 | FastAPI 실행 포트와 `targetPort` 일치 여부 |
| 이미지 Pull 실패 | Managed Identity / GHCR public 여부 확인 |
| Health Check 실패 | `/docs` 정상 응답 여부 |

### 9) 리소스 정리

배포된 리소스를 정리하려면:

```bash
# 특정 리소스 그룹 삭제 (스크립트 사용 - 권장)
./scripts/cleanup.sh affinityapp-20240924-a1b2

# 배포된 모든 affinity 리소스 그룹 확인
az group list --query "[?starts_with(name, 'affinityapp-')].{Name:name, Location:location}" --output table

# 수동 삭제
az group delete --name <resource-group-name> --yes --no-wait
```

**PowerShell 사용 시:**
```powershell
# 리소스 그룹 목록 확인 후 삭제
az group list --query "[?starts_with(name, 'affinityapp-')].name" --output table
az group delete --name "affinityapp-20240924-a1b2" --yes --no-wait
```

### 참고 문서

- [Azure Container Apps 시작하기](https://learn.microsoft.com/ko-kr/azure/container-apps/get-started)
- [Container Apps Bicep 예제](https://learn.microsoft.com/ko-kr/azure/container-apps/bicep-deploy)
- [Container Apps 환경 변수 관리](https://learn.microsoft.com/ko-kr/azure/container-apps/environment-variables)
- [Container Apps 커스텀 도메인](https://learn.microsoft.com/ko-kr/azure/container-apps/custom-domains)

---


## 향후 로드맵
- 노트 이동 이벤트 서버 검증 및 타입 정의 강화
- Board 영속화 (PostgreSQL + SQLAlchemy/SQLModel)
- 인증 (JWT 또는 Azure AD)
- Web PubSub / Redis 확장
- 그룹화(Cluster) 알고리즘 및 색상 태그
- 보드 내 검색 / 필터

## Debug & 진단 도구
실시간 드래그 / 생성 문제를 빠르게 진단하기 위한 런타임 플래그와 패널을 제공합니다.

### 디버그 패널
프론트 우상단 `Debug ▼` 버튼을 클릭하면 패널이 열립니다.

토글 가능한 옵션:
- `DEBUG_CREATE`: 포스트잇 생성 시 콘솔에 좌표/DOM Rect 로그
- `DEBUG_DRAG`: 드래그 시작/라이브 전송/종료 요약 로그
- `DEBUG_DRAG_VERBOSE`: 매 pointermove 스냅 적용 후 좌표 상세 로그 (소음 多)

패널 하단에는 현재 드래그 전송 정책이 표시됩니다:
- Throttle 간격: 90ms (최근 좌표 큐 → note.move 브로드캐스트)
- 주기적 flush: 120ms (사용자 입력 적을 때 잔여 큐 비우기)
- pointerup 시 최종 flush 보장

### 콘솔 수동 설정
패널 외에도 브라우저 콘솔에서 직접 설정 가능:
```js
window.DEBUG_CREATE = true;      // 생성 로그
window.DEBUG_DRAG = true;        // 기본 드래그 라이프사이클 로그
window.DEBUG_DRAG_VERBOSE = true;// 상세 이동 로그 (성능 영향)
```
끄기:
```js
window.DEBUG_DRAG_VERBOSE = false;
```

### Hover Outline
포스트잇 위에 포인터가 올라가면 파란 outline 이 나타나 타깃이 명확히 식별됩니다 (드래그 중 제외). 이는 포인터 이벤트 버블/레이어 문제로 인해 클릭 대상이 어긋나는지 확인할 때 유용합니다.

### 드래그 실시간 전송
기존: pointerup 시 단발 전송 → 개선: 이동 중 주기적(note.move) 실시간 공유. 느린 네트워크에서도 최종 위치는 pointerup flush 로 정확히 동기화됩니다.

### 문제 재현 팁
1. Debug Panel 열기 → DRAG / DRAG_VERBOSE 활성
2. 포스트잇 여러 개 생성 후 겹치거나 근접 배치
3. 드래그하여 자석(snap) 정렬 동작과 전송 로그 타이밍 비교
4. 다른 브라우저(또는 시크릿 창)에서 동일한 보드 관찰

### 추가 예정
- 드래그 경로 히트맵 시각화 옵션
- Latency 측정(ping) 및 평균 전송량 표시
- 서버 authoritative 이동 거부 시(향후) 경고 배지

## 라이선스
- 추후 결정
