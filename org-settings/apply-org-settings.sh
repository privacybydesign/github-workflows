#!/usr/bin/env bash
# Apply the privacybydesign organisation baseline for GitHub Actions and
# repository security. Idempotent: existing rulesets / configurations with the
# same name are updated.
#
# Usage:
#   ORG=privacybydesign ./apply-org-settings.sh baseline        # dry run (prints requests)
#   APPLY=1 ORG=privacybydesign ./apply-org-settings.sh baseline
#   APPLY=1 ORG=privacybydesign ./apply-org-settings.sh strict  # phase 2, see below
#   APPLY=1 ORG=privacybydesign ./apply-org-settings.sh opt-in go-sms-issuer irmago
#
# Phases:
#   baseline  - GITHUB_TOKEN read-only by default, Actions can't approve PRs
#             - allowed actions: GitHub-owned, verified creators, allowlist
#             - custom property `shared-ci` (repos opt in to the required check)
#             - rulesets: default-branch protection, required "Status checks passed"
#               (only for repos with shared-ci=v1), immutable v* tags
#             - security configuration: secret scanning + push protection,
#               Dependabot alerts/updates, private vulnerability reporting
#               (attached to public repos; set ATTACH_SCOPE=all to include private)
#   strict    - require SHA-pinned actions org-wide (only after every repo's
#               workflows are pinned, check with zizmor/workflow-lint first)
#             - immutable releases for all repos (only after go-release.yml
#               callers use the tag-push/draft flow from v1.1)
#   opt-in    - set shared-ci=v1 on the given repositories once they have
#               a "Status checks passed" job
#
# Requires: gh (authenticated as an org owner), jq.
# Optional: RELEASE_APP_ID - GitHub App that may create release tags.

set -euo pipefail
ORG="${ORG:?set ORG}"
APPLY="${APPLY:-0}"
ATTACH_SCOPE="${ATTACH_SCOPE:-public}"
HERE="$(cd "$(dirname "$0")" && pwd)"

api() { # api METHOD PATH [JSON]
  local method="$1" path="$2" body="${3:-}"
  if [ "$APPLY" != 1 ]; then
    echo "DRY RUN: gh api -X $method $path"; [ -n "$body" ] && jq . <<< "$body"
    return 0
  fi
  local out
  if [ -n "$body" ]; then out="$(gh api -X "$method" "$path" --input - <<< "$body")"
  else out="$(gh api -X "$method" "$path")"; fi
  if [ "${RAW:-0}" = 1 ]; then echo "$out"; fi
}

upsert_ruleset() {
  local file="$1" name body id
  body="$(cat "$file")"
  if [ -n "${RELEASE_APP_ID:-}" ]; then
    body="$(jq --argjson id "$RELEASE_APP_ID" '(.bypass_actors[] | select(.actor_type=="Integration") | .actor_id) = $id' <<< "$body")"
  else
    body="$(jq 'del(.bypass_actors[] | select(.actor_type=="Integration"))' <<< "$body")"
  fi
  name="$(jq -r .name <<< "$body")"
  id="$(gh api "orgs/$ORG/rulesets" --paginate --jq ".[] | select(.name==\"$name\") | .id" || true)"
  if [ -n "$id" ]; then echo "update ruleset $name"; api PUT "orgs/$ORG/rulesets/$id" "$body"
  else echo "create ruleset $name"; api POST "orgs/$ORG/rulesets" "$body"; fi
}

baseline() {
  echo "== Actions: read-only GITHUB_TOKEN, no PR approvals by Actions"
  api PUT "orgs/$ORG/actions/permissions/workflow" \
    '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}'

  echo "== Actions: allowed actions"
  api PUT "orgs/$ORG/actions/permissions" '{"enabled_repositories":"all","allowed_actions":"selected"}'
  api PUT "orgs/$ORG/actions/permissions/selected-actions" "$(cat "$HERE/allowed-actions.json")"

  echo "== Custom property shared-ci"
  api PUT "orgs/$ORG/properties/schema/shared-ci" \
    '{"value_type":"single_select","required":false,"allowed_values":["v1"],"description":"Repository uses the shared workflows and has a \"Status checks passed\" job","values_editable_by":"org_actors"}'

  echo "== Rulesets"
  for f in "$HERE"/rulesets/*.json; do upsert_ruleset "$f"; done

  echo "== Security configuration"
  local body name id
  body="$(cat "$HERE/security-configuration.json")"
  name="$(jq -r .name <<< "$body")"
  id="$(gh api "orgs/$ORG/code-security/configurations" --paginate --jq ".[] | select(.name==\"$name\") | .id" || true)"
  if [ -n "$id" ]; then api PATCH "orgs/$ORG/code-security/configurations/$id" "$body"
  else
    if [ "$APPLY" = 1 ]; then id="$(RAW=1 api POST "orgs/$ORG/code-security/configurations" "$body" | jq -r .id)"
    else api POST "orgs/$ORG/code-security/configurations" "$body"; id="<new-id>"; fi
  fi
  api POST "orgs/$ORG/code-security/configurations/$id/attach" "{\"scope\":\"$ATTACH_SCOPE\"}"
  api PUT "orgs/$ORG/code-security/configurations/$id/defaults" '{"default_for_new_repos":"public"}'
}

strict() {
  echo "== Require SHA-pinned actions"
  api PUT "orgs/$ORG/actions/permissions" '{"enabled_repositories":"all","allowed_actions":"selected","sha_pinning_required":true}'
  echo "== Immutable releases for all repositories"
  api PUT "orgs/$ORG/settings/immutable-releases" '{"enforced_repositories":"all"}'
}

opt_in() {
  [ "$#" -gt 0 ] || { echo "usage: $0 opt-in <repo>..."; exit 1; }
  local names
  names="$(printf '%s\n' "$@" | jq -R . | jq -cs .)"
  api PATCH "orgs/$ORG/properties/values" \
    "{\"repository_names\":$names,\"properties\":[{\"property_name\":\"shared-ci\",\"value\":\"v1\"}]}"
}

case "${1:-}" in
  baseline) baseline ;;
  strict)   strict ;;
  opt-in)   shift; opt_in "$@" ;;
  *) sed -n '2,32p' "$0"; exit 1 ;;
esac
[ "$APPLY" = 1 ] || echo "(dry run - set APPLY=1 to apply)"
