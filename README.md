# Purpose

This custom GitHub Action was created to integrate Loco Translations into your CI/CD pipeline. It allows you to download translations from `https://localise.biz` and create/update PR with translated files.

# Github Action: Loco Translations `flipdishbytes/loco-translations@v1.3`

To use this Datadog CI action, add it to your pipeline workflow YAML file. Here are examples of adding traces to the pipeline depending on your needs.

### How it works?

1. Checks if there is a Pull Request opened with the `[LANG] Loco updates` title in the beginning.
    1. If there is any, it gets the latest one and reads base and target branches for this PR to reuse them.
    2. If there is no PR opened, it will generate a branch name based on the current date `loco_updates_{YYYY_MM_DD}` and will create a PR in the end.
2. Downloads translations from Loco based on the `langs` array and `format`. Set the `LOCOEXPORTKEY` secret in your GitHub Actions.
3. Applies downloaded translation files (overwrite) to the `translationsFolder` folder.
4. Checks if there are any changes based on `git status` and pushes them to the translations branch from step 1.
5. Creates a PR if there is none yet.

### How to use?

❗ Make sure you enabled `Automatically delete head branches ` in your GitHub repository so after pull requests are merged, you can have head branches deleted automatically.

```yaml
name: GH Action workflow to download and apply Loco Translations

on:
  # allow to run manually
  workflow_dispatch:
  # run on schedule every 8 hours at 0 minutes
  schedule:
    - cron: "0 */8 * * *"

permissions: 
  id-token: write
  contents: write # must be set
  pull-requests: write # must be set


jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Translations Loco
        uses: flipdishbytes/loco-translations@v1.3
        with:
          app-id: ${{ vars.LOCO_APP_ID }} # No need to change/set this in your repository. LOCO_APP_ID variable is set globally in all Flipdish repos.
          private-key: ${{ secrets.LOCO_PRIVATE_KEY }} # No need to change/set this in your repository. LOCO_PRIVATE_KEY secret is set globally in all Flipdish repos.
          locoExportKey: ${{ secrets.LOCOEXPORTKEY }} # https://localise.biz -> Project -> Developer tools -> Export key from your Loco project. Set LOCOEXPORTKEY secret in your GitHub Actions.
          #mainBranch: main # it's main by default. Set it to your repository default branch if it's needed. Not required.
          langs: 'en,bg,de,es,fr,it,nl,pl,pt,fi' #language tags should match Loco languages from the project
          format: 'resx'
          # supported formats: 
          #     resx (for .NET projects)
          #     json (for projects using json language files)
          #     lproj (for iOS projects)
          #     xml (for Android projects)
          # nofolding: 'true' # supported only by json formats
          translationsFolder: 'src/DotNET.Translations' # the folder where your translation files are located.
          #filesExtension: 'strings.json' # will rename default extensions by this custom one ### supported by json format only
          #languagePostfixInNames: true # will rename files to be 'de_DE' and etc (except the en language) ### supported by json format only
          #reviewer: 'flipdishbytes/delivery-enablement-team' #Use comma if you need more than one team.
          #automerge: false # false by default. Use to enable auto merge after necessary requirements are met. Can't be used with draft set to true. Make sure you enabled pull request Auto merge for your repository.
          #draft: false # false by default.
          #skip_pr_create: false # false by default. Used for monorepos when there are more than one steps for loco translations being called. All steps except the last one should set this to false.
          #use_current_loco_branch: true # false by default. Use to use the current branch in Loco for translations.
```