# Jetson RTSP 스트리밍 구축 계획

## 전체 구조

```
RealSense 카메라 (/dev/video4)
  → GStreamer  (영상 캡처 + H.264 하드웨어 인코딩)
    → MediaMTX  (RTSP 서버, 포트 8554)
      → VLC / ffplay  (rtsp://JETSON_IP:8554/stream)
```

### 도구 역할 요약

| 도구 | 역할 |
|---|---|
| **GStreamer** | 카메라 영상을 읽어서 H.264로 인코딩 후 MediaMTX로 전송 |
| **nvv4l2h264enc** | Jetson 내장 하드웨어 인코더. CPU 대신 전용 칩이 인코딩 처리 |
| **MediaMTX** | RTSP 서버. 클라이언트가 접속할 수 있는 포트를 열어둠 |
| **Docker** | 위 구성 전체를 컨테이너로 묶어서 배포/재시작 관리 |

---

## 진행 순서

```
[x] Step 1. Dockerfile 작성       ← 완료
[x] Step 2. mediamtx.yml 작성     ← 완료
[x] Step 3. stream.sh 작성        ← 완료
[ ] Step 4. Jetson으로 파일 전송  ← scp 또는 git
[ ] Step 5. Jetson에서 Docker 빌드
[ ] Step 6. Jetson에서 컨테이너 실행
[ ] Step 7. 외부 PC에서 접속 확인
```

---

## Step 1. Dockerfile 작성

**목표:** Jetson에서 동작하는 Docker 이미지 정의

핵심 구성:
- 베이스 이미지: Jetson용 L4T (Linux for Tegra) 기반
- GStreamer + Jetson 하드웨어 인코더 플러그인 포함
- MediaMTX 바이너리 포함
- 시작 시 MediaMTX 자동 실행

## Step 2. mediamtx.yml 작성

**목표:** MediaMTX가 GStreamer를 실행해서 카메라 영상을 받아오도록 설정

핵심 내용:
- `/stream` 경로로 RTSP 서빙
- 시작 시 GStreamer 파이프라인 자동 실행
- GStreamer가 종료되면 자동 재시작

GStreamer 파이프라인 (Jetson 기준):
```
v4l2src device=/dev/video4
  → video/x-raw,width=640,height=480,framerate=30/1
  → nvvidconv           ← 색공간 변환 (하드웨어)
  → nvv4l2h264enc       ← H.264 인코딩 (하드웨어)
  → h264parse
  → rtspclientsink      ← MediaMTX로 전송
```

## Step 3. Jetson으로 파일 전송

방법 A (scp):
```bash
scp -r ./rtsp-server user@JETSON_IP:~/
```

방법 B (git):
```bash
# GitHub 등에 올려두고 Jetson에서 git clone
```

## Step 4. Jetson에서 Docker 빌드

```bash
docker build -t rtsp-server .
```

- Windows가 아닌 **Jetson에서 빌드**하는 이유:
  - Jetson이 ARM64 아키텍처라 Windows(x86_64)에서 빌드한 이미지가 호환되지 않음

## Step 5. Jetson에서 컨테이너 실행

```bash
docker run -d \
  --name rtsp-server \
  --device /dev/video4 \    # 카메라를 컨테이너 안으로 전달
  -p 8554:8554 \            # RTSP 포트 외부 노출
  --restart unless-stopped \ # 자동 재시작
  rtsp-server
```

## Step 6. 외부 PC에서 접속 확인

ffplay:
```bash
ffplay rtsp://JETSON_IP:8554/stream
```

VLC: 미디어 열기 → 네트워크 스트림 → URL 입력

---

## 파일 목록

```
image/
  ├── Dockerfile       # 컨테이너 빌드 정의
  ├── mediamtx.yml     # RTSP 서버 설정
  └── stream.sh        # GStreamer 파이프라인 스크립트
```

---

## 나중에 바꿀 것 (지금은 제외)

- depth 스트림 추가
- 인증/보안 설정
- 해상도/fps 튜닝
- 다중 스트림
