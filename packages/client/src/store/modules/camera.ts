export interface State {
  videoEl: HTMLVideoElement | null;
  settings: any;
  display: boolean;
  flipScreen: boolean;
  front: boolean;
  /**
   * 缩放比例
   */
  ratio: number;
}

const state = (): State => ({
  videoEl: null,
  settings: null,
  display: false,
  flipScreen: false,
  front: false,

  ratio: 1,
});

const mutations = {
  setVideoEl(state, el) {
    state.videoEl = el;
  },
  setSettings(state, settings) {
    state.settings = settings;
  },
  toggleDisplay(state) {
    state.display = !state.display;
  },
  toggleFlipScreen(state) {
    state.flipScreen = !state.flipScreen;
  },
  toggleFront(state) {
    state.front = !state.front;
  },

  setRatio(state, val) {
    state.ratio = val;
  },
};

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
};
