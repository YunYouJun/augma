<template>
  <transition name="agm-notification-fade">
    <div
      v-show="visible"
      :id="id"
      :class="['agm-notification', horizontalClass]"
      :style="styles"
      role="alert"
      @mouseenter="clearTimer()"
      @mouseleave="startTimer()"
      @click="click"
    >
      <div class="agm-notification__group">
        <i
          v-if="type || icon"
          class="agm-notification__icon"
          :class="[typeClass]"
        >
          <agm-icon :icon="icon"></agm-icon>
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
          <agm-icon :icon="icons.mdiClose"></agm-icon>
        </div>
      </div>
    </div>
  </transition>
</template>

<script lang="ts">
import AgmIcon from "../../icon/index.vue";

import { defineComponent, PropType, ref } from "vue";
import type { NotificationVM } from "./notification.type";
import { on, off } from "../../../utils/dom";
import { EVENT_CODE } from "../../../utils/aria";

import { mdiClose } from "@mdi/js";

const TypeMap: Indexable<string> = {
  success: "success",
  info: "info",
  warning: "warning",
  error: "error",
};

type PositionType = "top-right" | "top-left" | "bottom-right" | "bottom-left";

export default defineComponent({
  name: "AgmNotification",
  components: {
    AgmIcon,
  },
  data() {
    return {
      icons: {
        mdiClose,
      },
    };
  },
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
      type: String as PropType<PositionType>,
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
    type: { type: String, default: "" },
    zIndex: { type: Number, default: 0 },
  },
  emits: ["close", "click"],
  setup(props) {
    const visible = ref(false);
    const closed = ref(false);
    const timer = ref(null);

    return {
      visible,
      closed,
      timer,
    };
  },
  computed: {
    typeClass() {
      const type = this.type;
      return type && TypeMap[type] ? `agm-icon-${TypeMap[type]}` : "";
    },
    horizontalClass() {
      return this.position.indexOf("right") > 1 ? "right" : "left";
    },
    verticalProperty() {
      return this.position.startsWith("top") ? "top" : "bottom";
    },
    styles() {
      return {
        "--agm-icon-color": this.color,
        [this.verticalProperty]: `${this.offset}px`,
      };
    },
  },
  watch: {
    closed(newVal: boolean) {
      if (newVal) {
        this.visible = false;
        this.destroyElement();
      }
    },
  },
  mounted() {
    if (this.duration > 0) {
      this.timer = setTimeout(() => {
        if (!this.closed) {
          this.close();
        }
      }, this.duration);
    }
    this.visible = true;
    on(document, "keydown", this.keydown);
  },
  beforeUnmount() {
    off(document, "keydown", this.keydown);
  },
  methods: {
    /**
     * Delete Element
     * do not need on transitionend
     */
    destroyElement() {
      this.visible = false;
      this.onClose();
    },
    startTimer() {
      if (this.duration > 0) {
        this.timer = setTimeout(() => {
          if (!this.closed) {
            this.close();
          }
        }, this.duration);
      }
    },
    clearTimer() {
      clearTimeout(this.timer);
      this.timer = null;
    },
    click() {
      this?.onClick();
    },
    close() {
      this.closed = true;
      this.timer = null;
    },
    /**
     * shortcut to close notification
     */
    keydown({ code }: KeyboardEvent) {
      if (code === EVENT_CODE.delete || code === EVENT_CODE.backspace) {
        this.clearTimer();
      } else if (code === EVENT_CODE.esc) {
        if (!this.closed) {
          this.close();
        }
      } else {
        this.startTimer();
      }
    },
  },
});
</script>
