# ============================================================
# Jetson용 RTSP 스트리밍 서버
# ============================================================
#
# [베이스 이미지 선택]
# JetPack 버전에 따라 이미지 태그가 달라짐.
# Jetson에서 아래 명령으로 버전 확인:
#   cat /etc/nv_tegra_release
#
# JetPack 5.x → r35.x.x
# JetPack 6.x → r36.x.x  ← 현재 환경: r36.5.0 (JetPack 6.2)
#
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# GStreamer 설치
# - gstreamer1.0-tools       : gst-launch-1.0 등 CLI 도구
# - plugins-base             : 기본 요소 (videoconvert 등)
# - plugins-good             : v4l2src (카메라 입력) 포함
# - plugins-bad              : rtspclientsink (MediaMTX로 전송) 포함
# - plugins-ugly             : 일부 코덱
#
# nvv4l2h264enc (Jetson 하드웨어 인코더) 는
# --runtime=nvidia 옵션으로 실행할 때 호스트에서 자동으로 마운트됨.
# ============================================================
RUN apt-get update && apt-get install -y \
    ffmpeg \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# MediaMTX 설치 (ARM64 바이너리)
# - Jetson은 ARM64 아키텍처이므로 arm64v8 버전 사용
# - 바이너리 하나를 /usr/local/bin에 넣는 것으로 설치 완료
# ============================================================
ARG MEDIAMTX_VERSION=v1.9.1
RUN wget -qO /tmp/mediamtx.tar.gz \
    "https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_linux_arm64v8.tar.gz" \
    && tar -xzf /tmp/mediamtx.tar.gz -C /usr/local/bin mediamtx \
    && rm /tmp/mediamtx.tar.gz

# ============================================================
# 설정 파일 복사
# ============================================================
WORKDIR /app
COPY mediamtx.yml .
COPY stream.sh .
RUN chmod +x stream.sh

# RTSP 포트 (기본값 8554)
EXPOSE 8554

CMD ["mediamtx", "/app/mediamtx.yml"]
