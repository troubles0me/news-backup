#!/bin/bash

echo "🚀 뉴스 퀴즈 서버 시작 중..."

# 작업 디렉토리로 이동
cd "$(dirname "$0")"

# 프론트엔드 빌드
echo "📦 프론트엔드 빌드 중..."
cd final.front
npm install
npm run build
cd ..

# 백엔드 의존성 설치 및 실행
echo "🐍 백엔드 시작 중..."
cd final.back/backend
pip install fastapi uvicorn requests beautifulsoup4 python-dotenv openai

# 환경 변수 파일이 없다면 생성
if [ ! -f .env ]; then
    echo "⚠️  .env 파일이 없습니다. OpenAI API 키를 설정해주세요."
    echo "OPENAI_API_KEY=your_api_key_here" > .env
fi

# 백엔드 서버 시작 (백그라운드)
echo "🔥 백엔드 서버 시작 (포트 8000)"
uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload &

# nginx 설정 업데이트
echo "🌐 nginx 설정 업데이트 중..."
sudo cp ../final.front/mknewsquiz.conf /etc/nginx/sites-available/mknewsquiz
sudo ln -sf /etc/nginx/sites-available/mknewsquiz /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "✅ 서버 시작 완료!"
echo "🌍 프론트엔드: http://20.41.113.134"
echo "🔧 백엔드: http://20.41.113.134:8000"
echo "📚 API 문서: http://20.41.113.134:8000/docs"

# 실행 중인 프로세스 확인
echo "📊 실행 중인 프로세스:"
ps aux | grep -E "(uvicorn|nginx)" | grep -v grep
