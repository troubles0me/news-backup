#!/bin/bash

echo "🧪 빠른 백엔드 테스트 시작..."

cd final.back/backend

# Python 의존성 설치
echo "📦 Python 패키지 설치 중..."
pip3 install fastapi uvicorn requests beautifulsoup4 python-dotenv openai

# 환경 변수 파일 생성 (테스트용)
if [ ! -f .env ]; then
    echo "⚠️  .env 파일 생성 (테스트용)"
    echo "OPENAI_API_KEY=test_key_for_testing" > .env
fi

# 포트 8000 확인 및 정리
echo "🔌 포트 8000 정리 중..."
sudo pkill -f "uvicorn.*8000" 2>/dev/null
sleep 2

# 백엔드 서버 시작
echo "🚀 백엔드 서버 시작 (포트 8000)"
echo "📝 로그는 backend_test.log에 저장됩니다"
echo "🛑 중지하려면 Ctrl+C를 누르세요"
echo ""

uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload
