# maekyung_scraper.py

import requests
from bs4 import BeautifulSoup

def scrape_maekyung_article(url):
    """
    매일경제 기사 URL을 입력받아 제목과 본문을 추출하는 함수
    
    Args:
        url (str): 매일경제 기사의 전체 URL
    
    Returns:
        dict: {'title', 'content'} 형태의 딕셔너리, 실패 시 None
    """
    
    # 1. 로봇으로 인식되지 않도록 헤더 설정
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        # 2. URL에 접속해 HTML 코드 가져오기
        response = requests.get(url, headers=headers)
        response.raise_for_status() # 요청 실패 시 에러 발생

        # 요청코드 출력 
        print(f"HTTP 요청 상태 코드: {response.status_code}")

        # 3. BeautifulSoup으로 HTML 코드 분석 준비
        soup = BeautifulSoup(response.text, 'html.parser')

        # 4. '보물지도'(CSS 선택자)로 원하는 정보 찾기
        #    - 제목: h1 태그의 top_title 클래스
        #    - 본문: div 태그의 view_content_new 클래스
        title_tag = soup.select_one('h2.news_ttl')

        # 타이틀 출력
        # print(f"기사 제목: {title_tag.get_text(strip=True) if title_tag else '제목 없음'}")
        content_div = soup.select_one('div.news_cnt_detail_wrap[itemprop="articleBody"]')
        
        if content_div and title_tag:
            # 4-1. 불필요한 내용(광고, 기자 정보 등) 제거
            #      본문 내용 중 'div.figure' (이미지 설명), 'div.related_news' 등은 제외
            for tag in content_div.select('div.figure, div.related_news, span.read_more'):
                tag.decompose() # 해당 태그를 제거

            # 4-2. 제목과 본문 텍스트 추출
            title = title_tag.get_text(strip=True)
            content = content_div.get_text(separator='\n', strip=True)
            
            # 5. 추출한 정보를 딕셔너리로 묶어서 반환
            return {
                'title': title,
                'content': content
            }
        else:
            print("기사 제목이나 본문 영역을 찾지 못했습니다. 사이트 구조가 변경되었을 수 있습니다.")
            return None

    except requests.exceptions.RequestException as e:
        print(f"웹사이트에 접속하는 중 에러가 발생했습니다: {e}")
        return None

# 이 스크립트 파일을 직접 실행했을 때만 아래 코드가 동작함
if __name__ == "__main__":
    
    # 여기에 분석하고 싶은 매일경제 기사의 URL을 입력하세요.
    sample_url = "https://www.mk.co.kr/news/business/11403101"

    print(f"'{sample_url}' 주소의 기사 본문을 가져옵니다...")
    print("-" * 30)

    article = scrape_maekyung_article(sample_url)
    
    if article:
        print("[제목]:", article['title'])
        print("-" * 30)
        print("[본문]:\n", article['content'])
    else:
        print("\n[실패] 기사 내용을 가져오지 못했습니다.")