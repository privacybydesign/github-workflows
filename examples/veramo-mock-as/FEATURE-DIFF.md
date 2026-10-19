# veramo-mock-as: current workflow vs. shared workflows v1.1

Compared against `privacybydesign/veramo-mock-as` at `1ac2e89` (2026-05-29).
Old: `.github/workflows/docker.yml` (51 lines, push to main + PRs).
New: `status-checks.yml`, `delivery.yml` (with a temporary compat job), `image-rescan.yml`,
`ghcr-cleanup.yml` and `.github/dependabot.yml`, calling `@v1`. The shared workflows are unchanged.

Legend: `=` same · `+` added · `-` removed · `~` changed behaviour · ⚠ new check that can fail a PR · `GAP` not covered by the shared workflows

## Delivery (Docker image)

| | Feature | Current | Shared workflows v1.1 |
|---|---|---|---|
| = | Image name | `ghcr.io/privacybydesign/veramo-mock-as` | same |
| = | Platforms | linux/amd64 + linux/arm64 | same (`platforms` input) |
| = | Trigger | push to `main` | push to `main` + manual |
| ~ | Tag on push to main | `:latest` + `:sha-<short>` | `:edge`; **`:latest` and `:sha-<short>` only via the compat job** in `delivery.yml` (same digest, no rebuild) — **GAP 1** |
| + | Vulnerability scan before push | no | Anchore, critical + fixable fails |
| + | Edge only for the real HEAD, serialised per branch | no | yes |
| + | SBOM, provenance, GitHub attestation | no | yes |
| + | Reproducible image | no | yes |
| + | Dockerfile checks / base images pinned by digest | no | warnings: `golang:1.24-alpine` and `alpine:3.21` are not pinned |
| ~ | Action versions | `@v3`/`@v4`/`@v6` tags | SHA-pinned, Dependabot |
| ~ | Token permissions | `packages: write` on PRs too | `permissions: {}` + per job |
| + | Weekly rescan of published `:edge` + `:latest` (both platforms) | no | `image-rescan.yml` |
| + | Retention of old `:sha-*` tags and untagged versions | no | `ghcr-cleanup.yml` (dry run) |

## Status checks (all new: the repository has no Go CI today)

| | Feature | Current | Shared workflows v1.1 |
|---|---|---|---|
| ~ | PR image build | multi-arch build, no push, no scan | build + scan, no push — **amd64 only** (**GAP 2**) |
| + ⚠ | gofmt, `go fix`, `go mod tidy` | no | yes |
| + ⚠ | golangci-lint v2 | no | yes (default linters; no `.golangci.yml` in the repo) |
| + ⚠ | Tests (`main_test.go`) with `-race` | **not run** | yes |
| + ⚠ | govulncheck | no | yes — likely to fail, see "Repository findings" |
| + ⚠ | CodeQL Go + Actions | no | yes |
| + ⚠ | Dependency review | no | yes |
| + ⚠ | actionlint + zizmor | no | yes |
| + | One required check `Status checks passed`, merge queue, timeouts | no | yes |
| + | Dependabot (actions, Docker tag + digest, Go) | no | `dependabot.yml` |

## Gaps in the shared workflows (reported, not changed)

1. **No custom or extra image tags.** `docker-publish.yml` has a fixed tag set
   (`edge`, semver, `latest` only for the latest GitHub release, branch on manual runs).
   Repos without releases that publish `:latest` from `main`, or `:sha-<short>` per commit,
   can't keep those tags. Workaround used here: a caller-side job that runs
   `docker buildx imagetools create` on the published digest (tested: the digest stays
   identical). Suggested fix for v1.2: an `extra-tags` input (metadata-action tag rules),
   e.g. `type=raw,value=latest,enable={{is_default_branch}}` and `type=sha`.
2. **Check-only mode builds only the first platform.** With `push-image: false` the image is
   built and scanned for `linux/amd64` only, so an arm64-only build failure (e.g. a
   base image without arm64) is first seen on `main`. The current workflow builds both
   platforms on PRs. Suggested fix: an input to build all `platforms` in check mode
   (scan stays on the first platform).
3. **Modules without `go.sum` log a cache warning.** `go-checks`, `go-release` and `codeql`
   pass `go.sum` as the cache key; this repo has no dependencies and no `go.sum`, so
   setup-go logs "unable to cache dependencies" (a warning, the job still passes).
   Suggested fix: hash `go.mod` when `go.sum` doesn't exist.

Everything else this repository needs is covered by the existing inputs.

## Repository findings (fix in veramo-mock-as before switching)

1. **Go 1.24 is end-of-life** (`go 1.24` in `go.mod`, `golang:1.24-alpine` in the Dockerfile).
   Go 1.26 is current, so newer standard-library fixes are not backported to 1.24 and
   govulncheck will probably report reachable `net/http` vulnerabilities. Bump to Go 1.26.
2. **Base images are not pinned by digest** (warnings only). Pin `golang:…@sha256:…` and
   `alpine:…@sha256:…`; Dependabot's docker ecosystem then bumps tag and digest together.
3. **The container runs as root** (`alpine:3.21`, no `USER`). Consider
   `gcr.io/distroless/static-debian12:nonroot` like the Go issuers; nothing else is
   needed for a static `CGO_ENABLED=0` binary.
4. **Consumers of `:latest` / `:sha-*`**: no public privacybydesign repository references
   this image (checked veramo-agent, veramo-verifier, statuslist-agent,
   openid4vp-demo-frontend). If no private deployment uses those tags either, drop the
   compat job and use `:edge`.

## Before switching

1. Fix repository findings 1–3 in a PR that still uses the old workflow.
2. Add the new files, delete `docker.yml`, then run
   `org-settings/apply-org-settings.sh opt-in veramo-mock-as`.
3. Run `ghcr-cleanup.yml` once in dry-run mode, review the summary, then set `dry-run: false`.
