import type { PropType } from 'vue'
import type { Nullable } from '@augma/types'
import type {
  Placement,
  Instance as PopperInstance,
  Options as PopperOptions,
} from '@popperjs/core'

export type { PopperInstance }
export type TriggerType = 'click' | 'hover' | 'focus'
export type Trigger = TriggerType | TriggerType[]
export const DEFAULT_TRIGGER = 'hover'

const PopperProps = {
  disabled: {
    type: Boolean,
    default: false,
  },
  placement: {
    type: String as PropType<Placement>,
    default: 'bottom' as Placement,
  },
  popperOptions: {
    type: Object as PropType<PopperOptions>,
    default: () => null,
  },
  trigger: {
    type: [String, Array] as PropType<Trigger>,
    default: DEFAULT_TRIGGER,
  },
  visible: {
    type: Boolean,
    default: undefined,
  },
}
export default PopperProps

export interface IPopperOptions {
  disabled: boolean
  placement: Placement
  popperOptions: PopperOptions
  trigger: Trigger
  visible: boolean
}

export type RefElement = Nullable<HTMLElement>
