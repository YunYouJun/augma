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
      width: 1920,
      height: 1080,
      facingMode: front ? "user" : "environment",
    },
  };
  const stream = await navigator.mediaDevices.getUserMedia(constraints);
  const settings = stream.getVideoTracks()[0].getSettings();
  videoEl.srcObject = stream;
  // autoplay
  videoEl.onloadedmetadata = () => {
    videoEl.play();
  };
  return settings;
}
