import { inject } from "vue";

export const selectKey = "AgmSelect";

export function useOption(props) {
  const select = inject(selectKey);

  return { select };
}
