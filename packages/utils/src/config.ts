import type { ComponentSize } from "@augma/shared";

export interface InstallOptions {
  size: ComponentSize;
  zIndex: number;
}

export type AugmaOptions = InstallOptions;

let $AUGMA = {} as InstallOptions;

const setConfig = (option: InstallOptions): void => {
  $AUGMA = option;
};

const getConfig = (key: keyof InstallOptions): unknown => {
  return $AUGMA[key];
};

export { getConfig, setConfig };
