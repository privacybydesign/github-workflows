# go-sms-issuer: current workflows vs. shared workflows

Compared against `privacybydesign/go-sms-issuer` at `ae17e8a` (v1.6.1, 2026-09-29).
Old: `delivery.yml` (87 lines) + `status-checks.yml` (133 lines).
New (v1.1): `status-checks.yml` (89 lines) + `delivery.yml` (26 lines) + `image-rescan.yml` (20 lines) + `.github/dependabot.yml`, calling `@v1`.

Legend: `=` same · `+` added · `-` removed · `~` changed behaviour · `!` needs action before switching

## Delivery (Docker image)

| | Feature | Current | Shared workflow |
|---|---|---|---|
| = | Image name | `ghcr.io/privacybydesign/go-sms-issuer` | same |
| = | Platform | linux/amd64 | same (input `platforms`) |
| = | Push to main → `:edge` | yes | yes |
| = | Release → `:x.y.z` | `{{major}}.{{minor}}.{{patch}}` | `{{version}}`. Same for stable releases |
| = | Manual run → `:<branch>` (and `:edge` on main) | yes | yes |
| ~ | Scheduled run | rebuilds main + scans (the *next* image), no push | `image-rescan.yml` scans the **published** `:edge` and latest-release tags, amd64 + arm64 |
| = | Anchore scan: only-fixed, critical, fail-build | yes | yes (same defaults) |
| = | `TURNSTILE_SITE_KEY` build arg from a secret | yes | yes, via `secrets: DOCKER_BUILD_ARGS` |
| ~ | Pre-release → tag | `v1.7.0-rc.1` would **overwrite `:1.7.0`** | only `:1.7.0-rc.1` |
| ~ | Stale push (main moved on) | still tags `:edge`. Its HEAD check compares the checked-out SHA with itself, so it always passes | skipped: `:edge` only goes to the real HEAD |
| ~ | What gets scanned | image A (`load: true`), then **rebuilt** as image B and pushed | built once into an OCI archive, scanned, then pushed unchanged (digest checked after push). Scanned = published |
| = | Failed scan | nothing pushed | nothing pushed |
| ~ | Cron | `0 9 * * 0` = **Sunday** (comment says Monday) | `0 9 * * 1` = Monday |
| ~ | Workflow token | `contents: write` for the whole workflow | `contents: read`, per job |
| ~ | SARIF upload failure | fails the job | non-blocking (needed for fork PRs) |
| ~ | Code-scanning category | default | `anchore-Dockerfile`: alerts start under a new category, old ones need closing once |
| ~ | Build cache | `type=gha` default scope | scope per Dockerfile: the first run is uncached |
| ~ | Image manifest | single manifest | OCI index with SBOM + provenance attestation manifests (tag pulls unaffected) |
| ~ | PR image build | in Status checks, **not scanned** | in Status checks (`push-image: false`), scanned; **blocks** on critical fixable CVEs (add `scan-fail-build: false` to keep PRs non-blocking) |
| + | Concurrency | none: parallel runs can tag out of order | serialised per ref; superseded PR runs cancelled |
| + | GitHub artifact attestation | no | yes (`gh attestation verify oci://…`) |
| + | OCI labels on scan build, annotations | push only | both |
| + | Multi-arch | not possible together with the scan | possible (`platforms: linux/amd64,linux/arm64`) |

## Status checks

| | Feature | Current | Shared workflow |
|---|---|---|---|
| = | Frontend `npm ci` + `npm run build` (Node 24, npm cache) | yes | yes (`scripts: build`) |
| ~ | Frontend matrix `lang: [en, nl]` | runs the **identical** build twice; `matrix.lang` is never used | runs once |
| = | `gofmt` check | `test -z $(gofmt -l .)` (breaks when >1 file is unformatted, but still fails) | lists the files and fails |
| = | `go fix` check | `go fix -diff ./...` (non-zero exit on fixes) | `go fix ./...` + `git diff --exit-code` |
| = | golangci-lint v2.12.2, `--timeout 5m`, in `backend/` | `go install` | golangci-lint-action (prebuilt binary + cache) |
| = | Tests via `Dockerfile.test` | yes | yes |
| = | Coverage `/coverage/coverage.out` → Codecov, flag `backend`, fail on error | yes | yes (`coverage-file`, `codecov`, `codecov-flags`) |
| - | GHCR login + `docker/metadata-action` in test job | yes (outputs unused) | removed |
| - | `build-docker-image` job | in Status checks | moved to Delivery (`pull_request`) |
| ~ | Check names (branch protection) | `build-frontend (en)`, `build-frontend (nl)`, `analyze-go`, `test-go`, `build-docker-image` | one gate: **`Status checks passed`** (required via the org ruleset after `opt-in`) |
| ~ | Action versions | `checkout`/`setup-node`/`setup-go` by tag (v6), others by SHA | all by SHA, updated by Dependabot centrally |
| + | Workflow token | default (repo setting) | `contents: read` only |

## Added in v1.1 (new checks that can fail a PR are marked ⚠)

| | Feature | Current | Shared workflow v1.1 |
|---|---|---|---|
| + ⚠ | govulncheck (backend) | no | yes |
| + ⚠ | `go mod tidy` drift | no | yes |
| + ⚠ | CodeQL Go + JS/TS + Actions | no | yes (`security-extended`) |
| + ⚠ | Dependency review on PRs | no | blocks high/critical vulnerable runtime deps |
| + ⚠ | actionlint + zizmor on the repo's workflows | no | yes |
| + | Frontend install without dependency install scripts | no | `ignore-scripts: true` |
| + | `docker build --check` / base images pinned by digest | no | warnings only |
| + | Reproducible image (same commit → same digest) | no | yes |
| + ⚠ | Release commit must be on `main` | no | yes |
| + | Job timeouts | 6 h default | 5–60 min |
| + | `merge_group` trigger (merge queue) | no | yes |
| + | Dependabot: actions, Docker (tag + digest), Go, npm; grouped, 7-day cooldown | no | `.github/dependabot.yml` |

## Before switching (`!`)

1. **Update branch protection / rulesets**: remove the old required checks; after migrating, run `org-settings/apply-org-settings.sh opt-in go-sms-issuer` so `Status checks passed` becomes the single required check.
2. Secrets stay the same (`TURNSTILE_SITE_KEY`, `CODECOV_TOKEN`). No new secrets needed.
3. After the first run, close the code-scanning alerts of the old Anchore category (or set
   `category` to match the old one if you'd rather keep the history).
4. Fix what the new ⚠ checks report first (run them from a branch), or temporarily set
   `govulncheck: false` / `warn-only: true` on dependency review while catching up.
5. The frontend build runs `npm ci --ignore-scripts`; if a dependency needs its install
   script (e.g. esbuild), add it to `allowed-scripts`.
