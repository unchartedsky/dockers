# Bitnami → WordPress 공식 이미지 마이그레이션 계획

**작성일**: 2025-10-04
**목적**: Bitnami WordPress 이미지를 공식 WordPress 이미지로 전환

---

## 📊 핵심 차이점 정리

| 항목 | Bitnami WordPress | WordPress 공식 |
|------|-------------------|----------------|
| 웹서버 | Apache | Apache ✅ |
| 사용자 | 1001 (non-root) | www-data (UID 33) |
| 파일 경로 | `/bitnami/wordpress`, `/opt/bitnami/` | `/var/www/html` |
| 포트 | 8080, 8443 | 80, 443 (커스텀 가능) |
| PHP 설정 경로 | `/opt/bitnami/php/` | `/usr/local/etc/php/` |
| 환경변수 | `WORDPRESS_DATABASE_*`, `MARIADB_*`, `APACHE_*_PORT_NUMBER` | `WORDPRESS_DB_*` |
| fsGroup | 1001 | 33 |

### 주요 발견사항

1. **동일한 웹서버**: 둘 다 Apache 사용으로 호환성 높음
2. **Bitnami 2025년 변경사항**: 8월 28일부터 versioned 이미지가 유료화되며, 무료는 `:latest` 태그만 제공
3. **공식 이미지 entrypoint**: 런타임에 `/var/www/html` 초기화 (빌드타임 설치 주의 필요)

---

## 🎯 마이그레이션 작업 항목

### Phase 1: Dockerfile 재작성

**파일**: `/Users/keaton/Workspace/Personal/dockers/wordpress/Dockerfile.template`

#### 1.1 베이스 이미지 변경
```dockerfile
# Before
FROM bitnami/wordpress:{{.BASE_IMAGE_VERSION | default "latest"}}

# After
FROM wordpress:{{.WORDPRESS_VERSION | default "php8.2-apache"}}
# 또는 wordpress:php8.3-apache
```

#### 1.2 사용자 설정
```dockerfile
# 공식 이미지는 기본적으로 www-data 사용
# 빌드 중 root 사용, 마지막에 www-data로 전환
USER root
# ... 작업 ...
USER www-data
```

#### 1.3 필수 패키지 설치 (동일하게 유지)
```dockerfile
RUN set -ex; \
    export DEBIAN_FRONTEND=noninteractive; \
    deps='curl ca-certificates wget unzip jq rsync vim cron html2text awscli'; \
    apt-get update -y; \
    apt-get install -y $deps; \
    rm /var/log/dpkg.log /var/log/apt/*.log;
```

#### 1.4 PHP 확장 설치 (경로 변경)
```dockerfile
# Redis 설치 (동일)
RUN pecl install redis && \
    echo "extension=redis.so" > /usr/local/etc/php/conf.d/redis.ini

# ImageMagick (공식 이미지에 일부 포함, 추가 확인 필요)
RUN apt-get update && \
    apt-get install -y \
      fontconfig-config fonts-dejavu-core imagemagick-6-common \
      libfftw3-double3 libfontconfig1 libglib2.0-0 libgomp1 libjbig0 \
      liblcms2-2 liblqr-1-0 libltdl7 libmagickcore-6.q16-6 \
      libmagickwand-6.q16-6 libopenjp2-7 libtiff6 libx11-6 libx11-data libxau6 \
      libxcb1 libxdmcp6 libxext6 unzip \
      gcc make autoconf libc-dev pkg-config libmagickwand-dev && \
    # PHP-FPM 설정 경로 변경 필요 (Apache 모드이므로 다른 방식 필요)
    apt-get -y remove --auto-remove \
      gcc make autoconf libc-dev pkg-config libmagickwand-dev && \
    rm -rf /usr/include/* /tmp/* /var/lib/apt/lists/*
```

**주의**: ImageMagick PHP-FPM 설정 부분은 공식 이미지 구조에 맞게 수정 필요

