/**
 * 切换全屏
 * @param el
 */
export function toggleFullscreen(el = document.documentElement) {
  if (!document.fullscreenElement) {
    el.requestFullscreen().catch((err: any) => {
      this.$notify({
        type: "error",
        message: "无法进入全屏模式",
      });
    });
  } else {
    document.exitFullscreen();
  }
}
