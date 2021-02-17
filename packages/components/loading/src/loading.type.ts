export type ILoadingOptions = {
  background?: string;
  fullscreen?: boolean;
  body?: boolean;
  lock?: boolean;
  customClass?: string;
  visible?: boolean;
  target?: string | HTMLElement;
};

export type ILoadingCreateComponentParams = {
  options: ILoadingOptions;
};
