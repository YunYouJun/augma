import indexes from "./indexes.json";

const componentNames = indexes.components.children.map(
  (component) => component.name
);
const hookNames = indexes.hooks.children.map((hook) => hook.name);

export const AugmaChildren = componentNames.concat(hookNames);
