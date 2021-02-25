import { defineConfig } from "vite";
import path from "path";

import vue from "@vitejs/plugin-vue";
import Pages from "vite-plugin-pages";

export default defineConfig({
  plugins: [
    vue(),
    Pages({
      extensions: ["vue", "md"],
    }),
  ],
  // for '~/components'
  resolve: {
    alias: {
      "~": path.resolve(__dirname, "./src"),
    },
  },
});
