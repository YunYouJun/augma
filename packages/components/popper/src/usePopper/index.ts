import { computed, reactive, ref, watch } from "vue";
import { createPopper } from "@popperjs/core";

import type { ComponentPublicInstance, SetupContext, Ref } from "vue";

import type {
  IPopperOptions,
  RefElement,
  TriggerType,
  PopperInstance,
} from "./default";
import { isBool, isHTMLElement } from "@augma/utils/util";
import { WindowEventName } from "@vueuse/core";

export const UPDATE_VISIBLE_EVENT = "update:visible";

// popper trigger element can be component
export type ElementType = ComponentPublicInstance | HTMLElement;

export default function (props: IPopperOptions, ctx: SetupContext) {
  const arrowRef = ref<RefElement>(null);
  const triggerRef = ref<ElementType>(null);
  const popperRef = ref<RefElement>(null);

  let popperInstance: PopperInstance | null;

  const state = reactive({
    visible: !!props.visible,
  });

  // because we do not know if props.visible exist
  const visibility = computed<boolean>({
    get() {
      if (props.disabled) {
        return false;
      } else {
        return isBool(props.visible) ? props.visible : state.visible;
      }
    },
    set(val) {
      isBool(props.visible)
        ? ctx.emit(UPDATE_VISIBLE_EVENT, val)
        : (state.visible = val);
    },
  });

  const popperOptions = computed(() => {
    return props.popperOptions;
  });

  function initializePopper() {
    if (!visibility.value) {
      return;
    }
    const unwrappedTrigger = triggerRef.value;
    const _trigger = isHTMLElement(unwrappedTrigger)
      ? unwrappedTrigger
      : (unwrappedTrigger as ComponentPublicInstance).$el;
    popperInstance = createPopper(
      _trigger,
      popperRef.value,
      popperOptions.value
    );

    popperInstance.update();
  }

  function show() {
    if (props.disabled) return;
    visibility.value = true;
  }

  function hide() {
    if (props.disabled) return;
    visibility.value = false;
  }

  const toggleState = () => {
    if (visibility.value) {
      hide();
    } else {
      show();
    }
  };

  const popperEventsHandler = (e: Event) => {
    e.stopPropagation();
    switch (e.type) {
      case "click":
        toggleState();
        break;
      case "mouseenter":
      case "focus":
        show();
        break;
      case "mouseleave":
      case "blur":
        hide();
        break;
      default:
        break;
    }
  };

  function doDestroy(forceDestroy?: boolean) {
    if (!popperInstance || (visibility.value && !forceDestroy)) return;
    popperInstance?.destroy?.();
    popperInstance = null;
  }

  const events = {};

  const triggerEventsMap: Record<TriggerType, WindowEventName[]> = {
    click: ["click"],
    hover: ["mouseenter", "mouseleave"],
    focus: ["focus", "blur"],
  };

  function bindEvents(t: TriggerType) {
    triggerEventsMap[t].forEach((event) => {
      events[event] = popperEventsHandler;
    });
  }

  if (Array.isArray(props.trigger)) {
    props.trigger.map(bindEvents);
  } else {
    bindEvents(props.trigger);
  }

  watch(popperOptions, (val) => {
    if (!popperInstance) return;
    popperInstance.setOptions(val);
    popperInstance.update();
  });

  return {
    triggerRef,
    popperRef,
    arrowRef,

    initializePopper,

    show,
    hide,
    doDestroy,

    toggleState,
    visibility,

    events,
  };
}
