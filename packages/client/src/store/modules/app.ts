const state = () => ({
  loading: false,
  subwayMap: false,
  weather: false,
  yolo: false,
});

const mutations = {
  setLoading(state, val) {
    state.loading = val;
  },
  setSubwayMap(state, status) {
    state.subwayMap = status;
  },
  toggleSubwayMap(state) {
    state.subwayMap = !state.subwayMap;
  },
  toggleWeather(state) {
    state.weather = !state.weather;
  },
  toggleYolo(state) {
    state.yolo = !state.yolo;
  },
};

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
};
