import { createBlock, openBlock } from "vue";

import type { VNodeTypes } from "vue";

type Children = VNodeTypes[] | VNodeTypes;

export function renderBlock(
  node: VNodeTypes,
  props: any,
  children?: Children,
  patchFlag?: number,
  patchProps?: string[]
) {
  return openBlock(), createBlock(node, props, children, patchFlag, patchProps);
}
