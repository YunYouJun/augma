/**
 * 改变 WebCam 流
 * @param videoEl Video Element
 * @param front 是否使用前置摄像头
 */
export async function changeWebcamStream(
  videoEl: HTMLVideoElement,
  front = false
) {
  const constraints = {
    video: {
      facingMode: front ? "user" : "environment",
    },
  };
  const stream = await navigator.mediaDevices.getUserMedia(constraints);
  videoEl.srcObject = stream;
  // autoplay
  // videoEl.onloadedmetadata = () => {
  //   videoEl.play();
  // };
}
