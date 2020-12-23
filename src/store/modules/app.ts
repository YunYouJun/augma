const state = () => ({
  subwayMap: false,
});

const mutations = {
  setSubwayMap(state, status) {
    state.subwayMap = status;
  },
  toggleSubwayMap(state) {
    state.subwayMap = !state.subwayMap;
  },
};

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
};
