import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import {
  AgmButton,
  AgmDialog,
  AgmHudGauge,
  AgmHudProgress,
  AgmInput,
  AgmPanel,
  AgmSelect,
  AgmSwitch,
  AgmToast,
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
  it('keeps the switch name in sync when its label changes', async () => {
    const wrapper = mount(AgmSwitch, { props: { label: '语音播报' } })
    expect(wrapper.get('[role="switch"]').attributes('aria-label')).toBe('语音播报')
    await wrapper.setProps({ label: 'Spoken feedback' })
    expect(wrapper.get('[role="switch"]').attributes('aria-label')).toBe('Spoken feedback')
  })
  it('retains field hints and external descriptions when validation changes', async () => {
    const wrapper = mount(AgmInput, {
      props: { id: 'name', label: '名称', hint: '用于识别设备' },
      attrs: { 'aria-describedby': 'external-help', 'required': true },
    })
    const input = wrapper.get('input')
    expect(input.attributes('aria-describedby')).toBe('external-help name-hint')
    await wrapper.setProps({ error: '请输入名称' })
    expect(input.attributes('aria-invalid')).toBe('true')
    expect(input.attributes('aria-describedby')).toBe('external-help name-hint name-error')
    await wrapper.setProps({ error: undefined })
    expect(input.attributes('aria-invalid')).toBe('false')
    expect(input.attributes('aria-describedby')).toBe('external-help name-hint')
    expect(wrapper.find('#name-error').exists()).toBe(false)
    expect(input.attributes('required')).toBeDefined()
  })
  it('forwards select attributes and connects labels, hints and validation to its trigger', async () => {
    const wrapper = mount(AgmSelect, {
      props: {
        id: 'mode',
        label: '模式',
        hint: '选择可用模式',
        error: '请选择模式',
        required: true,
        options: [{ label: '专注', value: 'focus' }],
      },
      attrs: { 'aria-describedby': 'external-help', 'data-field': 'mode', 'class': 'custom-field', 'style': 'max-width: 300px' },
    })
    const trigger = wrapper.get('[role="combobox"]')
    expect(trigger.attributes('id')).toBe('mode')
    expect(wrapper.get('label').attributes('for')).toBe('mode')
    expect(trigger.attributes('aria-labelledby')).toBe('mode-label')
    expect(trigger.attributes('data-field')).toBe('mode')
    expect(wrapper.classes()).toContain('custom-field')
    expect(wrapper.attributes('style')).toContain('max-width: 300px')
    expect(trigger.classes()).not.toContain('custom-field')
    expect(trigger.attributes('aria-required')).toBe('true')
    expect(trigger.attributes('aria-invalid')).toBe('true')
    expect(trigger.attributes('aria-describedby')).toBe('external-help mode-hint mode-error')
    await wrapper.setProps({ error: undefined, hint: undefined })
    expect(trigger.attributes('aria-describedby')).toBe('external-help')
    expect(trigger.attributes('aria-invalid')).toBe('false')
    expect(wrapper.find('#mode-error').exists()).toBe(false)
  })
  it('renders panel actions without requiring a heading and keeps its footer separate', () => {
    const wrapper = mount(AgmPanel, {
      slots: { default: '内容', actions: '<button>刷新</button>', footer: '<button>保存</button>' },
    })
    expect(wrapper.get('header').text()).toBe('刷新')
    expect(wrapper.find('h2').exists()).toBe(false)
    expect(wrapper.get('footer').text()).toBe('保存')
    expect(wrapper.text()).toContain('内容')
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
  it('lets consumers replace the indeterminate progress text', async () => {
    const progress = mount(AgmHudProgress, { props: { label: 'Connecting' } })
    const readout = () => progress.findAll('.agm-progress-label span')[1]!.text()
    expect(readout()).toBe('进行中')
    await progress.setProps({ indeterminateText: 'In progress' })
    expect(readout()).toBe('In progress')
    await progress.setProps({ value: 40 })
    expect(readout()).toBe('40%')
  })
  it('lets consumers replace the select placeholder', async () => {
    const select = mount(AgmSelect, { props: { label: 'Mode', options: [{ label: 'Focus', value: 'focus' }] } })
    expect(select.get('[role="combobox"]').text()).toBe('请选择')
    await select.setProps({ placeholder: 'Select a mode' })
    expect(select.get('[role="combobox"]').text()).toBe('Select a mode')
  })
  // Dialog and Toast render into portals on document.body.
  it('lets consumers rename the dialog close button', async () => {
    const dialog = mount(AgmDialog, { props: { open: true, title: 'Device settings', description: 'Rename the device.' }, attachTo: document.body })
    await flushPromises()
    const dialogClose = () => document.querySelector('.agm-dialog .agm-dialog-close')!
    expect(dialogClose().getAttribute('aria-label')).toBe('关闭对话框')
    await dialog.setProps({ closeLabel: 'Close dialog' })
    expect(dialogClose().getAttribute('aria-label')).toBe('Close dialog')
    dialog.unmount()
  })
  it('lets consumers rename the toast close button and notification region', async () => {
    const toast = mount(AgmToast, { props: { open: true, title: 'Settings saved' }, attachTo: document.body })
    await flushPromises()
    const toastClose = () => document.querySelector('.agm-toast .agm-dialog-close')!
    const region = () => document.querySelector('[role="region"]')!
    expect(toastClose().getAttribute('aria-label')).toBe('关闭通知')
    expect(region().getAttribute('aria-label')).toBe('通知（F8）')
    await toast.setProps({ closeLabel: 'Close notification', regionLabel: 'Notifications (F8)' })
    expect(toastClose().getAttribute('aria-label')).toBe('Close notification')
    expect(region().getAttribute('aria-label')).toBe('Notifications (F8)')
    toast.unmount()
  })
  it('clamps gauge values and derives tone from the remaining share', async () => {
    const wrapper = mount(AgmHudGauge, { props: { label: '电量', value: 86 } })
    expect(wrapper.attributes('role')).toBe('meter')
    expect(wrapper.attributes('aria-label')).toBe('电量')
    expect(wrapper.attributes('aria-valuetext')).toBe('86 / 100')
    expect(wrapper.attributes('data-tone')).toBe('success')
    await wrapper.setProps({ value: 25, max: 50 })
    expect(wrapper.attributes('aria-valuemax')).toBe('50')
    expect(wrapper.attributes('data-tone')).toBe('warning')
    await wrapper.setProps({ value: 10 })
    expect(wrapper.attributes('data-tone')).toBe('danger')
    expect(wrapper.attributes('style')).toContain('--agm-gauge-value: 20%')
    await wrapper.setProps({ value: 120 })
    expect(wrapper.attributes('aria-valuenow')).toBe('50')
    await wrapper.setProps({ value: Number.NaN, max: -1 })
    expect(wrapper.attributes('aria-valuenow')).toBe('0')
    expect(wrapper.attributes('aria-valuemax')).toBe('100')
    expect(wrapper.get('.agm-gauge-readout').text()).toBe('0 / 100')
  })
})
