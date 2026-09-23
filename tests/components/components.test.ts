import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import {
  AgmButton,
  AgmHudProgress,
  AgmInput,
  AgmSwitch,
} from '../../packages/augma/src'

describe('component contracts', () => {
  it('prevents activation during loading', async () => {
    const wrapper = mount(AgmButton, {
      props: { loading: true },
      slots: { default: '保存' },
    })
    expect(wrapper.attributes('disabled')).toBeDefined()
    expect(wrapper.attributes('aria-busy')).toBe('true')
    await wrapper.trigger('click')
    expect(wrapper.emitted('click')).toBeUndefined()
  })
  it('labels the input and associates validation text', async () => {
    const wrapper = mount(AgmInput, {
      props: { id: 'device-name', label: '设备名称', error: '不能为空', modelValue: '' },
      attrs: { 'autocomplete': 'off', 'aria-describedby': 'device-help' },
    })
    const input = wrapper.get('input')
    expect(wrapper.get('label').attributes('for')).toBe(input.attributes('id'))
    expect(input.attributes('id')).toBe('device-name')
    expect(input.attributes('aria-describedby')).toBe('device-help device-name-error')
    expect(input.attributes('autocomplete')).toBe('off')
    await input.setValue('Augma')
    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['Augma'])
  })
  it('keeps switch state controlled by v-model updates', async () => {
    const wrapper = mount(AgmSwitch, {
      props: { label: 'HUD', modelValue: false },
    })
    await wrapper.get('[role="switch"]').trigger('click')
    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual([true])
    await wrapper.setProps({ modelValue: true })
    expect(wrapper.get('[role="switch"]').attributes('aria-checked')).toBe(
      'true',
    )
  })
  it('distinguishes unknown progress from zero and clamps finite values', async () => {
    const wrapper = mount(AgmHudProgress, { props: { label: '同步' } })
    expect(wrapper.attributes('aria-valuenow')).toBeUndefined()
    await wrapper.setProps({ value: 0 })
    expect(wrapper.attributes('aria-valuenow')).toBe('0')
    await wrapper.setProps({ value: 200, max: 80 })
    expect(wrapper.attributes('aria-valuenow')).toBe('80')
    await wrapper.setProps({ value: Number.NaN })
    expect(wrapper.attributes('aria-valuenow')).toBeUndefined()
  })
})
