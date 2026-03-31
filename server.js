const http = require('http');

// 도커 실행 시 주입받은 환경변수를 활용합니다.
const PORT = process.env.PORT || 8080;
const COLOR = process.env.COLOR || 'blue';
const VERSION = 'V1'; // 💡 데모 관측 시 이 버전값을 V2로 상향 수정하여 파이프라인 트리거 발생 예정

http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(`[${VERSION}] 현재 응답 서버 식별: ${COLOR} (포트: ${PORT})\n`);
}).listen(PORT, () => {
    console.log(`서버 가동 완료 (PORT: ${PORT})`);
});
