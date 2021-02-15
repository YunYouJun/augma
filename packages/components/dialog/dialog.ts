import { UPDATE_MODEL_EVENT } from "@augma/utils/constants";
import { Ref, SetupContext } from "vue";
export { UPDATE_MODEL_EVENT };

export interface DialogProps {
  modelValue: boolean;
}

export default function (
  props: DialogProps,
  ctx: SetupContext,
  targetRef: Ref<HTMLElement | null>
) {
  return {};
}
