# Purpose

This custom GitHub Action integrates Loco Translations (`https://localise.biz`) into your CI/CD pipeline. It supports two modes:

- **Export mode**: Download translations from Loco and create/update a Pull Request with the changed files.
- **Import mode**: Upload a local JSON translation file (e.g. `en.json`) to Loco so that all keys from the file exist in your Loco project. Use this on push/merge to main to keep Loco in sync with your source of truth.

# Github Action: Loco Translations `flipdishbytes/loco-translations@v1.8`

## Modes

The action chooses the mode automatically:

- **Import mode** when `locoWriteKey` is set **and** `format` is `json`: check out the repo and import `translationsFolder/<lang>.json` into Loco (use a single language in `langs`; no GitHub App or PR involved). If `format` is not `json`, import is skipped and the action runs as export.
- **Export mode** otherwise: use `locoExportKey` and the GitHub App to download from Loco, apply files, push to a branch, and create/update a PR.

---

## Export mode (download from Loco, create PR)

### How it works

1. Checks if there is a Pull Request open with the title starting with `[LANG] Loco updates`.
   - If yes, reuses its base and head branches.
   - If no, creates a branch `loco_updates_{YYYY_MM_DD}` and will create a PR at the end.
2. Downloads translations from Loco using `langs` and `format`. Set the `LOCOEXPORTKEY` secret.
3. Applies the downloaded files into `translationsFolder`.
4. If there are changes, commits and pushes to the translations branch.
5. Creates a PR if there is none yet.

### Example (export, RESX)

❗ Enable **Automatically delete head branches** in the repo so the Loco branch is deleted after the PR is merged.

```yaml
name: flipdishbytes.serverless-app-template.translations-export

on:
  workflow_dispatch:
  schedule:
    - cron: "0 */8 * * *"

permissions:
  id-token: write
  contents: write
  pull-requests: write

jobs:
  loco-export:
    runs-on: ubuntu-latest
    steps:
      - name: Translations Loco
        uses: flipdishbytes/loco-translations@v1.8
        with:
          app-id: ${{ vars.LOCO_APP_ID }}
          private-key: ${{ secrets.LOCO_PRIVATE_KEY }}
          locoExportKey: ${{ secrets.LOCOEXPORTKEY }}
          # mainBranch: main
          langs: 'en,bg,de,es,fr,it,nl,pl,pt,fi'
          format: 'resx'
          # format: resx | json | lproj | xml
          translationsFolder: 'src/DotNET.Translations'
          # reviewer: 'flipdishbytes/delivery-enablement-team'
          # automerge: false
          # draft: false
```

### Example (export, JSON)

Use `format: json` and set **`convert: 'true'`** if you also run the **import** workflow: export will write the value format `{"key":{"value":"..."}}`, which matches what import expects. `convert` is supported only for JSON.

```yaml
name: flipdishbytes.serverless-app-template.translations-export

on:
  workflow_dispatch:
  schedule:
    - cron: "0 */8 * * *"

permissions:
  id-token: write
  contents: write
  pull-requests: write

jobs:
  loco-export:
    runs-on: ubuntu-latest
    steps:
      - name: Translations Loco
        uses: flipdishbytes/loco-translations@v1.8
        with:
          app-id: ${{ vars.LOCO_APP_ID }} # No need to change/set this in your repository. LOCO_APP_ID variable is set globally.
          private-key: ${{ secrets.LOCO_PRIVATE_KEY }} # No need to change/set this in your repository. LOCO_PRIVATE_KEY secret is set globally.
          locoExportKey: ${{ secrets.LOCOEXPORTKEY }} # https://localise.biz → Project → Developer Tools → Export the read-only key from your Loco project. Set LOCOEXPORTKEY in your GitHub repository secrets (/settings/secrets/actions).
          langs: 'en,en-US,de,es-MX,es,fr,it,nl,pt' # language tags should match Loco languages from the project
          format: json
          convert: 'true' # JSON only. Required for import workflow compatibility: exports as {"key":{"value":"..."}} so import can read the same files. Use 'false' to export flat JSON (not compatible with import).
          translationsFolder: localization
          mainBranch: main
          automerge: true
```

---

## Import mode (upload JSON to Loco)

**Only JSON format is supported for import.** Use the same structure in your JSON files as in the template below.

### Requirements

