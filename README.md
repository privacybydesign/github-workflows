# github-workflows

Reusable GitHub Actions workflows for the [privacybydesign](https://github.com/privacybydesign) (Yivi) repositories.

Status: in development, not released yet.

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

The inputs of each workflow are documented in its file, under `on.workflow_call.inputs`. A reusable workflow gets no more permissions than the calling job grants, so grant the ones its file lists.

On private repositories, artifact attestations are skipped, and `codeql.yml` and `dependency-review.yml` need GitHub Code Security.

## Versioning

Releases are semver tags (`v1.2.0`) with a moving major tag (`v1`); breaking changes get a new major. Third-party actions are pinned to commit SHAs and kept up to date by Dependabot. See [CHANGELOG.md](CHANGELOG.md).
