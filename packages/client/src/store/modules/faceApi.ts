const state = () => ({
  faceDetection: false,
})

const mutations = {
  toggleFaceDetection(state) {
    state.faceDetection = !state.faceDetection
  },
}

export default {
  namespaced: true,
  state,
  mutations,
  actions: {},
}
