import { defineConfig } from "vite";
import path from "path";

import Vue from "@vitejs/plugin-vue";
import Pages from "vite-plugin-pages";

export default defineConfig({
  plugins: [
    Vue(),
    Pages({
      extensions: ["vue", "md"],
    }),
  ],
  // for '~/components'
  resolve: {
    alias: {
      '~/': `${path.resolve(__dirname, 'src')}/`,
      '@augma/components/': `${path.resolve(__dirname, '../components')}/`,
      '@augma/utils/': `${path.resolve(__dirname, '../utils/src')}/`,
      '@augma/hooks': `${path.resolve(__dirname, '../hooks/src')}/`,
      '@augma/shared': `${path.resolve(__dirname, '../shared/src')}/`,
      'augma': `${path.resolve(__dirname, '../augma/src')}/`,
    },
  },
});
