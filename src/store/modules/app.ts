const state = () => ({
  subwayMap: false,
  weather: false,
});

const mutations = {
  setSubwayMap(state, status) {
    state.subwayMap = status;
  },
  toggleSubwayMap(state) {
    state.subwayMap = !state.subwayMap;
  },
  toggleWeather(state) {
    state.weather = !state.weather;
  },
};

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
};
