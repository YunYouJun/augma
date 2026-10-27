# Augma for Magpie

A local plugin for official Magpie 0.1.1673, Augma for macOS, and DSH 0.2.0-rc.2. No changes to Magpie source or signing are needed.

Choose the model or routing group on the Augma card in Agents. Save reasoning effort in the Augma panel below the list or on the Augma plugin page, then detect and test in Augma before enabling the assistant. The plugin only affects requests identified as Augma.

Install this folder using `magpie plugin add /absolute/path/to/magpie-plugin-augma`, then save Medium in the panel to initialize options. Augma must have created its configuration first. Before uninstalling, disconnect the Augma card to restore its previous configuration.

The page has no network access or read permissions. Credentials and DSH desktop profiles are not copied. The agent writes only credential-free integration settings; the page saves its own options; Augma reads the active `augma-v1` options entry from Magpie’s default config directory (or absolute `XDG_CONFIG_HOME`).

Run `node --test test/*.test.js` to verify the plugin logic. Full installation and migration instructions are in the Augma repository’s `integrations/magpie/README.md`.
