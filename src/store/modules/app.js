const state = () => {
  flipScreen: false;
};

const mutations = {
  toggleFlipScreen(state) {
    state.flipScreen = !state.flipScreen;
  },
};

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
};
