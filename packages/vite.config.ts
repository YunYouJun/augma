import { resolve } from "path";
import { defineConfig } from "vite";

import ViteComponents from "vite-plugin-components";
import ViteIcons from "vite-plugin-icons";
import { VitePWA } from "vite-plugin-pwa";

import { componentNames } from "../meta/indexes";
import { hasDemo } from "../scripts/utils";

export default defineConfig({
  alias: [
    { find: "@augma/core", replacement: resolve(__dirname, "core/index.ts") },
  ],
  plugins: [
    ViteComponents({
      dirs: [".vitepress/theme/components", "components"],
      customLoaderMatcher: (id) => id.endsWith(".md"),
    }),
    ViteIcons(),
    {
      name: "md-transform",
      enforce: "pre",
      transform(code, id) {
        if (!id.endsWith(".md")) return null;

        const [pkg, name, i] = id.split("/").slice(-3);

        if (componentNames.includes(name) && i === "index.md") {
          const frontmatterEnds = code.indexOf("---\n\n") + 4;
          let header = "";
          if (hasDemo(pkg, name))
            header =
              "\n<script setup>\nimport Demo from './demo.vue'\n</script>\n";

          if (header)
            code =
              code.slice(0, frontmatterEnds) +
              header +
              code.slice(frontmatterEnds);
        }

        return code;
      },
    },
    VitePWA({
      outDir: ".vitepress/dist",
      manifest: {
        name: "Augma Docs",
        short_name: "Augma",
        theme_color: "#557591",
        icons: [
          {
            src: "/logo.png",
            sizes: "240x240",
            type: "image/png",
          },
        ],
      },
    }),
  ],
  // build: {
  //   lib: {
  //     entry: resolve(__dirname, "index.ts"),
  //     name: "augma",
  //   },
  // },
});
