# Releasing

Cutting a new version of PopNetworking takes three actions: merge the feature work, push a tag, click Publish. Everything else (release notes, DocC build, Pages deploy) is automated by the workflows in `.github/workflows/`.

## Steps

1. **Merge feature PRs into `main`.** Use descriptive PR titles — they become the release notes verbatim.

2. **Tag the release.** Tags must match `MAJOR.MINOR.PATCH` (e.g. `4.2.0`):
   ```bash
   git checkout main && git pull
   git tag 4.2.0
   git push origin 4.2.0
   ```
   Pushing the tag triggers `.github/workflows/Draft-Release.yml`, which creates a **draft** GitHub Release titled `PopNetworking 4.2.0`. The body is auto-generated from PR titles merged since the previous tag.

3. **Review and publish the draft.**
   - Open https://github.com/djk12587/PopNetworking/releases — the draft is at the top
   - Edit the body if you want to reorganize notes, add migration guidance, etc.
   - Click **Publish release**

   Publishing fires `.github/workflows/Deploy-Docs.yml`, which:
   - Builds DocC against the tagged commit (`xcodebuild docbuild` + `docc transform-for-static-hosting`)
   - Deploys the built site to GitHub Pages

   The live site at https://djk12587.github.io/PopNetworking/documentation/popnetworking updates within a few minutes.

## Recovering from a bad release

- **Notes are wrong**: edit the published release in the GitHub UI. Pages is unaffected.
- **Tag points at the wrong commit**: delete the tag (`git push --delete origin X.Y.Z`), retag the correct commit, push. Delete the old draft and re-publish the new one.
- **Deploy-Docs failed**: re-run the failed job from the Actions tab. The build is deterministic — if your local `xcodebuild docbuild` works, CI's will too.
- **Site renders broken content**: push a fix to `main`, then push a patch tag (`X.Y.Z+1`). The next deploy fully overwrites Pages.

## One-time setup (already done)

- Repo Settings → Pages → Source = **GitHub Actions** (not "Deploy from a branch")
- Default branch = `main`
- Tag format pattern in `Draft-Release.yml` matches semver-only tags

If Pages source ever gets reset to a branch source, deploys will silently fail. Re-set it to "GitHub Actions".

## What does NOT happen automatically

- Bumping versions in any consumer's `Package.swift` (clients pin themselves)
- Writing migration guides for breaking changes (do this in the PR body, it'll appear in the auto-generated release notes)
- Publishing to any package registry (Swift Package Manager pulls from tags directly)
