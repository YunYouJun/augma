// Editorial descriptions only. Types and defaults are extracted from Vue source.
export const components = [
  {
    slug: 'button',
    name: 'AgmButton',
    title: 'Button 按钮',
    group: '基础',
    description: '轻触，即刻响应。用于触发操作与状态切换。',
    props: [
      {
        name: 'variant',
        description: '视觉层级',
      },
      {
        name: 'disabled',
        description: '禁止操作',
      },
      {
        name: 'loading',
        description: '处理中，同时禁止重复操作',
      },
      {
        name: 'type',
        description: '原生按钮类型',
      },
    ],
    slots: ['default：按钮文字'],
    keyboard: 'Tab 聚焦；Enter 或 Space 激活。加载中与禁用状态不接受操作。',
    registry: true,
  },
  {
    slug: 'icon-button',
    name: 'AgmIconButton',
    title: 'IconButton 图标按钮',
    group: '基础',
    description: '圆形操作入口，为图标提供明确的可访问名称。',
    props: [
      {
        name: 'label',
        description: '可访问名称',
      },
      {
        name: 'disabled',
        description: '禁止操作',
      },
      {
        name: 'pressed',
        description: '可选的切换状态',
      },
    ],
    slots: ['default：图标，默认加号'],
    keyboard: 'Tab 聚焦；Enter 或 Space 激活。label 必须描述动作。',
  },
  {
    slug: 'input',
    name: 'AgmInput',
    title: 'Input 输入框',
    group: '基础',
    description: '清晰的标签与错误信息，让输入始终有方向。',
    props: [
      { name: 'id', description: '可选的输入元素 ID，默认自动生成' },
      {
        name: 'modelValue',
        description: '通过 v-model 更新',
      },
      {
        name: 'label',
        description: '可见标签',
      },
      {
        name: 'error',
        description: '错误说明',
      },
      {
        name: 'disabled',
        description: '禁止输入',
      },
      {
        name: 'type',
        description: '原生输入类型',
      },
    ],
    events: ['update:modelValue(string)'],
    keyboard:
      '使用原生输入键盘行为。placeholder、name、autocomplete、required 等属性传递到 input。',
    registry: true,
  },
  {
    slug: 'select',
    name: 'AgmSelect',
    title: 'Select 选择器',
    group: '控制',
    description: '在清晰的选项列表中做出选择。',
    props: [
      {
        name: 'modelValue',
        description: '通过 v-model 更新',
      },
      {
        name: 'label',
        description: '可见标签',
      },
      {
        name: 'options',
        description: 'value 必须为非空且唯一的字符串',
      },
      {
        name: 'placeholder',
        description: '未选择提示',
      },
      {
        name: 'disabled',
        description: '禁止选择',
      },
      {
        name: 'name',
        description: '表单字段名',
      },
    ],
    events: ['update:modelValue(string)'],
    keyboard:
      'Enter / Space 打开，方向键移动，Enter 选择，Escape 关闭；支持字符搜索。',
  },
  {
    slug: 'switch',
    name: 'AgmSwitch',
    title: 'Switch 开关',
    group: '控制',
    description: '即时切换一个明确的二元状态。',
    props: [
      {
        name: 'modelValue',
        description: '通过 v-model 更新',
      },
      {
        name: 'label',
        description: '可见标签',
      },
      {
        name: 'disabled',
        description: '禁止切换',
      },
      {
        name: 'name',
        description: '表单字段名',
      },
    ],
    events: ['update:modelValue(boolean)'],
    keyboard: 'Tab 聚焦，Space 或 Enter 切换。',
  },
  {
    slug: 'slider',
    name: 'AgmSlider',
    title: 'Slider 滑块',
    group: '控制',
    description: '以连续反馈调整数值，支持触控与键盘。',
    props: [
      {
        name: 'modelValue',
        description: '通过 v-model 更新',
      },
      {
        name: 'label',
        description: '可见标签',
      },
      {
        name: 'min',
        description: '最小值',
      },
      {
        name: 'max',
        description: '最大值，应大于 min',
      },
      {
        name: 'step',
        description: '正数步长',
      },
      {
        name: 'disabled',
        description: '禁止调整',
      },
      {
        name: 'name',
        description: '表单字段名',
      },
    ],
    events: ['update:modelValue(number)'],
    keyboard:
      '方向键按步长调节，Home / End 到达边界，Page Up / Down 大步调节。',
  },
  {
    slug: 'dialog',
    name: 'AgmDialog',
    title: 'Dialog 对话框',
    group: '反馈',
    description: '让注意力聚焦在当前操作，完成后回到原处。',
    props: [
      {
        name: 'open',
        description: '通过 v-model:open 更新',
      },
      {
        name: 'title',
        description: '可访问标题',
      },
      {
        name: 'description',
        description: '操作说明',
      },
    ],
    events: ['update:open(boolean)'],
    slots: ['trigger：单个可聚焦触发元素', 'default：内容', 'footer：操作区'],
    keyboard:
      '打开后焦点进入对话框，Tab 循环，Escape 关闭并返回触发器。推荐使用 trigger 插槽保证焦点返回。',
    registry: true,
  },
  {
    slug: 'tooltip',
    name: 'AgmTooltip',
    title: 'Tooltip 提示',
    group: '反馈',
    description: '为可聚焦操作补充简短说明。',
    props: [
      {
        name: 'text',
        description: '提示内容',
      },
      {
        name: 'delay',
        description: '悬停延迟（毫秒）',
      },
    ],
    slots: ['default：单个可聚焦触发元素'],
    keyboard:
      '悬停或聚焦触发元素显示，Escape 关闭。触屏必需信息应直接展示，不仅放在提示里。',
  },
  {
    slug: 'toast',
    name: 'AgmToast',
    title: 'Toast 通知',
    group: '反馈',
    description: '对已完成的操作给出轻量、可关闭的反馈。',
    props: [
      {
        name: 'open',
        description: '通过 v-model:open 更新',
      },
      {
        name: 'title',
        description: '通知标题',
      },
      {
        name: 'description',
        description: '补充内容',
      },
      {
        name: 'duration',
        description: '自动关闭时间（毫秒）',
      },
    ],
    events: ['update:open(boolean)'],
    keyboard:
      'F8 聚焦通知区域，Escape 或关闭按钮关闭。悬停或聚焦时暂停倒计时。每个应用建议放置一个 AgmToast。',
  },
  {
    slug: 'panel',
    name: 'AgmPanel',
    title: 'Panel 面板',
    group: 'HUD',
    description: '轻盈的半透明容器，为相关信息建立层次。',
    props: [
      {
        name: 'title',
        description: '面板标题',
      },
    ],
    slots: ['default：内容', 'header：自定义标题', 'actions：标题栏操作'],
    keyboard: '面板本身不接管焦点；内容遵循自然的文档顺序。',
    registry: true,
  },
  {
    slug: 'hud-status',
    name: 'AgmHudStatus',
    title: 'HudStatus 状态',
    group: 'HUD',
    description: '用文字与颜色共同表达状态变化。',
    props: [
      {
        name: 'tone',
        description: '状态语义',
      },
    ],
    slots: ['default：状态文字'],
    keyboard: '使用 role=status 温和播报动态变化；始终提供文字，不单靠颜色。',
    registry: true,
  },
  {
    slug: 'hud-progress',
    name: 'AgmHudProgress',
    title: 'HudProgress 进度',
    group: 'HUD',
    description: '线性或环形进度，让过程清晰可见。',
    props: [
      {
        name: 'label',
        description: '进度名称',
      },
      {
        name: 'value',
        description: '未提供或非有限数值表示不确定进度',
      },
      {
        name: 'max',
        description: '有效上界，非法值回退到 100',
      },
      {
        name: 'variant',
        description: '显示形式',
      },
    ],
    keyboard:
      '只读进度使用 progressbar 语义；数值被约束到 0 到 max，不确定进度不设置 aria-valuenow。',
    registry: true,
  },
]
export const origin = 'https://augma.yunyoujun.cn'
export const version = '0.2.0'
