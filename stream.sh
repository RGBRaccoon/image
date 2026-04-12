#!/bin/bash
# ============================================================
# GStreamer 파이프라인: RealSense → H.264 인코딩 → MediaMTX
# ============================================================
#
# 파이프라인 흐름:
#   v4l2src           : /dev/video4 에서 카메라 영상 읽기
#   video/x-raw       : 해상도/fps 지정 (640x480, 30fps)
#   nvvidconv         : 색공간 변환 (Jetson 하드웨어)
#   nvv4l2h264enc     : H.264 인코딩 (Jetson 하드웨어 인코더)
#   h264parse         : H.264 스트림 파싱/정리
#   rtph264pay        : RTP 패킷으로 포장 (네트워크 전송용)
#   rtspclientsink    : MediaMTX RTSP 서버로 push
#
# ============================================================

# [현재] 소프트웨어 인코더 - 동작 확인용
# nvvidconv/nvv4l2h264enc가 컨테이너 안에서 인식되지 않을 때 사용
gst-launch-1.0 -v \
  v4l2src device=/dev/video4 ! \
  "video/x-raw,width=640,height=480,framerate=30/1" ! \
  videoconvert ! \
  x264enc tune=zerolatency speed-preset=ultrafast bitrate=1000 ! \
  h264parse config-interval=1 ! \
  rtph264pay pt=96 ! \
  rtspclientsink location=rtsp://127.0.0.1:8554/stream protocols=tcp

# [나중에] 하드웨어 인코더 - 동작 확인 후 위 파이프라인과 교체
# gst-launch-1.0 -v \
#   v4l2src device=/dev/video4 ! \
#   "video/x-raw,width=640,height=480,framerate=30/1" ! \
#   nvvidconv ! \
#   nvv4l2h264enc maxperf-enable=1 bitrate=1000000 ! \
#   h264parse config-interval=1 ! \
#   rtph264pay pt=96 ! \
#   rtspclientsink location=rtsp://127.0.0.1:8554/stream protocols=tcp
