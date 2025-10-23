# WordPress 공식 이미지 빌드 및 테스트 가이드

**작성일**: 2025-10-04
**목적**: 마이그레이션된 WordPress 이미지 빌드 및 검증

---

## 📋 사전 준비

### 필수 도구
- Docker Desktop 또는 Docker Engine
- docker-compose (선택사항)
- kubectl (K8s 배포 시)

### 파일 확인
```bash
cd /Users/keaton/Workspace/Personal/dockers/wordpress

# 필수 파일 목록
ls -la
# - Dockerfile.template
# - docker-entrypoint-custom.sh
# - newrelic.ini
# - prepare.sh (템플릿 컴파일용)
```

---

## 🔨 Step 1: Dockerfile 생성

### 1.1 템플릿 컴파일 (있는 경우)
```bash
# prepare.sh가 있다면 사용
./prepare.sh

# 또는 수동으로 template에서 Dockerfile 생성
# {{.WORDPRESS_VERSION | default "php8.2-apache"}} → php8.2-apache로 치환
```

### 1.2 직접 Dockerfile 생성 (간단한 방법)
```bash
# Dockerfile.template의 변수를 치환하여 Dockerfile 생성
sed 's/{{.WORDPRESS_VERSION | default "php8.2-apache"}}/php8.2-apache/' Dockerfile.template > Dockerfile

# 확인
head -5 Dockerfile
# FROM wordpress:php8.2-apache 가 나와야 함
```

---

## 🏗️ Step 2: 로컬 이미지 빌드

### 2.1 기본 빌드
```bash
cd /Users/keaton/Workspace/Personal/dockers/wordpress

docker build -t wordpress-official:test .
```

**예상 빌드 시간**: 5-10분 (네트워크 속도에 따라)

### 2.2 빌드 중 확인사항
- [ ] Base image pull 성공 (wordpress:php8.2-apache)
- [ ] 패키지 설치 완료
- [ ] PHP 확장 설치 (Redis)
- [ ] NewRelic 설치 완료
- [ ] Composer 및 WordPress Feature API 플러그인 설치
- [ ] Apache 포트 설정 (8080, 8443)
- [ ] 커스텀 entrypoint 복사

### 2.3 빌드 오류 발생 시
```bash
# 캐시 없이 재빌드
docker build --no-cache -t wordpress-official:test .

# 특정 단계까지만 빌드하여 디버깅
docker build --target <단계> -t wordpress-debug .
```

---

## 🧪 Step 3: 로컬 테스트

### 3.1 데이터베이스 준비

**옵션 A: Docker로 MariaDB 실행**
```bash
docker run -d \
  --name wordpress-test-db \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wpuser \
  -e MYSQL_PASSWORD=wppass \
  -p 3306:3306 \
  mariadb:latest
```

**옵션 B: docker-compose 사용**
```yaml
# test-docker-compose.yml
version: '3.8'
services:
  db:
    image: mariadb:latest
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: wppass
    ports:
      - "3306:3306"

  wordpress:
    image: wordpress-official:test
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: wppass
      WORDPRESS_TABLE_PREFIX: wp_
      WORDPRESS_DEBUG: "1"
    ports:
      - "8080:8080"
      - "8443:8443"
    depends_on:
      - db
```

```bash
docker-compose -f test-docker-compose.yml up
```

### 3.2 WordPress 컨테이너 실행 (단독)

```bash
# MariaDB가 이미 실행 중이라면
docker run -d \
  --name wordpress-test \
  -e WORDPRESS_DB_HOST=host.docker.internal:3306 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wpuser \
  -e WORDPRESS_DB_PASSWORD=wppass \
  -e WORDPRESS_TABLE_PREFIX=wp_ \
  -e WORDPRESS_DEBUG=1 \
  -p 8080:8080 \
  -p 8443:8443 \
  wordpress-official:test
```

### 3.3 초기화 확인

```bash
# 컨테이너 로그 확인
docker logs -f wordpress-test

# 확인 사항:
# [Custom Entrypoint] Starting WordPress container initialization...
# [Custom Entrypoint] Waiting for WordPress initialization...
# [Custom Entrypoint] WordPress core files detected
# [Custom Entrypoint] Installing WordPress Feature API plugin...
# [Custom Entrypoint] WordPress Feature API plugin installed successfully
```

### 3.4 웹 브라우저 접속

```bash
# HTTP
open http://localhost:8080

# HTTPS (self-signed certificate)
open https://localhost:8443
```

**예상 화면**: WordPress 초기 설정 화면

---

## ✅ Step 4: 검증 체크리스트

### 4.1 기본 동작 확인

