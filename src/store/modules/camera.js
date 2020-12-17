const state = () => {
  videoEl: null;
  settings: null;
  display: true;
  flipScreen: false;
  front: false;
};

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
};

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
};