#### 1.5 NewRelic 설치 (경로만 변경)
```dockerfile
ENV NR_INSTALL_SILENT=true

WORKDIR /tmp

RUN export NEWRELIC_FILENAME=$(curl -L --silent https://download.newrelic.com/php_agent/release | html2text | grep linux.tar.gz | cut -d ' ' -f1) && \
    curl --silent -L "https://download.newrelic.com/php_agent/release/${NEWRELIC_FILENAME}" -o "${NEWRELIC_FILENAME}" && \
    tar xvfz "${NEWRELIC_FILENAME}" && \
    cd "$(basename ${NEWRELIC_FILENAME} .tar.gz)" && \
    ./newrelic-install install && \
    cd .. && \
    rm -f "${NEWRELIC_FILENAME}" && \
    mkdir -p /var/log/newrelic && \
    chown -R 33:33 /var/log/newrelic  # 1001 → 33

# 설정 파일 복사 경로 변경
COPY newrelic.ini /usr/local/etc/php/conf.d/newrelic.ini
```

**파일 수정 필요**: `newrelic.ini` 내 경로 확인
- Line 57: `newrelic.logfile = "/var/log/newrelic/php_agent.log"` (유지)
- Line 148: `newrelic.daemon.logfile = "/var/log/newrelic/newrelic-daemon.log"` (유지)

#### 1.6 Apache 포트 설정 (8080/8443 유지)
```dockerfile
# Apache 포트 변경 (K8s securityContext 때문에 non-privileged 포트 사용)
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/Listen 443/Listen 8443/' /etc/apache2/ports.conf && \
    sed -i 's/:80/:8080/g' /etc/apache2/sites-available/*.conf && \
    sed -i 's/:443/:8443/g' /etc/apache2/sites-available/*.conf
```

#### 1.7 WordPress Feature API 플러그인

**✅ 결정**: 이미지에 포함하지 않고 **수동 설치 방식** 채택

**이유**:
- WordPress Feature API는 AI/LLM 통합용 플러그인 (일반 블로그에는 불필요)
- 곧 deprecated 예정 (WordPress 6.9+에서는 Abilities API로 대체)
- 이미지 크기 절약 (Composer + vendor 디렉토리 제거)
- 간단한 구조 유지

**설치 방법**:
- 필요 시 `PLUGIN_INSTALLATION.md` 참조
- WordPress 관리자 또는 wp-cli로 수동 설치
- 또는 Init Container로 자동 설치 가능

---

### Phase 2: K8s Manifest 수정

**파일**: `/Users/keaton/Workspace/Personal/citadel/recipes/ns-plaintext/recipes3/wordpress.yaml`

#### 2.1 securityContext 변경

**Line 265-268**:
```yaml
securityContext:
  fsGroup: 33  # 1001 → 33 (www-data)
  seccompProfile:
    type: RuntimeDefault
```

**Line 276-283**:
```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 33  # 1001 → 33
```

#### 2.2 환경변수 매핑 (Line 286-350)

**제거할 환경변수**:
```yaml
# - name: BITNAMI_DEBUG
#   value: "true"
# - name: ALLOW_EMPTY_PASSWORD
#   value: "yes"
# - name: APACHE_HTTP_PORT_NUMBER
#   value: "8080"
# - name: APACHE_HTTPS_PORT_NUMBER
#   value: "8443"
```

**변경할 환경변수**:
```yaml
# Before:
- name: MARIADB_HOST
  value: "mariadb"
- name: MARIADB_PORT_NUMBER
  value: "3306"
- name: WORDPRESS_DATABASE_NAME
  valueFrom:
    secretKeyRef:
      name: mariadb
      key: mariadb-database

# After:
- name: WORDPRESS_DB_HOST
  value: "mariadb:3306"  # 호스트:포트 형식
- name: WORDPRESS_DB_NAME
  valueFrom:
    secretKeyRef:
      name: mariadb
      key: mariadb-database
```

```yaml
# Before:
- name: WORDPRESS_DATABASE_USER
- name: WORDPRESS_DATABASE_PASSWORD

# After:
- name: WORDPRESS_DB_USER
- name: WORDPRESS_DB_PASSWORD
```

