# GPT-Researcher Custom Docker Image

공식 [GPT-Researcher](https://github.com/assafelovic/gpt-researcher) GitHub Container Registry 이미지를 기반으로 누락된 패키지를 추가한 커스텀 빌드입니다.

## 기반 이미지

- **Base**: `ghcr.io/assafelovic/gpt-researcher:latest`
- **Frontend**: `ghcr.io/assafelovic/gpt-researcher-frontend-nextjs:latest`

## 추가된 패키지

공식 `requirements.txt`에 포함되어 있으나 Docker 이미지에서 누락된 패키지들:

- `duckduckgo-search>=4.1.1` - 웹 검색 (DuckDuckGo)
- `firecrawl-py>=0.2.0` - 웹 스크래핑 (Firecrawl API)

## 이미지 태그

- `ghcr.io/unchartedsky/gpt-researcher:latest` - 최신 빌드 (main 브랜치)
- `ghcr.io/unchartedsky/gpt-researcher:weekly-YYYYMMDD` - 주간 자동 빌드
- `ghcr.io/unchartedsky/gpt-researcher:sha-{commit}` - 커밋별 빌드

## 사용법

### Docker

```bash
docker pull ghcr.io/unchartedsky/gpt-researcher:latest

docker run -d --name gpt-researcher \
  -e OPENAI_API_KEY=your_key_here \
  -e TAVILY_API_KEY=your_tavily_key \
  -p 8000:8000 \
  ghcr.io/unchartedsky/gpt-researcher:latest
```

### Kubernetes (Citadel)

Citadel 배포에서 이미지 참조를 업데이트하세요:

```yaml
# gpt-researcher.yaml (line 179)
image: ghcr.io/unchartedsky/gpt-researcher:latest

# gpt-researcher-mcp.yaml (line 70)
image: ghcr.io/unchartedsky/gpt-researcher:latest
```

## 로컬 빌드

```bash
cd gpt-researcher
chmod +x build.sh
./build.sh
```

## 확인

패키지 설치 확인:

```bash
# duckduckgo-search
docker run --rm ghcr.io/unchartedsky/gpt-researcher:latest \
  python -c "import duckduckgo_search; print('✓ duckduckgo-search installed')"

# firecrawl
docker run --rm ghcr.io/unchartedsky/gpt-researcher:latest \
  python -c "import firecrawl; print('✓ firecrawl installed')"

# 전체 확인
docker run --rm ghcr.io/unchartedsky/gpt-researcher:latest \
  python -c "import duckduckgo_search, firecrawl, tavily; print('✓ All packages OK!')"
```

## 자동화

- **주간 빌드**: 매주 일요일 오전 2시 (UTC)에 최신 공식 이미지로 재빌드
- **Push 트리거**: `gpt-researcher/` 디렉토리 변경 시 자동 빌드
- **수동 빌드**: GitHub Actions 탭에서 workflow_dispatch로 수동 실행

## 참고

- **GPT-Researcher 공식**: https://github.com/assafelovic/gpt-researcher
- **공식 GHCR**: https://github.com/assafelovic/gpt-researcher/pkgs/container/gpt-researcher
- **빌드 패턴 참고**: tedicross, wordpress 빌드 시스템 따름
