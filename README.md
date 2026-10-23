# github-workflows

Reusable GitHub Actions workflows for the [privacybydesign](https://github.com/privacybydesign) (Yivi) repositories.

## Workflows

| Workflow | What it does |
|---|---|
| `go-checks.yml` | gofmt, `go fix`, `go mod tidy`, golangci-lint, govulncheck and tests |
| `docker-publish.yml` | Builds an image once, scans it, and pushes that same image with SBOM and provenance |
| `image-rescan.yml` | Rescans published image tags |
| `ghcr-cleanup.yml` | Deletes old untagged GHCR package versions |
| `go-release.yml` | Cross-compiled Go binaries with SBOM and checksums on a GitHub release |
| `node-checks.yml` | npm, Yarn or pnpm install, then lint, test and build |
| `npm-publish.yml` | Publishes to npm with Trusted Publishing |
| `terraform.yml` | fmt, validate, tflint, Checkov, plan and apply |
| `codeql.yml` | CodeQL for Go, JavaScript/TypeScript and workflow files |
| `dependency-review.yml` | Blocks pull requests that add vulnerable or disallowed-licence dependencies |
| `workflow-lint.yml` | actionlint and zizmor |
| `pr-title.yml` | Checks that pull request titles follow Conventional Commits |
| `release-please.yml` | Release pull requests and GitHub releases |

## Usage

Call a workflow from a job in your repository:

```yaml
jobs:
  go:
    uses: privacybydesign/github-workflows/.github/workflows/go-checks.yml@v1
    permissions:
      contents: read
```

Copy [`templates/dependabot.yml`](templates/dependabot.yml) to your `.github/` directory: Dependabot keeps your third-party actions pinned and current. workflow-lint allows `@v1` for these workflows and requires a commit SHA for every other action; add [`templates/zizmor.yml`](templates/zizmor.yml) as `.github/zizmor.yml` only if you need to change that policy.

### Starting a new repository

In the privacybydesign organization, a pull request can only merge once a check named `Status checks passed` succeeds. The templates in [`templates/workflows/`](templates/workflows) give you that check:

1. Copy `status-checks-go.yml` or `status-checks-node.yml` to `.github/workflows/status-checks.yml` and adjust the inputs (working directory, Dockerfile, languages). It ends in the `Status checks passed` job.
2. Copy `templates/dependabot.yml` to `.github/dependabot.yml` and remove the ecosystems you don't use.
3. If the repository publishes a container image, also add `delivery.yml` and `image-rescan.yml`.

Open a pull request with these files. It runs the new status checks itself, so it can merge once they pass. Other templates: `release-please.yml`, `go-release.yml`, `npm-publish.yml`, `pr-title.yml`, `terraform.yml`, `ghcr-cleanup.yml` and `scorecard.yml`.

The inputs of each workflow are documented in its file, under `on.workflow_call.inputs`. A reusable workflow gets no more permissions than the calling job grants, so grant the ones its file lists.

On private repositories, artifact attestations are skipped, and `codeql.yml` and `dependency-review.yml` need GitHub Code Security.

## Versioning

Releases are semver tags (`v1.2.0`) with a moving major tag (`v1`), so a release reaches every caller without a change in each repository; breaking changes get a new major. Only maintainers can move `v1`, and changes are tried from a canary repository first. Third-party actions in these workflows are pinned to commit SHAs and kept up to date by Dependabot. See [CHANGELOG.md](CHANGELOG.md).

## License

[Apache License 2.0](LICENSE).
