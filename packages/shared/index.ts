import { Indexable } from "@augma/utils/types";

export type AgmColorType =
  | "default"
  | "primary"
  | "success"
  | "warning"
  | "danger"
  | "info";

export const AgmTypeArray: AgmColorType[] = [
  "default",
  "primary",
  "success",
  "warning",
  "danger",
  "info",
];

export const AgmTypeMap: Indexable<AgmColorType> = {
  default: "default",
  primary: "primary",
  success: "success",
  warning: "warning",
  danger: "danger",
  info: "info",
};

export function getAgmColorByType(type: AgmColorType) {
  if (type && AgmTypeMap[type]) {
    return `var(--agm-${type})`;
  } else {
    return type;
  }
}

export type ComponentSize = "large" | "medium" | "small" | "mini";
