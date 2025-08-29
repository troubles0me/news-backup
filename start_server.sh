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
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python3가 설치되지 않았습니다. 설치 중..."
    sudo apt update
    sudo apt install -y python3 python3-pip
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
echo "pip 버전: $(pip3 --version)"

# Python 의존성 설치 (사용자 모드로 설치)
echo "Python 패키지 설치 중..."
if [ -f requirements.txt ]; then
    pip3 install --user -r requirements.txt
else
    pip3 install --user fastapi uvicorn requests beautifulsoup4 python-dotenv openai
fi

# 설치된 패키지 확인
echo "설치된 패키지 확인:"
pip3 list | grep -E "(fastapi|uvicorn|requests|beautifulsoup4|python-dotenv|openai)"

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

# PATH에 사용자 패키지 경로 추가
export PATH="$HOME/.local/bin:$PATH"

# uvicorn 경로 확인
if ! command -v uvicorn &> /dev/null; then
    echo "⚠️  uvicorn을 찾을 수 없습니다. 다시 설치 중..."
    python3 -m pip install --user uvicorn
fi

# 백엔드 서버 시작
echo "uvicorn 경로: $(which uvicorn || echo 'uvicorn을 찾을 수 없음')"
nohup python3 -m uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload > backend.log 2>&1 &

# 서버 시작 대기
echo "⏳ 백엔드 서버 시작 대기 중..."
sleep 5

# 백엔드 서버 상태 확인
if curl -s http://localhost:8000/ > /dev/null; then
    echo "✅ 백엔드 서버가 성공적으로 시작되었습니다!"
else
    echo "❌ 백엔드 서버 시작에 실패했습니다. 로그를 확인해주세요."
    echo "로그 내용:"
    tail -n 20 backend.log
fi

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
sudo netstat -tlnp | grep -E ":80|:8000"
