declare module "*.vue" {
  import { defineComponent } from "vue";
  const component: ReturnType<typeof defineComponent>;
  export default component;
}

// index
declare type Indexable<T> = {
  [key: string]: T;
};

declare type TimeoutHandle = ReturnType<typeof global.setTimeout>;
