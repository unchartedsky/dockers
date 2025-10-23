# WordPress AI 플러그인 설치 가이드

**작성일**: 2025-10-04
**업데이트**: 2025-10-04

---

## ✅ 자동 설치: WordPress Abilities API

**현재 Kubernetes 배포 환경에서는 Abilities API가 자동으로 설치됩니다.**

- **패키지**: `wordpress/abilities-api` (v0.1.1)
- **설치 방법**: Kubernetes Init Container (composer:2 이미지)
- **위치**: `/var/www/html/wp-content/plugins/abilities-api/`
- **상태**: WordPress 6.9에 포함 예정 (현재는 별도 플러그인)

### 확인 방법
```bash
# Kubernetes
kubectl exec -it -n plaintext deployment/wordpress -- ls -la /var/www/html/wp-content/plugins/abilities-api/

# 또는 WordPress 관리자
# 플러그인 → 설치된 플러그인 → "Abilities API" 확인
```

### 활성화
1. WordPress 관리자 로그인: `https://andromedarabbit.net/wp-admin`
2. **플러그인** 메뉴 클릭
3. **Abilities API** 찾기
4. **활성화** 클릭

### Init Container 동작 방식

Kubernetes manifest의 Init Container가 다음을 수행합니다:

```yaml
- name: install-abilities-api
  image: composer:2
  command:
    - composer install wordpress/abilities-api
```

- Pod 시작 시 자동 실행
- 이미 설치되어 있으면 스킵
- 실패해도 Pod는 정상 시작 (플러그인 없이)

---

## 📋 사전 확인

WordPress Abilities API는 **AI/LLM 통합**을 위한 플러그인입니다.

### 필요한 경우
- ✅ AI 기반 콘텐츠 생성 사용
- ✅ LLM을 통한 WordPress 자동 제어
- ✅ MCP (Model Context Protocol) 연동
- ✅ AI agent 기반 자동화 시스템

### 불필요한 경우
- ❌ 일반 블로그 운영
- ❌ 수동 콘텐츠 작성
- ❌ AI 기능 미사용

> 💡 **일반 블로그**라면 이 플러그인을 활성화하지 **않아도 됩니다**.

---

## 🔧 수동 설치 (Init Container 사용하지 않는 경우)

### 방법 1: Composer 사용 (권장)

#### 1단계: WordPress 컨테이너 접속
```bash
kubectl exec -it -n plaintext deployment/wordpress -- bash
```

#### 2단계: Composer 설치 확인
```bash
composer --version
# 없으면 설치
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
```

#### 3단계: Abilities API 설치
```bash
cd /var/www/html/wp-content/plugins
mkdir -p abilities-api
cd abilities-api

# composer.json 생성
cat > composer.json <<'EOF'
{
  "require": {
    "wordpress/abilities-api": "^0.1.1"
  }
}
EOF

# 설치
composer install --no-dev

# 권한 수정
chown -R www-data:www-data /var/www/html/wp-content/plugins/abilities-api
```

#### 4단계: WordPress 관리자에서 활성화
플러그인 → Abilities API → 활성화

---

### 방법 2: wp-cli 사용

```bash
# 컨테이너 접속
kubectl exec -it -n plaintext deployment/wordpress -- bash

# wp-cli 설치 (없는 경우)
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Abilities API 설치
cd /var/www/html
wp plugin install https://github.com/WordPress/abilities-api/archive/refs/heads/trunk.zip --activate

# 또는 Composer 패키지로
composer require wordpress/abilities-api
```

---

### 방법 3: GitHub에서 직접 다운로드

```bash
cd /var/www/html/wp-content/plugins

# 최신 버전 다운로드
curl -L https://github.com/WordPress/abilities-api/archive/refs/heads/trunk.tar.gz | tar xz
mv abilities-api-trunk abilities-api

# Composer 의존성 설치
cd abilities-api
composer install --no-dev

# 권한 수정
chown -R www-data:www-data /var/www/html/wp-content/plugins/abilities-api
```

---

## 🔍 설치 확인

