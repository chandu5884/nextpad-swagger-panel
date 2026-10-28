# Security

## Network

The plugin itself makes **no network connections**. Swagger UI and js-yaml are bundled
in `resources/` and loaded from disk; nothing is fetched from a CDN. The online spec
validator badge is disabled (`validatorUrl: null`).

Network traffic happens only when the user asks for it, from the spec they opened:

- **"Try it out" / "Execute"** in Swagger UI sends the HTTP request the user built to the
  server listed in the spec's `servers` / `host` field.
- **External `$ref`s** (a `$ref` pointing at an `http(s)://` URL) are fetched by Swagger UI
  from that URL to resolve the spec.
- **Links** in the spec (for example `externalDocs`) open in the default browser, not in the panel.

## Storage

Nothing is stored. The plugin keeps no settings or config files and saves no credentials.
Values typed into Swagger UI (such as API keys under "Authorize") exist only in the panel's
memory and are gone when Nextpad++ quits.

## Execution

No external programs are run. The plugin reads the current document's text from the
editor and passes it to Swagger UI in a WKWebView (loaded from `resources/index.html`).

## Reporting

Please report security issues by opening an issue at
https://github.com/chandu5884/nextpad-swagger-panel/issues.