```bash
# 컨테이너 쉘 접속
docker exec -it wordpress-test bash

# 1. WordPress 파일 확인
ls -la /var/www/html/
# wp-config.php, wp-content/, wp-admin/ 등이 있어야 함

# 2. PHP 버전 및 확장 확인
php -v
# PHP 8.2.x 이상

php -m | grep -E "redis|mysqli|json|curl"
# redis
# mysqli
# 등이 나와야 함

# 3. NewRelic 확인
php -m | grep newrelic
# newrelic

cat /var/log/newrelic/php_agent.log
# 로그 파일이 생성되어야 함

# 4. WordPress Feature API 플러그인 확인
ls -la /var/www/html/wp-content/plugins/
# wp-feature-api 디렉토리가 있어야 함

ls -la /var/www/html/wp-content/plugins/wp-feature-api/
# vendor/, composer.json 등이 있어야 함

# 5. Apache 포트 확인
cat /etc/apache2/ports.conf | grep Listen
# Listen 8080
# Listen 8443

# 6. 파일 소유권 확인
ls -la /var/www/html/ | head -5
# www-data www-data로 소유권이 되어 있어야 함

# 7. 사용자 확인
whoami
# www-data (또는 root로 exec 했으면 root)

id www-data
# uid=33(www-data) gid=33(www-data)

exit
```

### 4.2 WordPress 설정 완료

1. 브라우저에서 `http://localhost:8080` 접속
2. 언어 선택
3. 사이트 정보 입력:
   - 사이트 제목: Test Site
   - 사용자명: admin
   - 비밀번호: (강력한 비밀번호)
   - 이메일: test@example.com
4. WordPress 설치 완료 확인

### 4.3 기능 테스트

**테스트 항목**:
- [ ] 관리자 로그인 (`/wp-admin`)
- [ ] 대시보드 접속
- [ ] 플러그인 목록 확인
  - WordPress Feature API 플러그인이 있는지
- [ ] 새 글 작성 및 발행
- [ ] 미디어 업로드 (이미지)
- [ ] 테마 변경
- [ ] 설정 변경 및 저장

### 4.4 성능 및 오류 확인

```bash
# 1. Apache 오류 로그
docker exec wordpress-test tail -50 /var/log/apache2/error.log

# 2. PHP 오류 (WordPress debug.log)
docker exec wordpress-test tail -50 /var/www/html/wp-content/debug.log

# 3. 컨테이너 리소스 사용량
docker stats wordpress-test

# 4. NewRelic 연동 확인 (NewRelic 라이선스 키 설정 시)
docker exec wordpress-test tail -50 /var/log/newrelic/php_agent.log
# "Reporting to: ..." 메시지가 있으면 연동 성공
```

---

## 🐳 Step 5: 이미지 레지스트리 푸시

### 5.1 이미지 태그 지정

```bash
# 날짜 기반 태그
TAG=$(date +%Y-%m-%d)
echo "Tag: $TAG"

# 이미지 태그
docker tag wordpress-official:test ghcr.io/unchartedsky/wordpress:$TAG
docker tag wordpress-official:test ghcr.io/unchartedsky/wordpress:latest
```

### 5.2 GitHub Container Registry 로그인

```bash
# Personal Access Token 사용
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 또는 대화형
docker login ghcr.io
```

### 5.3 푸시

```bash
docker push ghcr.io/unchartedsky/wordpress:$TAG
docker push ghcr.io/unchartedsky/wordpress:latest
```

---

## 🚀 Step 6: 스테이징 환경 테스트

### 6.1 스테이징 Namespace 생성

```bash
kubectl create namespace wordpress-staging
```

### 6.2 Secret 복사

```bash
# MariaDB Secret
kubectl get secret mariadb -n plaintext -o yaml | \
  sed 's/namespace: plaintext/namespace: wordpress-staging/' | \
  kubectl apply -f -

# WordPress Secret
kubectl get secret wordpress -n plaintext -o yaml | \
  sed 's/namespace: plaintext/namespace: wordpress-staging/' | \
  kubectl apply -f -

# GitHub pull secret
kubectl get secret github-andromedarabbit -n plaintext -o yaml | \
  sed 's/namespace: plaintext/namespace: wordpress-staging/' | \
  kubectl apply -f -
```

### 6.3 wordpress.yaml 수정 (스테이징용)

```bash
cd /Users/keaton/Workspace/Personal/citadel/recipes/ns-plaintext/recipes3

# 스테이징용 복사
cp wordpress.yaml wordpress-staging.yaml

# 편집
# - namespace: plaintext → wordpress-staging
# - image 태그를 새 버전으로 변경
# - Ingress는 제거하거나 다른 도메인 사용
```

### 6.4 배포

```bash
kubectl apply -f wordpress-staging.yaml

# Pod 상태 확인
kubectl get pods -n wordpress-staging -w

# Init Container 로그 확인
kubectl logs -n wordpress-staging <pod-name> -c migrate-bitnami-data
kubectl logs -n wordpress-staging <pod-name> -c fix-permissions

# WordPress 컨테이너 로그
kubectl logs -n wordpress-staging <pod-name> -c wordpress -f
```

