import DefaultTheme from "vitepress/dist/client/theme-default";

// https://github.com/antfu/unocss
// 'uno:[layer-name].css'
import 'uno:components.css'
// layers that are not 'components' and 'utilities' will fallback to here
import 'uno.css'

// custom css
// import augma from "augma";
import "@augma/components/styles/index.scss";
// custom css
import "./styles/index.scss";

// "utilities" layer will have the highest priority
import 'uno:utilities.css'

const theme = {
  ...DefaultTheme,
};

export default theme;
