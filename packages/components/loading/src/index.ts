import { createVNode, nextTick, render } from "vue";
import AgmLoading from "./index.vue";
import type { ILoadingOptions } from "./loading.type";

let LoadingContainer = null;

const Loading = function (options: ILoadingOptions = {}) {
  // options = {
  //   ...options,
  // };
  // let vm = createVNode(AgmLoading, options);
  // const container = document.createElement("div");
  // container.className = "agm-loading-container";
  // // container.id = "agm-loading-container";
  // container.style.zIndex = "9999";
  // console.log(container);
  // // LoadingContainer = container;
  // return {
  //   $el: container,
  //   open: () => {
  //     render(vm, container);
  //     // document.body.appendChild(this.$el);
  //   },
  //   close: () => {
  //     console.log(LoadingContainer);
  //     const $el = LoadingContainer;
  //     nextTick(() => {
  //       document.body.removeChild($el);
  //     });
  //   },
  // };
};

export default Loading;
