# privacybydesign/github-workflows

Shared, versioned CI/CD workflows for every repository in the
[`privacybydesign`](https://github.com/privacybydesign) organisation. Covers Go,
Docker, Node/npm and Terraform. Current version: **v1.1** (see
[CHANGELOG.md](CHANGELOG.md)).

Repositories call these workflows with a short caller file instead of copying
150+ lines of YAML. Fixes, action bumps and security hardening are made once
and released as a new `v1.x` tag.

## Why a separate repository

| Option | Verdict |
|---|---|
| **Dedicated public repo `privacybydesign/github-workflows`** with reusable workflows (`on: workflow_call`) | ✅ **Chosen.** Public repos can only call reusable workflows that live in a *public* repo, and private repos can call public ones too, so a single public repo serves the whole organisation. Releases are tagged, Dependabot keeps it current, and it has its own CI. |
| Org `.github` repo with `workflow-templates/` | ✅ **Also used, for onboarding.** Templates show up under *Actions → New workflow* in every repo. They are only copied once, so they hold the **thin caller** files and never the logic itself. See [`org-dot-github/`](org-dot-github). |
| Composite actions only | Not enough on their own. They can't define jobs, matrices, permissions, environments or concurrency. |
| Private shared repo | Public repositories can't use it. |

## Layout

```
.github/workflows/
  docker-publish.yml     build once → Dockerfile checks → scan → push unchanged to GHCR; edge / semver / branch
                         tags; multi-arch; SBOM + provenance + attestation; reproducible; optional cosign;
                         `push-image: false` for PR checks
  image-rescan.yml       weekly scan of the PUBLISHED tags, every platform
  ghcr-cleanup.yml       retention: delete unreferenced untagged versions (dry run by default)
  go-checks.yml          gofmt, go fix, go mod tidy, golangci-lint v2, govulncheck, tests (native or Dockerfile.test), Codecov
  go-release.yml         cross-compile → SBOM → checksums → attest → draft release → publish (immutable-release safe)
  node-checks.yml        npm / Yarn / pnpm install (optionally without install scripts) + lint/test/build
  npm-publish.yml        npm Trusted Publishing (OIDC), tag-driven or semantic-release
  terraform.yml          fmt, validate, tflint, Checkov, plan + PR comment, gated apply, drift detection
  codeql.yml             CodeQL for Go, JS/TS and the workflow files themselves
  dependency-review.yml  block PRs that add vulnerable / disallowed-licence dependencies
  workflow-lint.yml      actionlint + zizmor for any repository's workflows
  pr-title.yml           Conventional Commit PR titles
  release-please.yml     release PRs + GitHub releases (via GitHub App so downstream workflows fire)
  self-ci.yml            CI for this repo (uses workflow-lint.yml)
org-dot-github/          → copy into privacybydesign/.github
  workflow-templates/    caller templates + .properties.json (shown in "New workflow")
templates/               files to copy into each repository: dependabot.yml, zizmor.yml
org-settings/            org rulesets, allowed actions, security configuration + apply script
examples/                before → after migrations for real repositories
zizmor.yml
```

## What the public repositories do today

I sparse-cloned all 49 non-archived public repositories (October 2026) and
counted what they use:

| Pattern | Repos | Covered by |
|---|---|---|
| `Delivery`: Docker build → push `ghcr.io/<repo>` with `:edge` on main, `:<x.y.z>` on release, `:<branch>` on manual runs | **30** | `docker-publish.yml` |
| Anchore image scan + SARIF upload to code scanning | 19 | `docker-publish.yml` |
| Go: `setup-go` from `go.mod`, gofmt, `go fix`, golangci-lint v2.12, tests via `Dockerfile.test` | 14 | `go-checks.yml` |
| Node: `setup-node` 24, `npm ci`/`yarn --immutable`, lint/test/build | 13 | `node-checks.yml` |
| Cross-compiled Go binaries uploaded to a release (irmago) | 1 (+gmrtd) | `go-release.yml` |
| npm publishing with Trusted Publishing + multi-semantic-release (yivi-frontend-packages) | 1 | `npm-publish.yml` |
| Conventional commits / release-please (gmrtd, yivi-frontend-packages) | 2 | `pr-title.yml`, `release-please.yml` |
| Scheme-manager repos (`pbdf-*`, `irma-demo-*`) | 6 | Out of scope: they're domain-specific. They could be a later `scheme-checks.yml`. |
| Flutter / Dart (irmamobile, vcmrtd, flutter_nfc_kit, …) | ~7 | Out of scope (not one of the four target ecosystems) |
| **Terraform** | **0 public** | `terraform.yml` follows general best practice. Check it against the private infrastructure repositories. |

### Problems in the current copies that the shared versions fix

1. **The scanned image isn't the published image.** Most `delivery.yml` files
   build once with `load: true` to scan, then build again to push, and assume
   the GHA cache gives the same result. `docker-publish.yml` builds **once**
   into an OCI archive on the runner and scans the first platform's manifest
   from that archive. Only if the scan passes does it push the archive with
   `skopeo copy --all --preserve-digests`, then check that the registry digest
   matches. A failed scan leaves nothing in GHCR, and multi-arch images can be
   scanned, which `load: true` can't do.
2. **Release candidates overwrite stable tags.** `type=semver,pattern={{major}}.{{minor}}.{{patch}}`
   turns `v1.2.0-rc.1` into `:1.2.0`. The shared workflow uses `{{version}}`,
   so an RC only gets `:1.2.0-rc.1`. The optional roll-up tags skip
   pre-releases.
3. **The "every Monday" scan runs on Sunday.** 11 repos say Monday in a comment
   but use `cron: '0 9 * * 0'`, which is Sunday.
4. **Pinning and action versions drift.** Repos use `checkout` v4, v5, v6 and
   v7 and four different `build-push-action` majors, and only 10 of 48 pin
   actions to commit SHAs. Everything in this repo is SHA-pinned and kept
   current by Dependabot.
5. **The `:edge` tag can go backwards.** Edge is only applied when the commit
   is still the HEAD of the default branch, and publishing runs for the same
   branch are serialised (irmago does this; the others don't).
6. **No supply-chain metadata.** Images get SBOM and max-mode provenance from
   BuildKit, plus a GitHub artifact attestation (`gh attestation verify`) on
   public repos.
7. **Too many token permissions.** Workflows start at `permissions: {}` and each
   job requests only what it needs. `contents: write` is no longer granted to
   Docker jobs.
8. **Releases made by release-please don't trigger `Delivery`.** A release made
   with `GITHUB_TOKEN` doesn't fire `release: published`. `release-please.yml`
   takes an org GitHub App token for this.

### Security baseline added in v1.1

| Area | What runs | Where |
|---|---|---|
| Go vulnerabilities | `govulncheck` (only reports vulnerable code you actually call) | go-checks |
| Dependency hygiene | `go mod tidy` drift check; npm/Yarn/pnpm install **without lifecycle scripts** (opt-in input, on in templates) | go-checks, node-checks |
| New dependencies | Dependency review: blocks PRs adding high/critical vulnerabilities or disallowed licences | dependency-review |
| SAST | CodeQL `security-extended` for Go, JS/TS and **GitHub Actions** | codeql |
| Workflow security | actionlint + zizmor in every repo, not only here | workflow-lint |
| Dockerfiles | `docker build --check`, base images pinned by digest (warn by default) | docker-publish |
| Images | scanned before push, reproducible (`SOURCE_DATE_EPOCH`), optional keyless cosign; weekly rescan of published tags on all platforms; retention clean-up | docker-publish, image-rescan, ghcr-cleanup |
| Releases | release commit must be on the default branch; Go binaries get SBOM + SBOM attestation; draft → upload → publish works with immutable releases | docker-publish, go-release, npm-publish |
| Terraform | Checkov IaC scan, weekly drift detection, pinned tflint | terraform |
| Robustness | `timeout-minutes` on every job, superseded PR runs cancelled, `merge_group` triggers, one required **"Status checks passed"** gate job per repo | all |
| Dependencies | grouped Dependabot updates with 7-day cooldown for actions, Docker (tag + digest), Go, npm, Terraform | templates/dependabot.yml |
| Organisation | read-only `GITHUB_TOKEN`, allowed-actions list, rulesets, secret scanning + push protection, then SHA pinning + immutable releases | org-settings/ |
| Public repos | OpenSSF Scorecard | yivi-scorecard template |

## Using it

Each repository adds small caller workflows, usually from *Actions → New
workflow → "Yivi: …"* once the templates are in `privacybydesign/.github`.

A typical Go service ends up with four small files, all from the templates:

| File | Template | Triggers |
|---|---|---|
| `status-checks.yml` | Yivi: Status checks (Go) | push, pull_request, merge_group, weekly |
| `delivery.yml` | Yivi: Docker delivery | push to default branch, release published, manual |
| `image-rescan.yml` | Yivi: Image rescan | weekly |
| `.github/dependabot.yml` | `templates/dependabot.yml` | – |

Every Status checks workflow ends in one job named **`Status checks passed`**
that depends on all other jobs. That is the only check the org ruleset
requires, so jobs can be added or renamed without touching branch protection.

```yaml
  passed:
    name: Status checks passed
    if: always()
    needs: [go, docker, codeql, dependency-review, workflow-lint]
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions: {}
    steps:
      - env:
          RESULTS: ${{ toJSON(needs.*.result) }}
        run: if grep -qE '"(failure|cancelled)"' <<< "$RESULTS"; then exit 1; fi
```

A reusable workflow can't get more permissions than its caller job grants, so
each template lists exactly what that workflow needs.

See [`examples/`](examples) for full migrations of `go-sms-issuer`,
`go-email-issuer` and `irmago`.

### Inputs at a glance

| Workflow | Key inputs (defaults keep v1.0 behaviour; **new in v1.1** in bold) |
|---|---|
| docker-publish | `image-name`, `context`, `dockerfile`, `platforms` (linux/amd64), `build-args`, `target`, `tag-latest`, `tag-semver-rollups`, `scan-severity-cutoff` (critical), `scan-fail-build`, `attest`, **`push-image`** (true), **`require-release-on-default-branch`** (true), **`dockerfile-check`** (warn), **`base-image-pinning`** (warn), **`reproducible`** (true), **`cosign`** (false), **`timeout-minutes`** (60); secrets `DOCKER_BUILD_ARGS`, `DOCKER_BUILD_SECRETS` |
| image-rescan | `image-name`, `tags` (edge latest-release), `severity-cutoff` (high), `fail-build` |
| ghcr-cleanup | `package-name`, `dry-run` (true), `min-age-days` (14), `delete-tags-regex`, `tag-max-age-days` (90), `max-deletions` (200); secret `PACKAGES_TOKEN` |
| go-checks | `working-directory`, `go-version`, `golangci-lint-version` (v2.12.2), `check-gofmt`, `check-go-fix`, **`check-go-mod-tidy`** (true), **`govulncheck`** (true), `lint`, `test-command`, `test-dockerfile`, `coverage-file`, `codecov`, `apt-packages`, **`timeout-minutes`** |
| go-release | `binary-name`*, `main-package`, `targets`, `ldflags`, `version-variable`, `require-changelog-entry`, **`require-release-on-default-branch`**, **`sbom`** (true), `attest`; secrets **`RELEASE_APP_ID`/`RELEASE_APP_PRIVATE_KEY`** |
| node-checks | `working-directory`, `node-version`, `scripts` (lint test build), **`ignore-scripts`** (false; true in templates), **`allowed-scripts`**, `audit`, **`timeout-minutes`** |
| npm-publish | `working-directory`, `node-version`, `access`, `check-version`, `release-command`, `dry-run`, **`require-release-on-default-branch`**; secret `NPM_TOKEN` |
| terraform | `working-directory`, `terraform-version`, `backend-config`, `var-file`, `tflint`, **`tflint-version`**, **`checkov`** (warn), **`checkov-skip-checks`**, `plan`, `apply`, `environment`, **`fail-on-drift`** (true); secret `TF_ENV` |
| codeql | `languages` (["actions"]), `queries` (security-extended), `go-version-file`, `go-build-command`, `config-file` |
| dependency-review | `fail-on-severity` (high), `fail-on-scopes` (runtime), `allow-licenses`/`deny-licenses`, `comment-summary-in-pr`, `warn-only` |
| workflow-lint | `actionlint-version`, `zizmor-version`, `zizmor-config` (.github/zizmor.yml), `zizmor-min-severity` (medium), `paths` |

Repos with several images (yivi-portal, yivi-businesswallet,
yivi-boarding-pass) call `docker-publish.yml` once per image. You can do this
with a matrix over `dockerfile`/`context`/`image-name`.

## Private repositories

* Private repos can call these workflows as they are. Nothing here needs the
  shared repo to be private.
* Artifact attestations and npm provenance need a public source repo (or
  GitHub Enterprise Cloud), so they turn off automatically when
  `github.event.repository.private` is true.
* Secrets are always passed **explicitly** (`secrets: TF_ENV: ...`), never with
  `secrets: inherit`, so a workflow only sees the secrets it needs.
* CodeQL and dependency review need GitHub Code Security on private repos;
  without it, drop those two jobs from the private repo's Status checks.
* `cosign: true` works for private repos too, but writes the repository name
  and digest to the **public** Rekor transparency log.

## Versioning and change management

* Use semver tags: `v1.0.0`, `v1.1.0`, … plus a moving **`v1`** major tag.
  Callers use `@v1` for our own workflows (allowed by the shared `zizmor.yml`)
  and get fixes automatically. Breaking input changes become `v2`.
* Every third-party action is pinned by SHA with a `# vX.Y.Z` comment.
  Dependabot (`.github/dependabot.yml`, 7-day cooldown) opens grouped bump PRs.
* `self-ci.yml` runs actionlint and zizmor on every PR. Before moving `v1`,
  test the change from a canary repo (for example `go-email-issuer`) by
  pointing it at `@<branch>`.
* Protect `main` and the `v*` tags (ruleset: only maintainers can create or
  move them). Anyone who can move `v1` can run code in every repository's
  pipeline.
* If the org turns on *require SHA pinning* (`org-settings` strict phase) and
  it turns out to cover reusable workflows too, switch callers from `@v1` to
  `@<sha> # v1.1.0`; Dependabot's github-actions ecosystem bumps those.

## Organisation settings

[`org-settings/apply-org-settings.sh`](org-settings/apply-org-settings.sh)
applies everything that isn't YAML. It's a dry run unless `APPLY=1`.

| Phase | What |
|---|---|
| `baseline` | read-only `GITHUB_TOKEN` and no PR approvals by Actions; allowed actions = GitHub-owned + verified creators + [allowlist](org-settings/allowed-actions.json); rulesets [default-branch protection](org-settings/rulesets/default-branch.json), [immutable `v*` tags](org-settings/rulesets/release-tags.json) (maintainers, admins and the release App may create them) and [required "Status checks passed"](org-settings/rulesets/required-status-checks.json) for repos with custom property `shared-ci=v1`; [security configuration](org-settings/security-configuration.json) with secret scanning + push protection, Dependabot alerts/updates and private vulnerability reporting |
| `opt-in <repo>…` | sets `shared-ci=v1` once a repo has the gate job, so the required check never blocks unmigrated repos |
| `strict` | require SHA-pinned actions org-wide; immutable releases for all repos. Run only after all repos are pinned and Go binaries use the v1.1 draft flow |

npm packages: once Trusted Publishing works, set each package's *Publishing
access* to "Require two-factor authentication and disallow tokens" on
npmjs.com.

## Roll-out plan

1. Create the public `privacybydesign/github-workflows` repo from this folder,
   tag `v1.1.0` and point `v1` at it.
2. Copy `org-dot-github/workflow-templates/` into `privacybydesign/.github`.
3. Create the org release GitHub App (contents, pull-requests, issues: write).
   Store `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` as org secrets.
4. Run `org-settings/apply-org-settings.sh baseline` (dry run first).
5. Migrate the canaries: `go-sms-issuer`/`go-email-issuer` (Go + Docker +
   Node) and `irmago` (multi-arch + binaries, tag-push release flow). Compare
   GHCR tags with the current ones, then `opt-in` them.
6. Migrate the other repositories (Go issuers, Docker web apps, TypeScript
   services, private repos, Terraform repos), adding `templates/dependabot.yml`
   and the image-rescan / ghcr-cleanup templates, and `opt-in` each one.
7. Once every repo pins its actions and uses the draft release flow, run the
   `strict` phase.
8. Remove the old copied workflows.
