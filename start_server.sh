#!/bin/bash

echo "🚀 뉴스 퀴즈 서버 시작 중..."

# 작업 디렉토리로 이동
cd "$(dirname "$0")"

# 필요한 패키지 설치 확인
echo "📦 필요한 패키지 설치 확인 중..."

# Node.js 설치 확인
if ! command -v node &> /dev/null; then
    echo "⚠️  Node.js가 설치되지 않았습니다. 설치 중..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Python3 및 pip 설치 확인
echo "Python3 설치 상태 확인 중..."
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python3가 설치되지 않았습니다. 설치 중..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
else
    echo "✅ Python3가 이미 설치되어 있습니다."
fi

if ! command -v pip3 &> /dev/null; then
    echo "⚠️  pip3가 설치되지 않았습니다. 설치 중..."
    sudo apt update
    sudo apt install -y python3-pip
else
    echo "✅ pip3가 이미 설치되어 있습니다."
fi

# nginx 설치 확인
if ! command -v nginx &> /dev/null; then
    echo "⚠️  nginx가 설치되지 않았습니다. 설치 중..."
    sudo apt update
    sudo apt install -y nginx
fi

# 프론트엔드 빌드
echo "📦 프론트엔드 빌드 중..."
cd final.front

# Node.js 버전 확인
echo "Node.js 버전: $(node --version)"
echo "npm 버전: $(npm --version)"

# package-lock.json이 있으면 제거하고 깨끗하게 설치
if [ -f package-lock.json ]; then
    echo "기존 package-lock.json 제거 중..."
    rm package-lock.json
fi

if [ -d node_modules ]; then
    echo "기존 node_modules 제거 중..."
    rm -rf node_modules
fi

# 패키지 설치
echo "패키지 설치 중..."
npm install

# 빌드
echo "프론트엔드 빌드 시작..."
npm run build

cd ..

# 백엔드 의존성 설치 및 실행
echo "🐍 백엔드 시작 중..."
cd final.back/backend

# Python 버전 확인
echo "Python 버전: $(python3 --version)"
echo "pip 버전: $(python3 -m pip --version)"

# 가상환경 생성 및 활성화 (권한 문제 해결)
echo "🔄 Python 가상환경 설정 중..."
if [ -d "venv" ]; then
    echo "기존 가상환경 제거 중..."
    rm -rf venv
fi

echo "새로운 가상환경 생성 중..."
python3 -m venv venv

echo "가상환경 활성화 중..."
source venv/bin/activate

# 가상환경 활성화 확인
if [ "$VIRTUAL_ENV" ]; then
    echo "✅ 가상환경 활성화 성공: $VIRTUAL_ENV"
else
    echo "❌ 가상환경 활성화 실패"
    exit 1
fi

# pip 업그레이드
echo "pip 업그레이드 중..."
python -m pip install --upgrade pip

# Python 의존성 설치 (가상환경에서)
echo "Python 패키지 설치 중..."
echo "현재 Python 경로: $(which python)"
echo "현재 pip 경로: $(which pip)"

if [ -f requirements.txt ]; then
    echo "requirements.txt에서 패키지 설치 중..."
    python -m pip install -r requirements.txt
else
    echo "개별 패키지 설치 중..."
    python -m pip install fastapi "uvicorn[standard]" requests beautifulsoup4 python-dotenv openai
fi

# 설치된 패키지 확인
echo "설치된 패키지 확인:"
python -m pip list | grep -E "(fastapi|uvicorn|requests|beautifulsoup4|python-dotenv|openai)"

# uvicorn 설치 확인
echo "uvicorn 설치 확인:"
python -c "import uvicorn; print(f'uvicorn 버전: {uvicorn.__version__}')" || echo "❌ uvicorn 설치 실패"

# 환경 변수 파일이 없다면 생성
if [ ! -f .env ]; then
    echo "⚠️  .env 파일이 없습니다. OpenAI API 키를 설정해주세요."
    echo "OPENAI_API_KEY=your_api_key_here" > .env
fi

# 포트 8000이 사용 중인지 확인
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  포트 8000이 이미 사용 중입니다. 기존 프로세스를 종료합니다."
    sudo pkill -f "uvicorn.*8000"
    sleep 2
fi

# 백엔드 서버 시작 (백그라운드)
echo "🔥 백엔드 서버 시작 (포트 8000)"

# FastAPI 앱 존재 확인
if [ ! -f "gptchatbot.py" ]; then
    echo "❌ gptchatbot.py 파일을 찾을 수 없습니다!"
    exit 1
fi

# 가상환경이 여전히 활성화되어 있는지 확인
if [ ! "$VIRTUAL_ENV" ]; then
    echo "⚠️  가상환경이 비활성화되었습니다. 다시 활성화 중..."
    source venv/bin/activate
fi

# uvicorn 실행 시도 (여러 방법)
echo "uvicorn 실행 시도 중..."
echo "현재 Python 경로: $(which python)"

