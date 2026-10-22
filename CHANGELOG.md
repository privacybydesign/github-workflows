# Changelog

## v1.1.3

- `workflow-lint.yml`: a repository without its own `.github/zizmor.yml` now gets the shared policy (`privacybydesign/*` by tag, everything else by SHA) instead of zizmor's defaults, which reject `@v1`. Repositories set up from the workflow templates pass without copying `zizmor.yml`.

## v1.1.2

- `docker-publish.yml`: the provenance attestation no longer tries to create an artifact storage record. That needed `artifact-metadata: write` from every caller and only produced a warning; the attestation itself is unchanged.

## v1.1.1

- Callers use the moving `@v1` tag again, as in v1.0. v1.1.0 asked for a commit SHA per caller, which meant a pull request in every repository for each release. `templates/zizmor.yml` allows a tag for `privacybydesign/*` again and still requires a SHA for every other action.
- `codeql.yml` no longer runs `actions/unpinned-tag`, which would flag every `@v1` reference. zizmor covers third-party actions. A caller's `config-file` is merged with this filter.

## v1.1.0

All changes are backwards compatible for v1.0 callers: new inputs default
to the v1.0 behaviour unless noted. New checks that can fail a build are
marked ⚠.

### New reusable workflows
- `codeql.yml`: CodeQL (`security-extended`) for Go, JS/TS and GitHub Actions.
- `dependency-review.yml`: blocks PRs that add vulnerable (≥ high) or disallowed-licence dependencies.
- `workflow-lint.yml`: actionlint + zizmor for any repository.
- `image-rescan.yml`: weekly scan of the published image tags, every platform.
- `ghcr-cleanup.yml`: GHCR retention; never deletes manifests or referrers that a kept tag needs; dry run by default.

### docker-publish.yml
- `push-image: false` to build + scan only (PR checks in Status checks).
- Push of a `v*` tag is handled like a published release.
- ⚠ Releases whose commit is not on the default branch are refused (`require-release-on-default-branch`).
- `docker build --check` (`dockerfile-check: warn`) and base-image digest pinning check (`base-image-pinning: warn`).
- Reproducible images: `SOURCE_DATE_EPOCH` = commit time + `rewrite-timestamp` (same commit → same digest).
- Optional keyless cosign signing (`cosign: true`).
- Per-ref concurrency: a pending release run is never cancelled by a later push.
- `timeout-minutes` (60).

### go-checks.yml
- ⚠ `govulncheck` job (`govulncheck: true`).
- ⚠ `go mod tidy` drift check (`check-go-mod-tidy: true`).
- Timeouts and cancellation of superseded PR runs.

### go-release.yml
- Works with **immutable releases**: on a `v*` tag push it uploads to a draft (existing or new) and then publishes it, with the release App token when given so `release: published` workflows still run.
- `release: published` trigger still supported for repos without immutable releases.
- SPDX SBOM attached to the release + SBOM attestation (`sbom: true`).
- ⚠ Release commit must be on the default branch.
- `-trimpath -buildvcs=true` for reproducible binaries.

### node-checks.yml
- `ignore-scripts` + `allowed-scripts`: install without dependency lifecycle scripts (default off in v1.x, on in the templates).
- Timeouts and cancellation of superseded PR runs.

### npm-publish.yml
- ⚠ Release commit must be on the default branch (tag-driven mode).

### terraform.yml
- Checkov IaC scan (`checkov: warn`).
- ⚠ Drift detection on `schedule` runs (`fail-on-drift: true`).
- tflint version pinned (`tflint-version: v0.64.0`, was `latest`).

### Fixes
- docker-publish: `tags` output lists only tags that were actually pushed; GHA cache scope and SARIF category are unique per image/Dockerfile/context (matrix callers no longer overwrite each other).
- terraform: the saved plan is kept 7 days (approval window) together with `.terraform.lock.hcl`; concurrency is per event + ref, so drift or merge-queue runs never cancel a pending push plan.
- workflow-lint: `actionlint-paths` to lint workflow files outside `.github/workflows` (used by this repo for templates and examples).

### Templates and org settings
- Status checks templates for Go and Node with one required gate job, **`Status checks passed`**, and `merge_group` triggers.
- Delivery template: PR scanning moved to Status checks, the weekly schedule moved to Image rescan.
- New templates: image rescan, GHCR clean-up, OpenSSF Scorecard; Go release template uses tag push.
- `templates/dependabot.yml` (actions, Docker digests, Go, npm, Terraform; grouped; 7-day cooldown).- `org-settings/`: allowed actions, rulesets, security configuration, apply script with `baseline`, `opt-in` and `strict` phases.

## v1.0.0
- Initial release: docker-publish, go-checks, go-release, node-checks, npm-publish, terraform, pr-title, release-please.