### 6.5 스테이징 검증

```bash
# Port-forward로 접속
kubectl port-forward -n wordpress-staging svc/wordpress 8080:80 8443:443

# 브라우저에서 확인
open http://localhost:8080
```

**검증 항목**:
- [ ] WordPress 접속 가능
- [ ] 기존 데이터 마이그레이션 확인 (마이그레이션 대상이 있었다면)
- [ ] 플러그인 정상 작동
- [ ] 파일 업로드/다운로드
- [ ] 관리자 페이지 기능
- [ ] NewRelic APM 데이터 수집 (설정 시)

> ℹ️ **WordPress Feature API 플러그인**은 이미지에 포함되지 않습니다.
> 필요 시 `PLUGIN_INSTALLATION.md` 참조하여 수동 설치하세요.

---

## 🔧 Step 7: 문제 해결

### 문제 1: WordPress Feature API 플러그인이 없음

**원인**: 커스텀 entrypoint가 실행되지 않거나 타이밍 이슈

**해결**:
```bash
# 컨테이너 접속
kubectl exec -it -n wordpress-staging <pod-name> -- bash

# 수동 복사
cp -a /usr/local/wordpress-plugins/wp-feature-api /var/www/html/wp-content/plugins/
chown -R www-data:www-data /var/www/html/wp-content/plugins/wp-feature-api
```

### 문제 2: 권한 오류 (Permission denied)

**원인**: fsGroup 또는 파일 소유권 불일치

**해결**:
```bash
# Init Container 로그 확인
kubectl logs -n wordpress-staging <pod-name> -c fix-permissions

# 수동 수정
kubectl exec -it -n wordpress-staging <pod-name> -- bash
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
```

### 문제 3: 데이터베이스 연결 실패

**원인**: 환경변수 설정 오류

**확인**:
```bash
kubectl exec -it -n wordpress-staging <pod-name> -- env | grep WORDPRESS_DB
```

**올바른 변수**:
```
WORDPRESS_DB_HOST=mariadb:3306
WORDPRESS_DB_NAME=...
WORDPRESS_DB_USER=...
WORDPRESS_DB_PASSWORD=...
```

### 문제 4: 포트 접근 불가

**원인**: Apache 포트 설정 또는 K8s Service 포트 매핑 오류

**확인**:
```bash
# Apache 포트 확인
kubectl exec -it -n wordpress-staging <pod-name> -- cat /etc/apache2/ports.conf

# Service 확인
kubectl get svc -n wordpress-staging wordpress -o yaml

# Container 포트 확인
kubectl get pod -n wordpress-staging <pod-name> -o yaml | grep -A 5 containerPort
```

### 문제 5: Init Container 마이그레이션 실패

**원인**: 기존 데이터 경로 문제 또는 권한 부족

**확인**:
```bash
# PVC 내용 확인
kubectl exec -it -n wordpress-staging <pod-name> -- ls -la /old-data/
kubectl exec -it -n wordpress-staging <pod-name> -- ls -la /new-data/

# 마이그레이션 마커 확인
kubectl exec -it -n wordpress-staging <pod-name> -- cat /var/www/html/.migration-completed
```

---

## 📊 성공 기준

### 모든 체크리스트 통과 시 다음 단계 진행

✅ **빌드 성공**:
- Dockerfile 빌드 오류 없음
- 모든 레이어 정상 완료

✅ **로컬 테스트 성공**:
- WordPress 초기 화면 로드
- 설정 완료 가능
- 플러그인 정상 설치
- NewRelic 연동 확인

✅ **스테이징 배포 성공**:
- Init Container 정상 실행
- Pod Running 상태
- WordPress 접속 가능
- 기본 기능 동작

✅ **마이그레이션 검증** (기존 데이터 있는 경우):
- 기존 글/페이지 정상 표시
- 미디어 파일 접근 가능
- 플러그인/테마 유지

---

## 🎯 다음 단계

모든 테스트를 통과했다면:

1. **프로덕션 배포 준비**
   - MIGRATION_PLAN.md의 Phase 4 참조
   - 백업 확인
   - 롤백 계획 수립

2. **모니터링 설정**
   - NewRelic APM 확인
   - K8s 리소스 모니터링
   - 로그 수집 설정

3. **팀 공유**
   - 변경 사항 문서화
   - 배포 일정 공유
   - 비상 연락망 확인

---

## 📞 문제 발생 시

1. 로그 수집:
   ```bash
   kubectl logs -n wordpress-staging <pod-name> --all-containers > logs.txt
   kubectl describe pod -n wordpress-staging <pod-name> > pod-describe.txt
   ```

2. 이슈 트래킹:
   - GitHub Issues 생성
   - 로그 첨부
   - 재현 단계 기록

3. 롤백 준비:
   - 기존 이미지 태그 보관
   - PVC 스냅샷 확인

**Good luck! 🚀**