# 방법 1: python -m uvicorn (권장)
echo "방법 1: python -m uvicorn으로 실행 시도..."
if python -c "import uvicorn" &> /dev/null; then
    echo "✅ uvicorn 모듈 확인됨. 서버 시작 중..."
    
    # 기존 로그 파일 제거
    rm -f backend.log
    
    # 서버 시작 (가상환경 유지)
    nohup bash -c "
    source venv/bin/activate
    python -m uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload
    " > backend.log 2>&1 &
    
    BACKEND_PID=$!
    echo "백엔드 서버 PID: $BACKEND_PID"
else
    echo "❌ uvicorn 모듈을 찾을 수 없습니다!"
    echo "수동으로 uvicorn 재설치 시도..."
    python -m pip install uvicorn[standard] --force-reinstall
    
    # 재설치 후 다시 시도
    if python -c "import uvicorn" &> /dev/null; then
        echo "✅ uvicorn 재설치 성공. 서버 시작 중..."
        nohup bash -c "
        source venv/bin/activate
        python -m uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload
        " > backend.log 2>&1 &
        BACKEND_PID=$!
        echo "백엔드 서버 PID: $BACKEND_PID"
    else
        echo "❌ uvicorn 설치 실패. 서버 시작 불가능."
        exit 1
    fi
fi

# 서버 시작 대기
echo "⏳ 백엔드 서버 시작 대기 중..."
sleep 5

# 백엔드 서버 상태 확인
echo "🔍 백엔드 서버 상태 확인 중..."

# 서버 시작 시간을 더 많이 주기
sleep 3

# 여러 번 시도해서 서버 상태 확인
for i in {1..5}; do
    echo "시도 $i/5: 백엔드 서버 연결 확인..."
    if curl -s --connect-timeout 5 http://localhost:8000/ > /dev/null; then
        echo "✅ 백엔드 서버가 성공적으로 시작되었습니다!"
        echo "🌐 백엔드 API 테스트: http://20.196.66.12:8000"
        break
    else
        if [ $i -eq 5 ]; then
            echo "❌ 백엔드 서버 시작에 실패했습니다."
            echo ""
            echo "📋 디버깅 정보:"
            echo "1. 프로세스 상태:"
            ps aux | grep -E "(uvicorn|python.*gptchatbot)" | grep -v grep || echo "관련 프로세스를 찾을 수 없습니다."
            echo ""
            echo "2. 포트 8000 사용 상태:"
            lsof -i :8000 2>/dev/null || echo "포트 8000이 사용되지 않고 있습니다."
            echo ""
            echo "3. 최근 로그 (마지막 30줄):"
            if [ -f backend.log ]; then
                tail -n 30 backend.log
            else
                echo "backend.log 파일이 없습니다."
            fi
            echo ""
            echo "4. 가상환경 상태:"
            echo "VIRTUAL_ENV: $VIRTUAL_ENV"
            echo "Python 경로: $(which python)"
            echo ""
            echo "5. uvicorn 테스트:"
            python -c "import uvicorn; print('uvicorn 사용 가능')" 2>/dev/null || echo "uvicorn 사용 불가능"
        else
            echo "서버 시작 대기 중... (5초 후 재시도)"
            sleep 5
        fi
    fi
done

# nginx 설정 업데이트
echo "🌐 nginx 설정 업데이트 중..."
sudo cp ../../final.front/mknewsquiz.conf /etc/nginx/sites-available/mknewsquiz
sudo ln -sf /etc/nginx/sites-available/mknewsquiz /etc/nginx/sites-enabled/

# 기본 nginx 설정 비활성화
sudo rm -f /etc/nginx/sites-enabled/default

# nginx 설정 테스트 및 재시작
sudo nginx -t && sudo systemctl reload nginx

if [ $? -eq 0 ]; then
    echo "✅ nginx 설정이 성공적으로 적용되었습니다!"
else
    echo "❌ nginx 설정에 문제가 있습니다."
fi

echo ""
echo "🎉 서버 시작 완료!"
echo "🌍 프론트엔드: http://20.196.66.12"
echo "🔧 백엔드: http://20.196.66.12:8000"
echo "📚 API 문서: http://20.196.66.12:8000/docs"
echo "📊 백엔드 로그: tail -f final.back/backend/backend.log"

# 실행 중인 프로세스 확인
echo ""
echo "📊 실행 중인 프로세스:"
ps aux | grep -E "(uvicorn|nginx)" | grep -v grep

# 포트 사용 상태 확인
echo ""
echo "🔌 포트 사용 상태:"
if command -v netstat &> /dev/null; then
    sudo netstat -tlnp | grep -E ":80|:8000"
elif command -v ss &> /dev/null; then
    sudo ss -tlnp | grep -E ":80|:8000"
else
    echo "netstat/ss 명령어가 없습니다. net-tools 설치 중..."
    sudo apt update && sudo apt install -y net-tools
    sudo netstat -tlnp | grep -E ":80|:8000"
fi
