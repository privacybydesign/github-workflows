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

Call a workflow from a job in your repository, pinned to the commit SHA of a release:

```yaml
jobs:
  go:
    uses: privacybydesign/github-workflows/.github/workflows/go-checks.yml@<commit-sha> # v1.1.0
    permissions:
      contents: read
```

Copy [`templates/dependabot.yml`](templates/dependabot.yml) and [`templates/zizmor.yml`](templates/zizmor.yml) to your `.github/` directory: Dependabot then bumps the SHA and the version comment when a new release comes out, and zizmor rejects workflows and actions that are not pinned to a SHA.

The inputs of each workflow are documented in its file, under `on.workflow_call.inputs`. A reusable workflow gets no more permissions than the calling job grants, so grant the ones its file lists.

On private repositories, artifact attestations are skipped, and `codeql.yml` and `dependency-review.yml` need GitHub Code Security.

## Versioning

Releases are semver tags (`v1.2.0`); breaking changes get a new major. There is no moving major tag: callers pin a commit SHA, so a release can't change under them. Third-party actions in these workflows are pinned the same way and kept up to date by Dependabot. See [CHANGELOG.md](CHANGELOG.md).

## License

[Apache License 2.0](LICENSE).
