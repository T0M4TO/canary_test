#!/bin/bash

function update_nginx_weight() {
    local BLUE=$1
    local GREEN=$2
    echo ">> 트래픽 비율 변경 중... Blue(${BLUE}%) / Green(${GREEN}%)"

    # [핵심] 할당 비율이 0 초과인 서버만 설정 문자열 명단에 편입하여 변수 조립!
    CONF="upstream backend { "
    [ "$BLUE" -gt 0 ] && CONF="${CONF} server app-blue:8080 weight=${BLUE}; "
    [ "$GREEN" -gt 0 ] && CONF="${CONF} server app-green:8081 weight=${GREEN}; "
    CONF="${CONF} }"

    # 호스트 밖에서 Nginx 컨테이너 내부로 설정 파일을 덮어쓰고, 프록시를 무중단 리로드(Reload) 처리합니다.
    docker exec nginx-proxy sh -c "echo '$CONF' > /etc/nginx/conf.d/upstream.inc"
    docker exec nginx-proxy nginx -s reload
}

# 1. 호스트 내 app-blue 명칭 컨테이너의 가동 상태 생존 여부 검색
IS_BLUE=$(docker ps -q -f name="^app-blue$")

# 검색 결과 존재(Blue 가동 중) 시, 신규 배포를 수행할 타겟 서버는 Green으로 교차 스위칭 할당
if [ -n "$IS_BLUE" ]; then
    CURRENT="blue"; TARGET="green"; TARGET_PORT=8081; TARGET_COLOR="🟢 GREEN"
else
    CURRENT="green"; TARGET="blue"; TARGET_PORT=8080; TARGET_COLOR="🔵 BLUE"
fi

echo "🚀 새로운 버전 [${TARGET}] 구동 시작!"

# 2. 최신 릴리즈 소스코드를 기반으로 신규 도커 이미지를 구워냅니다.
docker build -t my-canary-app .

# 3. 이전 배포 실패 등 잔재로 남아있는 타겟 컨테이너 찌꺼기 존재 시 사전 강제 파기 조치
docker rm -f app-$TARGET 2>/dev/null

# 4. 신규 컨테이너를 가상 네트워크망(canary-net)에 결속시켜 환경 변수 기반 구동 실행
docker run -d --name app-$TARGET \
  --network canary-net \
  -e PORT=$TARGET_PORT \
  -e COLOR="$TARGET_COLOR" \
  my-canary-app

# 5. 서버 내부 런타임 부팅을 위한 최소 대기 시간 부여 후, 프록시망 내부 접근 시도
sleep 5
RESPONSE=$(docker exec nginx-proxy sh -c "wget -qO- http://app-$TARGET:${TARGET_PORT}")

# 수신된 응답 문자열 패킷 미존재 시 서비스 불가로 판단, 즉각 컨테이너 파기(Rollback) 수행
if [ -z "$RESPONSE" ]; then
    echo "❌ 헬스체크 실패! 신규 서버 통신 접근 불가. 즉시 롤백 처리합니다."
    docker rm -f app-$TARGET
    exit 1
fi

# ==========================================
# 6. 점진적 카나리 개방 (Traffic Rollout Stages)
# ==========================================
echo "✅ [1단계] 10% 카나리 오픈 (15초 대기)"
if [ "$TARGET" == "green" ]; then update_nginx_weight 90 10; else update_nginx_weight 10 90; fi; sleep 15

echo "✅ [2단계] 50% 트래픽 균등 전환 (15초 대기)"
if [ "$TARGET" == "green" ]; then update_nginx_weight 50 50; else update_nginx_weight 50 50; fi; sleep 15

echo "🎉 [3단계] 신규 릴리즈 버전 100% 완전 라우팅 전환 확정 달성"
if [ "$TARGET" == "green" ]; then update_nginx_weight 0 100; else update_nginx_weight 100 0; fi

# 라우팅 트래픽 배분 목적이 완전 종료된 이전 버전(Legacy) 컨테이너 인스턴스 안전 파기
docker rm -f app-$CURRENT