**유지 가능성 불확실한 환경변수** (테스트 필요):
```yaml
- name: WORDPRESS_USERNAME  # ⚠️ 공식 이미지 지원 여부 확인
  value: "team7"
- name: WORDPRESS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: wordpress
      key: wordpress-password
- name: WORDPRESS_EMAIL
  value: "team7@unchartedsky.com"
- name: WORDPRESS_FIRST_NAME  # ⚠️ 비표준
  value: "Admin"
- name: WORDPRESS_LAST_NAME  # ⚠️ 비표준
  value: "Team7"
- name: WORDPRESS_BLOG_NAME  # ⚠️ 비표준
  value: "User's Blog!"
```

**공식 이미지 표준 환경변수**:
- `WORDPRESS_DB_HOST`
- `WORDPRESS_DB_USER`
- `WORDPRESS_DB_PASSWORD`
- `WORDPRESS_DB_NAME`
- `WORDPRESS_TABLE_PREFIX`
- `WORDPRESS_DEBUG`
- `WORDPRESS_CONFIG_EXTRA` (추가 wp-config.php 설정)

**비표준 변수 대안**:
```yaml
- name: WORDPRESS_CONFIG_EXTRA
  value: |
    define('WP_DEBUG', false);
    // PHP opcache 설정은 php.ini에서 처리
```

#### 2.3 포트 설정 (Line 351-355)

**옵션 1: 8080/8443 유지** (Dockerfile에서 Apache 설정 변경)
```yaml
ports:
  - name: http
    containerPort: 8080  # 그대로 유지
  - name: https
    containerPort: 8443  # 그대로 유지
```

**옵션 2: 80/443 사용** (표준 포트)
```yaml
ports:
  - name: http
    containerPort: 80
  - name: https
    containerPort: 443
```

**추천**: 옵션 1 (8080/8443 유지) - securityContext runAsNonRoot와 호환

#### 2.4 볼륨 마운트 경로 (Line 385-388)

```yaml
volumeMounts:
  - mountPath: /var/www/html  # /bitnami/wordpress → /var/www/html
    name: wordpress-data
    subPath: html  # 'wordpress' → 'html' 변경 (또는 마이그레이션 후 변경)
```

#### 2.5 이미지 태그 (Line 274)

```yaml
# Before:
image: ghcr.io/unchartedsky/wordpress:2025-04-05

# After:
image: ghcr.io/unchartedsky/wordpress:2025-10-05  # 새 빌드 태그
```

---

### Phase 3: 데이터 마이그레이션 전략

**문제**: 기존 PVC에 `/bitnami/wordpress` 경로로 데이터 저장됨 → `/var/www/html` 필요

#### 방법 1: Init Container (추천)

**wordpress.yaml**의 `spec.template.spec`에 추가:

```yaml
initContainers:
  # 1. 데이터 마이그레이션
  - name: migrate-bitnami-data
    image: busybox:latest
    command:
      - sh
      - -c
      - |
        echo "Checking for Bitnami data migration..."

        if [ -d /old-data/wordpress ] && [ ! -f /new-data/.migration-completed ]; then
          echo "Migrating data from /bitnami/wordpress to /var/www/html..."

          # 전체 복사
          mkdir -p /new-data
          cp -av /old-data/wordpress/. /new-data/

          # 마이그레이션 완료 마커
          touch /new-data/.migration-completed
          echo "$(date): Migration from Bitnami to official image" > /new-data/.migration-completed

          echo "Migration completed successfully!"
        elif [ -f /new-data/.migration-completed ]; then
          echo "Migration already completed:"
          cat /new-data/.migration-completed
        else
          echo "No Bitnami data found at /old-data/wordpress - fresh installation"
        fi
    volumeMounts:
      - name: wordpress-data
        mountPath: /old-data
      - name: wordpress-data
        mountPath: /new-data
        subPath: html
    securityContext:
      runAsUser: 0  # root로 실행하여 파일 복사

  # 2. 권한 수정
  - name: fix-permissions
    image: busybox:latest
    command:
      - sh
      - -c
      - |
        echo "Fixing file permissions for www-data (33:33)..."
        chown -R 33:33 /var/www/html
        echo "Permissions fixed!"
    volumeMounts:
      - name: wordpress-data
        mountPath: /var/www/html
        subPath: html
    securityContext:
      runAsUser: 0  # root로 실행
```

