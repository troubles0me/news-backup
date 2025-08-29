# 🚨 "Failed to fetch" 오류 해결 가이드

## 🔍 **문제 진단**

"Failed to fetch" 오류는 프론트엔드에서 백엔드 API에 접근할 수 없을 때 발생합니다.

## 🎯 **해결 방법**

### **1단계: 백엔드 서버 상태 확인**

```bash
# Azure VM에서 실행
ps aux | grep uvicorn
netstat -tlnp | grep :8000
```

**정상 상태**: uvicorn 프로세스가 실행 중이고 포트 8000이 LISTEN 상태

### **2단계: 백엔드 서버 실행**

```bash
cd final.back/backend

# 의존성 설치
pip3 install fastapi uvicorn requests beautifulsoup4 python-dotenv openai

# 서버 실행
uvicorn gptchatbot:app --host 0.0.0.0 --port 8000 --reload
```

**성공 시**: 터미널에 "Uvicorn running on http://0.0.0.0:8000" 메시지 표시

### **3단계: 백엔드 API 테스트**

```bash
# 테스트 스크립트 실행
python3 test_backend.py

# 또는 수동 테스트
curl http://localhost:8000/
curl http://localhost:8000/api/
```

### **4단계: 방화벽 설정 확인**

```bash
# Ubuntu 방화벽 상태 확인
sudo ufw status

# 포트 8000 열기 (필요시)
sudo ufw allow 8000
```

### **5단계: Azure VM 네트워크 보안 그룹 확인**

Azure Portal에서:
1. VM → 네트워킹 → 네트워크 보안 그룹
2. 인바운드 보안 규칙에 포트 8000 추가
3. 프로토콜: TCP, 포트: 8000, 소스: Any

## 🛠️ **자동화된 해결 스크립트**

### **빠른 백엔드 테스트**
```bash
chmod +x quick_test.sh
./quick_test.sh
```

### **전체 서버 설정**
```bash
chmod +x start_server.sh
./start_server.sh
```

## 🔧 **수동 문제 해결**

### **포트 충돌 해결**
```bash
# 포트 8000 사용 중인 프로세스 종료
sudo pkill -f "uvicorn.*8000"

# 또는 특정 포트 사용 중인 프로세스 확인
sudo lsof -i :8000
```

### **로그 확인**
```bash
# 백엔드 로그 확인
tail -f final.back/backend/backend.log

# nginx 로그 확인
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### **CORS 문제 해결**
```bash
# 백엔드 CORS 설정 확인
cat final.back/backend/gptchatbot.py | grep -A 10 "CORS"
```

## 📱 **프론트엔드에서 테스트**

브라우저 개발자 도구에서:
1. F12 → Console 탭
2. 다음 명령어 실행:
```javascript
fetch('http://20.41.113.134:8000/')
  .then(response => response.json())
  .then(data => console.log('성공:', data))
  .catch(error => console.error('오류:', error));
```

## 🚀 **성공 확인**

모든 단계가 성공하면:
- 백엔드: http://20.41.113.134:8000 ✅
- 프론트엔드: http://20.41.113.134 ✅
- API 문서: http://20.41.113.134:8000/docs ✅

## 📞 **추가 지원**

문제가 지속되면:
1. `test_backend.py` 실행 결과 공유
2. 백엔드 서버 실행 시 오류 메시지 공유
3. 브라우저 개발자 도구의 Network 탭 스크린샷 공유
