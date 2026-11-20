# Publishing the wiki

The only place to edit the wiki is `docs/wiki/` in this repository. The GitHub wiki (`<repo>.wiki.git`) is a generated mirror. Never edit pages in the GitHub web UI: the next sync overwrites them.

## Automatic publish

`.github/workflows/publish-wiki.yml` runs on every push to `main` that touches `docs/wiki/**`. It mirrors `docs/wiki/` into the wiki repo with `rsync --delete`, then commits and pushes with the default `GITHUB_TOKEN` (no deploy key). No diff, no commit. It can also be started by hand (Actions tab, "Run workflow").

### One-time setup

1. Settings, Features: wiki enabled, and at least one page exists (otherwise the wiki repo cannot be cloned).
2. Settings, Features, Wiki: tick "Restrict editing to collaborators only".
3. Settings, Actions, General, Workflow permissions: the workflow sets `contents: write` itself, so the read-only default is fine.

### Before a push that changes the wiki

- no placeholders left: `grep -R "{{" docs/wiki`
- no screenshot placeholders left (`grep -R "placeholder-" docs/wiki --include=*.md`), or a conscious decision to publish with them
- `python tools/rotation_sim/check_config.py` prints OK, and `python tools/rotation_sim/gen.py --wiki` leaves no diff

## Manual publish (fallback)

```
git clone https://github.com/borondy/FS25_VirtualTSZPrecisionFarmingExtension.wiki.git ../wiki-publish
rsync -a --delete --exclude .git docs/wiki/ ../wiki-publish/   # or robocopy /MIR /XD .git on Windows
cd ../wiki-publish && git add -A && git commit -m "Update wiki" && git push
```
