# Purpose

This custom GitHub Action was created to integrate Loco Translations into your CI/CD pipeline. It allows you to download translations from `https://localise.biz` and create/update PR with translated files.

# Github Action: Loco Translations `flipdishbytes/loco-translations@v1.0`

To use this Datadog CI action, add it to your pipeline workflow YAML file. Here are examples of adding traces to the pipeline depending on your needs.

### How it works?

1. Checks if there is Pull Request opened with the `[LANG] Loco updates` title in the beginning.
    1.1. If there is any it gets the latest one and reads base and target branches for this PR to reuse them.
    1.2. If there is no any PR opened it will generate branch name based on the current data `loco_updates_{YYYY_MM_DD}` and will create PR in the end.
2. Downloads translations from Loco based on `langs` array and `format`. Set `LOCOEXPORTKEY` secret in your GitHub Actions.
3. Applies downloaded translations files (overwrite) to the `translationsFolder` folder.
4. Checks if there are any changes based on `git status` and pushing them to the translations branch from the #1.
5. Creates PR if there is no any yet.


### How to use?

```yaml
name: GH Action workflow to download and apply Loco Translations

on:
  # allow to run manually
  workflow_dispatch:

permissions: 
  id-token: write
  contents: write
  pull-requests: write


jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Translations Loco
        uses: flipdishbytes/loco-translations@v1.0
        with:
          locoExportKey: ${{ secrets.LOCOEXPORTKEY }} # https://localise.biz -> Project -> Developer tools -> Export key from your Loco project. Set LOCOEXPORTKEY secret in your GitHub Actions.
          langs: 'en,bg,de,es,fr,it,nl,pl,pt,fi' #language tags should match Loco languages from the project
          format: 'resx' 
          # supported formats: 
          #     resx (for .NET projects),
          #     json (for Android and other ptojects using json language files),
          #     lproj (for iOS projects).
          translationsFolder: 'src/DotNET.Translations' #the folder where yout translation files are located.
          GH_TOKEN: ${{ github.token }} # leave it like that of you don't need to assign PR to groups for review.
          mainBranch: main # it's main by default. Set it to your repository default branch.
```