**장점**:
- 자동 마이그레이션
- 한 번만 실행되며 이후는 스킵
- 롤백 용이 (기존 데이터 유지)

**단점**:
- Pod 재시작 시마다 체크 (하지만 빠름)

#### 방법 2: 별도 Migration Job

별도 파일 생성: `wordpress-migration-job.yaml`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: wordpress-data-migration
  namespace: plaintext
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: busybox:latest
          command:
            - sh
            - -c
            - |
              if [ -d /old-data/wordpress ]; then
                echo "Copying data..."
                mkdir -p /new-data/html
                cp -av /old-data/wordpress/. /new-data/html/
                chown -R 33:33 /new-data/html
                echo "Migration completed!"
              else
                echo "No data to migrate"
              fi
          volumeMounts:
            - name: wordpress-data
              mountPath: /old-data
            - name: wordpress-data
              mountPath: /new-data
      volumes:
        - name: wordpress-data
          persistentVolumeClaim:
            claimName: wordpress
      securityContext:
        runAsUser: 0
        fsGroup: 0
```

**장점**:
- 수동 제어 가능
- 마이그레이션 완료 후 삭제 가능

**단점**:
- 수동 실행 필요
- 더 복잡한 워크플로우

**추천**: 방법 1 (Init Container)

---

### Phase 4: 검증 및 롤아웃

#### 4.1 사전 준비

1. **PVC 백업**
   ```bash
   # PVC 스냅샷 생성 (CSI 스냅샷 지원 시)
   kubectl create -f pvc-snapshot.yaml

   # 또는 수동 백업
   kubectl exec -n plaintext deployment/wordpress -- tar czf /tmp/backup.tar.gz -C /bitnami/wordpress .
   kubectl cp plaintext/wordpress-pod:/tmp/backup.tar.gz ./wordpress-backup-$(date +%Y%m%d).tar.gz
   ```

2. **현재 상태 기록**
   ```bash
   kubectl get deployment wordpress -n plaintext -o yaml > wordpress-deployment-backup.yaml
   kubectl describe pvc wordpress -n plaintext > wordpress-pvc-info.txt
   ```

3. **이미지 태그 기록**
   - 현재: `ghcr.io/unchartedsky/wordpress:2025-04-05`
   - 신규: `ghcr.io/unchartedsky/wordpress:2025-10-05` (예시)

#### 4.2 로컬 테스트

```bash
# 1. 새 Dockerfile 빌드
cd /Users/keaton/Workspace/Personal/dockers/wordpress
docker build -t wordpress-test:local -f Dockerfile .

# 2. 로컬 실행 테스트
docker run -p 8080:8080 -p 8443:8443 \
  -e WORDPRESS_DB_HOST=host.docker.internal:3306 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=root \
  -e WORDPRESS_DB_PASSWORD=password \
  wordpress-test:local

# 3. 확인사항
# - http://localhost:8080 접속
# - NewRelic 로그 확인: docker exec <container> tail /var/log/newrelic/php_agent.log
# - Redis 확장 확인: docker exec <container> php -m | grep redis
# - PHP 설정 확인: docker exec <container> php -i
```

#### 4.3 스테이징 환경 테스트

```bash
# 1. 별도 namespace 생성
kubectl create namespace wordpress-staging

# 2. Secret 복사
kubectl get secret mariadb -n plaintext -o yaml | \
  sed 's/namespace: plaintext/namespace: wordpress-staging/' | \
  kubectl apply -f -

kubectl get secret wordpress -n plaintext -o yaml | \
  sed 's/namespace: plaintext/namespace: wordpress-staging/' | \
  kubectl apply -f -

# 3. 스테이징용 manifest 적용
kubectl apply -f wordpress-staging.yaml

