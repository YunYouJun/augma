import { resolve } from "path";
import { defineConfig } from "vite";

import ViteComponents from "vite-plugin-components";
import ViteIcons, { ViteIconsResolver } from "vite-plugin-icons";
import { VitePWA } from "vite-plugin-pwa";

import { AugmaChildren } from "../meta/indexes";
import { firstLetterUpper, hasDemo } from "../scripts/utils";

export default defineConfig({
  resolve: {
    alias: [
      { find: "@augma/core", replacement: resolve(__dirname, "core/index.ts") },
      { find: "@augma/styles", replacement: resolve(__dirname, "styles") },
    ],
  },
  plugins: [
    ViteComponents({
      dirs: [".vitepress/theme/components"],
      customLoaderMatcher: (id) => id.endsWith(".md"),
      // directoryAsNamespace: true,
      customComponentResolvers: ViteIconsResolver(),
    }),
    ViteIcons({
      // hide default style
      defaultStyle: "",
    }),
    {
      name: "md-transform",
      enforce: "pre",
      transform(code, id) {
        if (!id.endsWith(".md")) return null;

        const [pkg, name, i] = id.split("/").slice(-3);

        if (AugmaChildren.includes(name) && i === "index.md") {
          const frontmatterEnds = code.indexOf("---\n", 3) + 4;
          let header = "";
          if (hasDemo(pkg, name)) {
            const insertedCode =
              "\n\n<script setup>\nimport Demo from './demo.vue'\n</script>\n";
            const demoCode = `\n\n::: demo\n\n<<< ./packages/${pkg}/${name}/demo.vue\n\n:::\n`;
            header =
              insertedCode +
              `\n# ${firstLetterUpper(name)} {{ $frontmatter.title }}` +
              demoCode;
          }

          if (header) {
            code =
              code.slice(0, frontmatterEnds) +
              header +
              code.slice(frontmatterEnds) +
              "<PropsTable v-if='$frontmatter' :props='$frontmatter.props' />";
          }
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
});
