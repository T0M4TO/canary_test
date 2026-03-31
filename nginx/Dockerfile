FROM nginx:alpine
COPY default.conf /etc/nginx/conf.d/default.conf

# [핵심 방어] 초기 구동 시 Green 서버 미존재에 따른 Nginx 기동 실패를 원천 차단하기 위해, 
# 상시 켜져 있는 Blue 컨테이너 단일 등록 파일을 강제 생성합니다.
RUN echo "upstream backend { server app-blue:8080; }" > /etc/nginx/conf.d/upstream.inc

