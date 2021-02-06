import _indexes from "./indexes.json";

const indexes = _indexes;

export const componentNames = indexes.components.map(
  (component) => component.name
);
