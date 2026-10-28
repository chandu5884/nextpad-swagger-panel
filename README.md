# Swagger Panel for Nextpad++ (macOS)

A [Nextpad++](https://github.com/nextpad-plus-plus) plugin that shows the open Swagger 2.0 / OpenAPI 3.x file (YAML or JSON) as interactive Swagger UI in a docked side panel.

- Live preview: updates as you type and when you switch tabs
- Works offline: Swagger UI and js-yaml are bundled
- Universal binary (Apple Silicon + Intel), macOS 11+

## Download

**[⬇ Download NppSwaggerPanel.zip](https://github.com/chandu5884/nextpad-swagger-panel/releases/latest/download/NppSwaggerPanel.zip)** (latest version)

All versions: [Releases page](https://github.com/chandu5884/nextpad-swagger-panel/releases)

## Install

### Option A: one command (Terminal)

Downloads the latest version and installs it, then restart Nextpad++:

```bash
cd /tmp && curl -fL -o NppSwaggerPanel.zip https://github.com/chandu5884/nextpad-swagger-panel/releases/latest/download/NppSwaggerPanel.zip && rm -rf ~/Library/Application\ Support/Nextpad++/plugins/NppSwaggerPanel && unzip -oq NppSwaggerPanel.zip -d ~/Library/Application\ Support/Nextpad++/plugins/ && xattr -dr com.apple.quarantine ~/Library/Application\ Support/Nextpad++/plugins/NppSwaggerPanel
```

### Option B: by hand

1. Download `NppSwaggerPanel.zip` using the link above and unzip it.
2. Copy the `NppSwaggerPanel` folder (the `.dylib` plus its `resources` folder) into:
   `~/Library/Application Support/Nextpad++/plugins/`
3. macOS blocks plugins downloaded from the internet, so clear the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine ~/Library/Application\ Support/Nextpad++/plugins/NppSwaggerPanel
   ```
4. Restart Nextpad++.

## Use

Open a spec, then **Plugins → Swagger Panel → Toggle Swagger Panel** (Ctrl+Alt+Shift+W).

## Build from source

Requires Xcode command line tools.

```bash
./build.sh
```

This produces `build/NppSwaggerPanel/` and `build/NppSwaggerPanel.zip`.

## Credits

- [Swagger UI](https://github.com/swagger-api/swagger-ui) (Apache-2.0)
- [js-yaml](https://github.com/nodeca/js-yaml) (MIT)
- Plugin API headers from [nextpad-plus-plus-macos](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos); Scintilla headers (Scintilla license)

## Security

See [SECURITY.md](SECURITY.md): the plugin makes no network connections of its own and stores nothing.

## License

MIT, see [LICENSE](LICENSE). Bundled Swagger UI is Apache-2.0 and js-yaml is MIT.
