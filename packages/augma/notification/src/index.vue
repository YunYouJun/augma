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
        <div class="agm-notification__closeBtn"></div>
      </div>
    </div>
  </transition>
</template>

<script lang="ts">
import AgmIcon from "../../icon/index.vue";

import { defineComponent, PropType, ref } from "vue";
import type { NotificationVM } from "./notification.type";
import { on, off } from "../../utils/dom";
import { EVENT_CODE } from "../../utils/aria";

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
      default: true,
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
        on(this.$el, "transitionend", this.destroyElement);
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
  methods: {
    /**
     * Delete Element
     */
    destroyElement() {
      this.visible = false;
      off(this.$el, "transitionend", this.destroyElement);
      this.onClose();
    },
    startTimer() {
      if (this.duration > 0) {
        this.timer = setTimeout(() => {
          if (this.closed) {
            this.close();
          }
        }, this.duration);
      }
    },
    clearTimer() {
      clearTimeout(this.timer);
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

<style lang="scss">
@import "../../../theme/variables/index.scss";
.agm-notification {
  display: flex;
  width: 12rem;
  height: 3rem;
  position: fixed;
  background-color: white;
  box-shadow: $box-shadow-light;
  border-radius: 5px;
  transition: opacity 0.3s, transform 0.3s, left 0.3s, right 0.3s, top 0.4s,
    bottom 0.3s;
  z-index: 9999;

  &.right {
    right: 1.5rem;
  }

  &.left {
    left: 1.5rem;
  }

  &__icon {
    position: absolute;
    display: flex;
    align-items: center;
    justify-self: center;
    // position: absolute;

    background-color: var(--agm-icon-color);
    border-radius: 2px;
    padding: 2px;
    color: white;
    left: -14px;
    box-shadow: 0 0 2px var(--agm-icon-color);
  }

  &__group {
    position: relative;
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding-left: 1.5rem;
  }

  &__title {
    font-weight: bold;
    font-size: 1rem;
  }

  &__content {
    color: gray;
    font-size: 12px;

    p {
      margin: 0;
      width: 10rem;
      overflow: hidden;
      text-overflow: ellipsis;
    }
  }

  &-fade {
    &-enter-from {
      &.right {
        right: 0;
        transform: translateX(100%);
      }

      &.left {
        left: 0;
        transform: translateX(-100%);
      }
    }

    &-leave-to {
      opacity: 0;
    }
  }
}
</style>
