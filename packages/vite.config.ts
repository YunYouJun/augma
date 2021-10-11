import { resolve } from "path";
import { defineConfig } from "vite";

import Icons from "unplugin-icons/vite";
import IconsResolver from "unplugin-icons/resolver";
import Components from "unplugin-vue-components/vite";

import { VitePWA } from "vite-plugin-pwa";
import { capitalize } from "vue";

import { AugmaChildren } from "../meta/indexes";
import { hasDemo } from "../scripts/utils";

export default defineConfig({
  resolve: {
    alias: [
      { find: "augma", replacement: resolve(__dirname, "augma/index.ts") },
      { find: "@augma/core", replacement: resolve(__dirname, "core/index.ts") },
      {
        find: "@augma/style",
        replacement: resolve(__dirname, "components/styles/index.scss"),
      },
      {
        find: "@augma/shared",
        replacement: resolve(__dirname, "shared/index.ts"),
      },
    ],
  },
  plugins: [
    // https://github.com/antfu/unplugin-vue-components
    Components({
      dirs: [".vitepress/theme/components"],

      // allow auto load markdown components under `./src/components/`
      extensions: ["vue", "md"],

      // allow auto import and register components used in markdown
      include: [/\.vue$/, /\.vue\?vue/, /\.md$/],

      // custom resolvers
      resolvers: [
        // auto import icons
        // https://github.com/antfu/unplugin-icons
        IconsResolver({
          componentPrefix: "",
          // enabledCollections: ['carbon']
        }),
      ],

      dts: "src/components.d.ts",
    }),

    // https://github.com/antfu/unplugin-icons
    Icons({
      autoInstall: true,
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
              `\n# ${capitalize(name)} {{ $frontmatter.title }}` +
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
