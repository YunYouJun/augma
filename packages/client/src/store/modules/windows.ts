const state = () => ({
  browser: false,
})

const mutations = {
  setBrowser(state, value) {
    state.browser = value
  },
  toggleBrowser(state) {
    state.browser = !state.browser
  },
}

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
}
