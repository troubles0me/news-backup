#!/usr/bin/env python3
"""
백엔드 API 테스트 스크립트
Azure VM에서 백엔드가 제대로 작동하는지 확인합니다.
"""

import requests
import json
import sys

def test_backend():
    base_url = "http://localhost:8000"
    
    print("🧪 백엔드 API 테스트 시작...")
    print(f"📍 테스트 대상: {base_url}")
    print("-" * 50)
    
    # 1. 루트 엔드포인트 테스트
    try:
        print("1️⃣ 루트 엔드포인트 테스트...")
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            print(f"✅ 성공: {response.json()}")
        else:
            print(f"❌ 실패: {response.status_code}")
    except Exception as e:
        print(f"❌ 오류: {e}")
    
    # 2. API 루트 테스트
    try:
        print("\n2️⃣ API 루트 테스트...")
        response = requests.get(f"{base_url}/api/")
        if response.status_code == 200:
            print(f"✅ 성공: {response.json()}")
        else:
            print(f"❌ 실패: {response.status_code}")
    except Exception as e:
        print(f"❌ 오류: {e}")
    
    # 3. 스크래핑 API 테스트
    try:
        print("\n3️⃣ 스크래핑 API 테스트...")
        test_url = "https://www.mk.co.kr/news/business/11403101"
        payload = {"url": test_url}
        response = requests.post(f"{base_url}/api/scrape", json=payload)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 성공: 제목 - {data.get('title', 'N/A')}")
            print(f"   내용 길이: {len(data.get('content', ''))} 문자")
        else:
            print(f"❌ 실패: {response.status_code}")
            print(f"   응답: {response.text}")
    except Exception as e:
        print(f"❌ 오류: {e}")
    
    # 4. 채팅 API 테스트
    try:
        print("\n4️⃣ 채팅 API 테스트...")
        payload = {
            "word": "테스트",
            "context": "이것은 테스트용 기사 내용입니다."
        }
        response = requests.post(f"{base_url}/api/chat", json=payload)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 성공: {data.get('answer', 'N/A')[:100]}...")
        else:
            print(f"❌ 실패: {response.status_code}")
            print(f"   응답: {response.text}")
    except Exception as e:
        print(f"❌ 오류: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 테스트 완료!")
    print("\n💡 문제 해결 방법:")
    print("1. 백엔드 서버가 실행 중인지 확인: ps aux | grep uvicorn")
    print("2. 포트 8000이 열려있는지 확인: netstat -tlnp | grep :8000")
    print("3. 방화벽 설정 확인: sudo ufw status")
    print("4. 백엔드 재시작: cd final.back/backend && uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload")

if __name__ == "__main__":
    test_backend()
