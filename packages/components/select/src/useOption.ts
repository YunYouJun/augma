import { inject, InjectionKey } from "vue";
export interface ISelectOption {
  label: string;
  value: any;
}
export interface SelectContext {
  props: {
    placeholder: string;
  };
  handleOptionSelect(val: ISelectOption): void;
}

export const selectKey = ("AgmSelect" as unknown) as InjectionKey<SelectContext>;

export function useOption(props) {
  const select = inject(selectKey);

  return { select };
}
