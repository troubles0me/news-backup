#!/bin/bash

echo "🐍 Python 환경 완전 설정 스크립트"
echo "================================="

# 시스템 업데이트
echo "📦 시스템 패키지 업데이트 중..."
sudo apt update

# Python 및 관련 패키지 설치
echo "🐍 Python3 및 pip3 설치 중..."
sudo apt install -y python3 python3-pip python3-venv python3-dev

# 추가 필수 패키지 설치
echo "🔧 추가 필수 패키지 설치 중..."
sudo apt install -y build-essential curl wget git net-tools

# Python과 pip 경로 확인
echo ""
echo "📋 설치 확인:"
echo "Python3 경로: $(which python3)"
echo "pip3 경로: $(which pip3)"
echo "Python3 버전: $(python3 --version)"
echo "pip3 버전: $(pip3 --version)"

# PATH 확인
echo ""
echo "현재 PATH:"
echo $PATH

echo ""
echo "✅ Python 환경 설정 완료!"
echo "이제 bash start_server.sh를 실행하세요."
