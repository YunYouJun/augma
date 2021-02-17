<template>
  <transition
    name="agm-notification-fade"
    @before-leave="onClose"
    @after-leave="$emit('destroy')"
  >
    <div
      v-show="visible"
      :id="id"
      :class="['agm-notification', horizontalClass]"
      :style="styles"
      role="alert"
      @mouseenter="clearTimer()"
      @mouseleave="startTimer()"
      @click="onClick"
    >
      <div class="agm-notification__group">
        <i
          v-if="type || icon"
          class="agm-notification__icon"
          :class="[typeClass]"
        >
          <slot name="icon"></slot>
        </i>

        <div class="agm-notification__title">{{ title }}</div>
        <div class="agm-notification__content">
          <slot>
            <p v-html="message"></p>
          </slot>
        </div>
        <div
          v-if="showClose"
          class="agm-notification__closeBtn"
          @click.stop="close"
        >
          <!-- <i-carbon-close /> -->
        </div>
      </div>
    </div>
  </transition>
</template>

<script lang="ts">
import {
  defineComponent,
  computed,
  ref,
  onMounted,
  onBeforeUnmount,
  CSSProperties,
} from "vue";
// notificationVM is an alias of vue.VNode
import { EVENT_CODE } from "@augma/utils/aria";
import { on, off } from "@augma/utils/dom";

import type { PropType } from "vue";
import type { NotificationVM, Position } from "./notification.type";
import { AgmColorType, TypeMap } from "@augma/shared/src";

export default defineComponent({
  name: "AgmNotification",
  props: {
    duration: {
      type: Number,
      default: 3000,
    },
    id: { type: String, default: "" },
    message: {
      type: [String, Object] as PropType<string | NotificationVM>,
      default: "",
    },
    offset: { type: Number, default: 0 },
    onClick: {
      type: Function as PropType<() => void>,
      default: () => void 0,
    },
    onClose: {
      type: Function as PropType<() => void>,
      required: true,
    },
    position: {
      type: String as PropType<Position>,
      default: "top-right",
    },
    showClose: {
      type: Boolean,
      default: false,
    },
    title: {
      type: String,
      default: "",
    },
    icon: {
      type: String,
      default: "",
    },
    color: {
      type: String,
      default: "black",
    },
    /**
     * type for notification
     */
    type: { type: String as PropType<AgmColorType>, default: "default" },
    zIndex: { type: Number, default: 0 },
  },
  emits: ["destroy"],

  setup(props) {
    const visible = ref(false);
    let timer: any = null;

    const typeClass = computed(() => {
      const type = props.type;
      return type && TypeMap[type] ? `el-icon-${TypeMap[type]}` : "";
    });

    const horizontalClass = computed(() => {
      return props.position.indexOf("right") > 1 ? "right" : "left";
    });

    const verticalProperty = computed(() => {
      return props.position.startsWith("top") ? "top" : "bottom";
    });

    const styles = computed(() => {
      return {
        "--agm-icon-color": props.color,
        [verticalProperty.value]: `${props.offset}px`,
      } as CSSProperties;
    });

    function startTimer() {
      if (props.duration > 0) {
        timer = setTimeout(() => {
          if (visible.value) {
            close();
          }
        }, props.duration);
      }
    }

    function clearTimer() {
      if (!timer) return;
      clearTimeout(timer);
      timer = null;
    }

    function close() {
      visible.value = false;
    }

    function onKeydown({ code }: KeyboardEvent) {
      if (code === EVENT_CODE.delete || code === EVENT_CODE.backspace) {
        clearTimer(); // press delete/backspace clear timer
      } else if (code === EVENT_CODE.esc) {
        // press esc to close the notification
        if (visible.value) {
          close();
        }
      } else {
        startTimer(); // resume timer
      }
    }

    // lifecycle
    onMounted(() => {
      startTimer();
      visible.value = true;
      on(document, "keydown", onKeydown);
    });

    onBeforeUnmount(() => {
      off(document, "keydown", onKeydown);
    });

    return {
      visible,

      horizontalClass,
      typeClass,
      styles,

      close,
      clearTimer,
      startTimer,
    };
  },
});
</script>
