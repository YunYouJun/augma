import type { InjectionKey } from 'vue'
import { ComponentSize } from '@augma/shared'

export interface AgmFormContext {
  registerLabelWidth(width: number, oldWidth: number): void
  deregisterLabelWidth(width: number): void
  autoLabelWidth: string | undefined
  emit: (evt: string, ...args: any[]) => void
  labelSuffix: string
  inline?: boolean
  model?: Record<string, unknown>
  size?: string
  showMessage?: boolean
  labelPosition?: string
  labelWidth?: string
  rules?: Record<string, unknown>
  statusIcon?: boolean
  hideRequiredAsterisk?: boolean
  disabled?: boolean
}

export interface AgmFormItemContext {
  prop?: string
  size: ComponentSize
  validateState: string
  updateComputedLabelWidth(width: number): void
  addValidateEvents(): void
  removeValidateEvents(): void
  resetField(): void
  clearValidate(): void
}

// provide form ctx
// TODO: change it to symbol
export const agmFormKey: InjectionKey<AgmFormContext> = 'agmForm' as any

export const agmFormItemKey: InjectionKey<AgmFormItemContext> = 'agmFormItem' as any
