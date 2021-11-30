import { useData } from "vitepress";
import type { DefaultTheme } from "../config";

export function useRepo() {
  const { site } = useData();

  return computed(() => {
    const theme = site.value.themeConfig as DefaultTheme.Config;
    const name = theme.docsRepo || theme.repo;

    if (!name) return null;

    const link = getRepoUrl(name);

    return { text: 'GitHub', link };
  });
}

function getRepoUrl(repo: string): string {
  // if the full url is not provided, default to GitHub repo
  return /^https?:/.test(repo) ? repo : `https://github.com/${repo}`;
}

export const platforms = ["GitHub", "GitLab", "Bitbucket"].map((platform) => {
  return [platform, new RegExp(platform, "i")] as const;
});