# 4. 검증
kubectl logs -n wordpress-staging -l app=wordpress --tail=100
kubectl exec -n wordpress-staging deployment/wordpress -- wp --info
```

**검증 체크리스트**:
- [ ] WordPress 초기 화면 로드
- [ ] 데이터베이스 연결 확인
- [ ] 플러그인/테마 정상 작동
- [ ] wp-content 업로드 권한
- [ ] NewRelic APM 데이터 수집
- [ ] Redis 연결 (있다면)
- [ ] HTTPS 접속 (8443 포트)
- [ ] wp-admin 로그인

#### 4.4 프로덕션 배포

**Blue-Green 배포 방식** (추천):

1. **새 Deployment 생성**
   ```bash
   # wordpress.yaml을 wordpress-green.yaml로 복사 후 수정
   # metadata.name: wordpress → wordpress-green
   kubectl apply -f wordpress-green.yaml
   ```

2. **헬스체크 대기**
   ```bash
   kubectl wait --for=condition=available --timeout=300s \
     deployment/wordpress-green -n plaintext
   ```

3. **Service 전환**
   ```yaml
   # Service selector 변경
   selector:
     app.kubernetes.io/name: wordpress
     app.kubernetes.io/instance: blog-green  # blog → blog-green
   ```

4. **모니터링 (10-30분)**
   - 에러 로그 확인
   - NewRelic APM 메트릭
   - 사용자 접속 테스트

5. **롤백 또는 완료**
   ```bash
   # 문제 발생 시 롤백
   kubectl patch service wordpress -n plaintext -p '{"spec":{"selector":{"app.kubernetes.io/instance":"blog"}}}'

   # 정상 작동 시 기존 삭제
   kubectl delete deployment wordpress -n plaintext
   kubectl delete deployment wordpress-green -n plaintext
   # 그리고 wordpress.yaml 적용
   kubectl apply -f wordpress.yaml
   ```

**Canary 배포 방식** (대안):
- Ingress weight 조정으로 트래픽 점진적 전환
- 더 안전하지만 복잡함

---

## ⚠️ 주요 리스크 및 대응

### 리스크 1: WordPress Feature API 플러그인 손실

**문제**: 빌드타임 설치가 런타임에 덮어써질 수 있음

**대응**:
1. 커스텀 entrypoint로 런타임 복사 (Phase 1.7 참조)
2. 또는 Init Container에서 설치
3. 또는 PVC에 영구 저장

### 리스크 2: 환경변수 미지원

**문제**: `WORDPRESS_USERNAME`, `WORDPRESS_FIRST_NAME` 등 비표준 변수

**대응**:
1. 로컬 테스트로 확인
2. 미지원 시 `WORDPRESS_CONFIG_EXTRA`로 대체
3. 또는 수동으로 wp-config.php 수정 (ConfigMap)

### 리스크 3: 권한 문제

**문제**: fsGroup 33 변경 시 기존 파일 소유권 충돌

**대응**:
- Init Container로 `chown -R 33:33` 실행 (Phase 3 참조)
- 충분한 테스트

### 리스크 4: 데이터 손실

**문제**: 마이그레이션 중 오류

**대응**:
1. 반드시 PVC 백업
2. Init Container의 `.migration-completed` 마커로 중복 실행 방지
3. 기존 데이터 유지 (`/bitnami/wordpress`는 삭제하지 않음)

### 리스크 5: NewRelic 연동 실패

**문제**: 경로 변경으로 설정 미적용

**대응**:
1. `newrelic.ini` 경로 확인: `/usr/local/etc/php/conf.d/`
2. 로그 확인: `/var/log/newrelic/php_agent.log`
3. PHP 모듈 로드 확인: `php -m | grep newrelic`

---

## 📋 작업 체크리스트

### 준비 단계
- [ ] 현재 배포 상태 백업
- [ ] PVC 스냅샷/백업 생성
- [ ] Dockerfile.template 분석 완료
- [ ] K8s manifest 분석 완료
- [ ] 마이그레이션 계획 검토

### 개발 단계
- [ ] Dockerfile.template 수정
  - [ ] 베이스 이미지 변경
  - [ ] 사용자 권한 설정
  - [ ] PHP 확장 경로 수정
  - [ ] NewRelic 경로 수정
  - [ ] Apache 포트 설정 (8080/8443)
  - [ ] WordPress Feature API 설치 방식 결정
- [ ] newrelic.ini 파일 검토 (경로 확인)
- [ ] 커스텀 entrypoint 작성 (필요 시)

### 테스트 단계
- [ ] 로컬 Docker 빌드
- [ ] 로컬 실행 테스트
  - [ ] WordPress 설치 확인
  - [ ] NewRelic 연동 확인
  - [ ] Redis 확장 확인
  - [ ] 포트 8080/8443 확인
- [ ] 이미지 레지스트리 푸시

### K8s 개발 단계
- [ ] wordpress.yaml 수정
  - [ ] securityContext 변경 (fsGroup: 33, runAsUser: 33)
  - [ ] 환경변수 매핑
  - [ ] 포트 설정 확인
  - [ ] 볼륨 마운트 경로 변경
  - [ ] 이미지 태그 업데이트
  - [ ] Init Container 추가
- [ ] wordpress-staging.yaml 생성

### 스테이징 테스트
- [ ] 스테이징 namespace 생성
- [ ] Secret 복사
- [ ] 스테이징 배포
- [ ] 기능 테스트
  - [ ] WordPress 접속
  - [ ] 데이터베이스 연결
  - [ ] 플러그인 작동
  - [ ] 파일 업로드
  - [ ] NewRelic 데이터
  - [ ] HTTPS 접속
- [ ] 성능 테스트
- [ ] 로그 확인

### 프로덕션 배포
- [ ] 배포 방식 결정 (Blue-Green/Canary)
- [ ] 배포 실행
- [ ] 헬스체크 대기
- [ ] 모니터링 (30분)
- [ ] 사용자 테스트
- [ ] 롤백 준비 상태 확인
- [ ] 최종 완료 또는 롤백 결정

### 사후 정리
- [ ] 기존 Deployment 삭제 (성공 시)
- [ ] 스테이징 환경 정리
- [ ] 백업 파일 아카이브
- [ ] 문서 업데이트
- [ ] 팀 공유

---

## 📌 참고 자료

### 공식 문서
- WordPress Docker Official Image: https://hub.docker.com/_/wordpress
- WordPress Docker GitHub: https://github.com/docker-library/wordpress
- Bitnami WordPress 변경사항: https://www.docker.com/blog/broadcoms-new-bitnami-restrictions-migrate-easily-with-docker/

### 환경변수 레퍼런스
- `WORDPRESS_DB_HOST`: 데이터베이스 호스트 (예: `mariadb:3306`)
- `WORDPRESS_DB_USER`: 데이터베이스 사용자
- `WORDPRESS_DB_PASSWORD`: 데이터베이스 패스워드
- `WORDPRESS_DB_NAME`: 데이터베이스 이름
- `WORDPRESS_TABLE_PREFIX`: 테이블 prefix (기본값: `wp_`)
- `WORDPRESS_DEBUG`: 디버그 모드 (true/false)
- `WORDPRESS_CONFIG_EXTRA`: 추가 wp-config.php 설정

### 파일 경로 맵핑

| 용도 | Bitnami | Official |
|------|---------|----------|
| WordPress 루트 | `/bitnami/wordpress` | `/var/www/html` |
| PHP 설정 | `/opt/bitnami/php/etc/php.ini` | `/usr/local/etc/php/php.ini` |
| PHP 확장 설정 | `/opt/bitnami/php/etc/conf.d/` | `/usr/local/etc/php/conf.d/` |
| Apache 설정 | `/opt/bitnami/apache/conf/` | `/etc/apache2/` |
| NewRelic 로그 | `/var/log/newrelic/` | `/var/log/newrelic/` (동일) |

### 연락처
- 이슈 발생 시: (팀 연락처 추가)
- 마이그레이션 책임자: (이름 추가)
- 예상 작업 시간: 4-6시간 (테스트 포함)

---

**다음 단계**: Phase 1.1 Dockerfile.template 수정 시작