1. **JSON format only** — Import runs only when `format` is `json`.
2. **Use the value format in your JSON files** — Match the template format so export and import stay in sync. Example:
   ```json
   "About_Test": {
       "value": "About Test"
   },
   ```
   The JSON files in your repo **must** use this value format. The action can read both flat and value-wrapped when importing to Loco, but the canonical format in the repo must be `{"key": {"value": "..."}}` for compatibility with import-from-Loco when using `convert: 'true'`.
3. **Do not use `.value` in Loco strings** — In Loco, store the plain translation (e.g. `About Test`), not IDs or text that include `.value`. If you already have `.value` in Loco, you can run the **export** pipeline manually: it will add all strings from `en.json` and generate translations, which also helps repopulate or fix the Loco project.
4. **Filling a Loco project from JSON** — You can use the import workflow (or a one-off import) to seed a new or empty Loco project from your `en.json` file.

### How it works

1. Checks out the repository.
2. Reads the JSON file at `translationsFolder/<lang>.json` (e.g. `localization/en.json` when `translationsFolder` is `localization` and `langs` is `en`). **Import requires `format: 'json'** and **exactly one language in `langs`.**
3. Sends it to Loco’s import API with `ignore-existing=true`, so only **new** keys are added; existing assets are not updated.

Use this on push to `main` when your source translation file changes, so Loco gets new keys from your codebase. You can restrict the workflow to run only when that file changes using `paths`. If you also use **export** with JSON, set **`convert: 'true'`** in the export workflow so exported files use the same value format (`{"key":{"value":"..."}}`) that import supports.

### Example (import when translation file changes)

Set `LOCOWRITEKEY` in your repository secrets (Loco → Project → Developer tools → full-access/write key).

```yaml
name: flipdishbytes.serverless-app-template.translations-import

on:
  workflow_dispatch:
  push:
    branches:
      - main
    # Run only when the translation file changes; update path(s) to match your repo
    paths:
      - 'localization/en.json'

permissions:
  id-token: write
  contents: write

concurrency:
  group: main_translations

jobs:
  loco-import:
    runs-on: ubuntu-latest
    steps:
      - name: Add tags to pipeline traces
        uses: flipdishbytes/datadog-ci@v1.2
        with:
          COMMAND: 'tag --level pipeline --tags service:serverless-app-template --tags team:platform-enablement-team --tags env:production'
      - name: Translations Loco
        uses: flipdishbytes/loco-translations@v1.8
        with:
          locoWriteKey: ${{ secrets.LOCOWRITEKEY }}
          format: 'json'
          langs: 'en'
          # Folder containing <lang>.json; update if your file is elsewhere (e.g. packages/frontend/src/localization)
          translationsFolder: 'localization'
```

The JSON format in your repo must be the value format `{"key": {"value": "..."}}` (see **Requirements** above). The action supports reading both flat and value-wrapped when exporting to Loco, but the repo files must use the value format.

---

## Inputs reference

| Input | Export | Import | Description |
|-------|--------|--------|-------------|
| `locoExportKey` | ✅ Required | — | Loco export key. |
| `locoWriteKey` | — | ✅ Required | Loco write key (import mode). |
| `langs` | ✅ Required | ✅ Required (exactly one) | Comma-separated for export; single language for import (e.g. `en`). |
| `format` | ✅ Required | ✅ Required (`json` only) | Export: `resx` \| `json` \| `lproj` \| `xml`. Import runs only when `json`. |
| `translationsFolder` | ✅ Required | ✅ Required | Folder for translation files (export: write here; import: read `<lang>.json` from here). |
| `app-id` | ✅ Required | — | GitHub App ID (export only). |
| `private-key` | ✅ Required | — | GitHub App private key (export only). |
| `mainBranch` | Optional | — | Default `main`. |
| `nofolding` | Optional | — | JSON only, default `false`. |
| `convert` | Optional | — | **JSON only.** Set to `true` for import workflow compatibility (exports `{"key":{"value":"..."}}`; import expects this format). Default `false`. |
| `filesExtension` | Optional | — | JSON only. |
| `languagePostfixInNames` | Optional | — | JSON only, default `false`. |
| `reviewer` | Optional | — | PR reviewer. |
| `skip_pr_create` | Optional | — | Default `false` (monorepo). |
| `use_current_loco_branch` | Optional | — | Default `false`. |
| `draft` | Optional | — | Create PR as draft. |
| `automerge` | Optional | — | Automerge PR. |
