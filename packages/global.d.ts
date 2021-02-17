import { ComponentOptions } from "vue";
declare module "*.vue" {
  const Component: ComponentOptions;
  export default Component;
}

declare module "*.md" {
  const Component: ComponentOptions;
  export default Component;
}

// index
declare type Indexable<T> = {
  [key: string]: T;
};

// vuex
import { Store } from "vuex";

declare module "@vue/runtime-core" {
  // Declare your own store states.
  interface State {
    count: number;
  }

  interface ComponentCustomProperties {
    $store: Store<State>;

    $notify: any;
  }
}