### 파일 시스템 확인
```bash
ls -la /var/www/html/wp-content/plugins/abilities-api/
# vendor/, composer.json, README.md 등이 있어야 함
```

### WordPress 관리자 확인
```
플러그인 → 설치된 플러그인 → Abilities API 확인
```

### wp-cli 확인
```bash
wp plugin list | grep abilities
# abilities-api  0.1.1  active
```

---

## 🔄 Init Container 비활성화

Abilities API를 자동 설치하지 않으려면 `wordpress.yaml`에서 Init Container를 제거하세요:

```yaml
# wordpress.yaml에서 삭제
# initContainers:
#   - name: install-abilities-api
#     ...
```

---

## 🗑️ 제거

### WordPress 관리자
```
플러그인 → Abilities API → 비활성화 → 삭제
```

### wp-cli
```bash
wp plugin deactivate abilities-api
wp plugin delete abilities-api
```

### 수동 삭제
```bash
rm -rf /var/www/html/wp-content/plugins/abilities-api
```

---

## 📚 참고 자료

- **GitHub**: https://github.com/WordPress/abilities-api
- **Packagist**: https://packagist.org/packages/wordpress/abilities-api
- **WordPress AI Initiative**: https://make.wordpress.org/ai/
- **문서**: https://make.wordpress.org/ai/2025/07/17/abilities-api/

---

## ⚠️ Deprecated: WordPress Feature API

> **경고**: `automattic/wp-feature-api`는 **deprecated**되었습니다.
>
> - WordPress 6.9+에서는 **Abilities API 사용 필수**
> - 새 프로젝트는 Abilities API로 시작
> - 기존 Feature API 사용 중이라면 마이그레이션 권장

### Feature API → Abilities API 마이그레이션

```bash
# 1. Feature API 비활성화 및 제거
wp plugin deactivate wp-feature-api
wp plugin delete wp-feature-api

# 2. Abilities API 설치 (위 방법 참조)
# Init Container가 자동으로 설치하거나
# 수동으로 설치

# 3. 코드 마이그레이션 (개발자용)
# Feature API 호출을 Abilities API로 변경
# 자세한 내용은 공식 문서 참조
```

### Feature API 수동 설치 (레거시 - 참고용)

<details>
<summary>구버전 Feature API 설치 방법 (클릭하여 펼치기)</summary>

#### Composer로 설치
```bash
cd /var/www/html/wp-content/plugins
mkdir -p wp-feature-api
cd wp-feature-api

cat > composer.json <<'EOF'
{
  "require": {
    "automattic/wp-feature-api": "^0.1.8"
  }
}
EOF

composer install --no-dev
chown -R www-data:www-data /var/www/html/wp-content/plugins/wp-feature-api
```

#### GitHub에서 설치
```bash
cd /var/www/html/wp-content/plugins
curl -L https://github.com/Automattic/wp-feature-api/archive/refs/tags/0.1.8.tar.gz | tar xz
mv wp-feature-api-0.1.8 wp-feature-api
cd wp-feature-api
composer install --no-dev
```

</details>

---

## 💡 트러블슈팅

### 문제: Init Container가 실패함
```bash
# Init Container 로그 확인
kubectl logs -n plaintext <pod-name> -c install-abilities-api

# 일반적인 원인:
# - 네트워크 문제 (composer 다운로드 실패)
# - 권한 문제
# - Packagist 접속 불가
```

### 문제: Composer 의존성 오류
```bash
cd /var/www/html/wp-content/plugins/abilities-api
composer clear-cache
composer install --no-dev
```

### 문제: 권한 오류
```bash
chown -R www-data:www-data /var/www/html/wp-content/plugins/abilities-api
chmod -R 755 /var/www/html/wp-content/plugins/abilities-api
```

### 문제: 플러그인이 보이지 않음
```bash
# WordPress 관리자 → 플러그인 페이지 새로고침
# 또는 캐시 삭제
wp cache flush
```

---

**권장 사항**:
- AI 기능을 사용하지 않는다면 Abilities API를 **비활성화**하세요
- WordPress 6.9+ 사용 시 자동으로 core에 포함될 예정
- 현재는 별도 플러그인으로 설치 필요
