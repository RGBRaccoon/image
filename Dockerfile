# ============================================================
# Jetson용 RTSP 스트리밍 서버
# 베이스: Ubuntu 22.04 (JetPack 6.x 기반)
# ============================================================

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# ffmpeg 설치
# - v4l2 카메라 입력 + libx264 인코딩 + RTSP push 지원
# - universe 저장소 활성화 (libx264 포함된 ffmpeg 제공)
# ============================================================
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y ffmpeg wget curl jq && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# MediaMTX 설치 (ARM64 바이너리)
# GitHub API로 최신 버전 자동 감지 → arm64v8 바이너리 다운로드
# ============================================================
RUN DOWNLOAD_URL=$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases/latest \
        | jq -r '.assets[] | select(.name | contains("linux_arm64v8")) | .browser_download_url') \
    && echo "Downloading: $DOWNLOAD_URL" \
    && wget -O /tmp/mediamtx.tar.gz "$DOWNLOAD_URL" \
    && tar -xzf /tmp/mediamtx.tar.gz -C /usr/local/bin mediamtx \
    && rm /tmp/mediamtx.tar.gz

# ============================================================
# 설정 파일 복사
# ============================================================
WORKDIR /app
COPY mediamtx.yml .
COPY stream.sh .
RUN chmod +x stream.sh

# RTSP 포트
EXPOSE 8554

CMD ["mediamtx", "/app/mediamtx.yml"]
