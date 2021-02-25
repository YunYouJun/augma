import { ref } from "vue";

interface WebcamOptions {
  /**
   * whether to use the front camera
   */
  isFront: boolean;
}

/**
 * https://developer.mozilla.org/zh-CN/docs/Web/API/MediaDevices/getUserMedia
 * @param target
 * @param options
 */
export function useWebcam(
  target: HTMLVideoElement,
  options: WebcamOptions = {
    isFront: false,
  }
) {
  const targetRef = ref(
    target || (document.querySelector("#webcam") as HTMLVideoElement)
  );
  const isFront = ref(options.isFront);

  let constraints = ref<MediaStreamConstraints>({
    video: {
      width: { min: 640, ideal: 1280, max: 1920 },
      height: { min: 480, ideal: 720, max: 1080 },
      facingMode: isFront ? "user" : "environment",
    },
  });

  const settings = ref<MediaTrackSettings | null>(null);

  /**
   * change webcam stream (default is video)
   */
  async function changeWebcamStream(isFront = options.isFront) {
    (constraints.value.video as MediaTrackConstraints).facingMode = isFront
      ? "user"
      : "environment";

    const stream = await navigator.mediaDevices.getUserMedia(constraints.value);
    settings.value = stream.getVideoTracks()[0].getSettings();

    if (targetRef.value) {
      const videoEl = targetRef.value;
      videoEl.srcObject = stream;
      // autoplay
      videoEl.onloadedmetadata = () => {
        videoEl.play();
      };
    }
  }

  return {
    isFront,
    settings,
    changeWebcamStream,
  };
}
