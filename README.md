# Taiwan Judgment Crawler

司法院 공개 판결문을 JSONL로 수집하는 독립 CLI. Windows에서 `run.bat` 더블클릭 한 번이면 Python 설치부터 크롤링까지 자동 수행합니다.

## 실행 (Windows)

1. `run.bat` 더블클릭
   - Python이 없으면 UAC 창에서 "예" 클릭 → `winget`으로 자동 설치
   - 최초 실행 시 의존성 + Chromium 다운로드 약 10분 소요 (약 200 MB)
   - "Pages per keyword?" 프롬프트에 숫자 입력 (기본 3)
2. 완료 후 `output\crawled.jsonl`에 결과 누적

재실행 시에는 의존성 설치를 건너뛰어 바로 크롤이 시작됩니다.

## 수집 키워드 변경

`keywords.txt`를 메모장으로 열고 한 줄에 하나씩 추가/수정. `#`로 시작하는 줄은 주석으로 무시됩니다.

기본 4개 키워드 (원래 PRD 기준):

```
詐欺
幫助詐欺
洗錢
人頭帳戶
```

## 출력 형식

`output/crawled.jsonl` — 한 줄에 하나의 JSON 객체:

| 필드 | 설명 |
|---|---|
| `case_id` | 사건 번호 (예: `臺灣高等法院111年度上易字第123號`) |
| `source_url` | 사법원 원문 상세 페이지 URL |
| `court_level` | `最高法院` / `高等法院` / `地方法院` / `未知` |
| `raw_text` | 판결문 본문 평문 (개행 유지) |

**재실행 시 append**됩니다. 새로 시작하려면 `output\crawled.jsonl`을 삭제하세요. 중복 감지는 하지 않습니다.

## 수동 실행 (macOS / Linux 또는 파워 유저)

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium

# 단일 키워드
python crawl_judgments.py --keyword 詐欺 --max-pages 3

# 파일 기반 일괄 수집
python crawl_judgments.py --keywords-file keywords.txt --max-pages 3

# 디버깅 (브라우저 창 표시)
python crawl_judgments.py --keyword 詐欺 --max-pages 1 --no-headless
```

## 예의와 법적 고지

- 사법원 공식 공개 판결 페이지에서 수집하며, 로그인/CAPTCHA가 없습니다.
- 요청 간 3–5초 무작위 간격으로 서버 부하를 최소화합니다.
- User-Agent에 연락처를 명시하고 `robots.txt`를 존중합니다.
- 수집한 판결문은 공개 자료이나, 재배포 또는 영리적 이용 전 사법원 이용 약관과 관련 법규를 확인하세요.

## 이 프로젝트가 아닌 것

- **Gemini 구조화 안 함** — raw_text를 그대로 저장. 구조화·요약은 후속 단계에서 별도 도구로 처리.
- **RAG 검색 안 함** — 이 도구는 데이터 수집 전용.
- **Docker 안 씀** — Python + venv만.
