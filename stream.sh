#!/bin/bash
# ============================================================
# ffmpeg: RealSense(/dev/video4) → H.264 → MediaMTX로 push
# ============================================================
#
#   -f v4l2            : Linux 카메라 입력 방식
#   -i /dev/video4     : 카메라 장치
#   -vcodec libx264    : 소프트웨어 H.264 인코더
#   -preset ultrafast  : 인코딩 속도 최우선 (지연 최소화)
#   -tune zerolatency  : 실시간 스트리밍용 튜닝
#   -b:v 1000k         : 비트레이트 1Mbps
#   -f rtsp            : RTSP 포맷으로 출력
#   -rtsp_transport tcp: TCP로 전송 (UDP보다 안정적)
#
# ============================================================

ffmpeg -f v4l2 -i /dev/video4 \
  -vcodec libx264 -preset ultrafast -tune zerolatency -b:v 1000k \
  -f rtsp -rtsp_transport tcp rtsp://127.0.0.1:8554/stream
