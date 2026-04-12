아래 내용을 그대로 README.md나 TASK.md로 넘기시면 됩니다.

# Jetson + RealSense RTSP Server 구현 정리

## 목적

Jetson 보드에 연결된 Intel RealSense 카메라로부터 **우선 RGB 영상만** 받아서,
Jetson 내부에서 **RTSP 서버 형태로 스트리밍 서비스**를 제공하는 구조를 만든다.

최종적으로는:

- RealSense가 Jetson에 연결되어 있고
- Jetson에서 RTSP 서버가 실행되며
- 외부 PC(예: Windows)에서 VLC 등으로 접속해 영상을 볼 수 있어야 한다
- 이후 Docker 컨테이너로 패키징해 Jetson에서 서비스처럼 구동하고 싶다

---

## 현재까지 확인된 사항

### 하드웨어 / 장치 인식
- Intel RealSense 장치가 `lsusb`에서 확인됨
- `/dev/video0` ~ `/dev/video5` 장치가 생성됨

### 스트림 식별
- `/dev/video2` : 흑백 스트림
- `/dev/video4` : 컬러(RGB) 스트림
- 따라서 **현재 RGB 입력 장치는 `/dev/video4`로 확정**

### Jetson 로컬 테스트
아래 명령으로 Jetson 로컬에서 컬러 영상이 정상 출력됨:


gst-launch-1.0 v4l2src device=/dev/video4 ! videoconvert ! autovideosink

즉:

카메라 입력 자체는 정상
/dev/video4는 실제 RGB 스트림으로 사용 가능
네트워크 관련
Jetson과 Windows PC는 같은 WiFi에 연결 가능
방화벽을 끄면 양방향 ping 가능
즉, 네트워크 레벨의 기본 통신은 가능
지금까지 시도한 것
UDP/RTP 전송 시도

Jetson에서 GStreamer 기반으로 H264 RTP/UDP 송신을 시도했고,
Jetson 측 송신 파이프라인 자체는 실행되었음.

예시:

gst-launch-1.0 -v \
  v4l2src device=/dev/video4 ! \
  video/x-raw,width=640,height=480,framerate=30/1 ! \
  videoconvert ! \
  x264enc tune=zerolatency speed-preset=ultrafast bitrate=1000 key-int-max=30 ! \
  rtph264pay pt=96 config-interval=1 ! \
  udpsink host=WINDOWS_IP port=5000 sync=false async=false

하지만 Windows 수신 측(VLC/GStreamer) 디버깅에 시간이 많이 들었고,
이 방식은 최종 목표인 RTSP 서버 구조와 직접적으로 일치하지 않으므로 더 파지 않기로 결정했다.

현재 판단

UDP unicast 방식은 테스트용으로는 의미가 있었지만,
최종 목표는 아래와 같은 구조이므로 바로 RTSP 서버 구현으로 넘어가는 것이 맞다.

목표 구조
RealSense (/dev/video4 RGB)
  -> Jetson
    -> RTSP server
      -> 외부 클라이언트(VLC, ffplay, 앱 등) 접속

즉:

현재의 Jetson -> 특정 PC로 push 구조가 아니라
클라이언트 -> Jetson RTSP 서버에 접속 구조로 가야 한다
요구사항
1. 1차 목표
/dev/video4를 입력으로 사용
Jetson에서 RTSP 서버를 실행
외부 PC에서 RTSP URL로 접속 가능
우선은 RGB-only
노코드/저코드 방식 우선 가능하면 좋지만, 필요하면 구현해도 됨
2. 2차 목표
이 RTSP 서버를 Docker 컨테이너로 패키징
Jetson 부팅 후 서비스처럼 재실행 가능하게 만들고 싶음
3. 장기 목표
나중에 depth, 기타 metadata 확장 가능성 고려
하지만 현재는 depth를 구현하지 않음
현재 단계에서 중요한 것은 RGB 스트리밍 서버를 안정적으로 여는 것
비요구사항 / 지금 하지 않을 것

아래는 지금 단계에서 하지 않음:

depth 스트림 송출
point cloud
color-depth alignment
ROS2 도입
AI inference 연동
다중 데이터 채널 설계
Windows 수신용 UDP/RTP 추가 디버깅
아키텍처 방향

현재 판단으로는 아래 방향이 적절함:

권장 방향
Jetson host에서 /dev/video4를 입력으로 사용
RTSP 서버 구성
이후 동일 구성을 Docker로 감싸기
이유
/dev/video4가 이미 검증됨
UDP는 특정 클라이언트 대상 전송 느낌이 강함
RTSP가 이후 구조 확장 및 운영 관점에서 더 적합함
Docker는 배포/재시작/환경고정 측면에서 유리함
구현 시 고려사항
카메라 입력
현재 입력 장치는 /dev/video4
입력 포맷은 GStreamer/V4L2 기준으로 처리 가능해야 함
필요 시 videoconvert 사용
해상도 / fps

초기값은 보수적으로 시작하는 것이 좋음:

640x480
30fps

이유:

안정성 우선
나중에 성능 튜닝 가능
인코딩

초기에는 H.264 사용이 적절함

예상 이유:

VLC 등 범용 클라이언트 호환성
대역폭 절약
RTSP에서 일반적으로 사용하기 쉬움
클라이언트 접속

최종적으로 아래 같은 URL로 접속 가능한 형태를 원함:

rtsp://JETSON_IP:PORT/stream
Codex에 기대하는 작업

다음 작업을 수행해주면 됨:

1. RTSP 서버 방식 제안

아래 중 어떤 방식이 가장 적합한지 제안:

GStreamer 기반 RTSP server
MediaMTX 등 외부 RTSP 서버 + publish 구조
기타 Jetson에서 운용 쉬운 방법
2. 가장 단순한 1차 구현

다음을 만족하는 최소 구현:

/dev/video4 입력
H264 인코딩
RTSP로 publish 또는 serve
외부 PC에서 VLC로 확인 가능
3. 실행 방법 문서화
Jetson에서 필요한 패키지
실행 명령
접속 URL
테스트 방법
4. Docker화 가능한 구조 제안

다음도 함께 고려:

/dev/video4를 컨테이너에 전달하는 방법
포트 노출
자동 재시작 가능한 실행 구조
Dockerfile / docker-compose 또는 대안
기술적 제약 / 선호
선호
처음에는 단순하고 검증하기 쉬운 구조
너무 많은 구성 요소는 피하고 싶음
우선 성공하는 경로가 중요
나중에 Docker로 옮기기 쉬워야 함
제약
사용자는 이미지 처리/컴퓨터비전 배경지식이 많지 않음
따라서 구조가 너무 복잡하면 유지가 어려움
현재는 RGB-only로 충분
depth는 나중에 별도 채널로 붙이는 것이 더 적절하다고 판단 중
성공 기준

아래가 되면 1차 성공:

Jetson에서 RealSense /dev/video4를 입력으로 잡는다
RTSP 서버가 올라간다
같은 네트워크의 PC에서 VLC로 접속 가능하다
영상이 안정적으로 보인다

예시:

VLC -> rtsp://JETSON_IP:8554/stream
추가 메모
UDP/RTP 직접 전송은 디버깅 비용 대비 현재 목표와 직접 연결성이 낮아 중단
RTSP 서버 구조로 바로 넘어가는 것이 맞다고 판단
이후 Docker 패키징이 중요
장기적으로는:
RGB = RTSP
depth / metadata = 별도 채널
구조를 염두에 두고 있음
하지만 지금 단계에서는 depth 확장을 구현 요구사항에 포함하지 않음