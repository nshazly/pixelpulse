#!/usr/bin/env bash
# Configure GitHub security and permission settings for this public repository.
#
# Usage:
#   scripts/configure-github-repo.sh [OWNER/REPO]           # dry run: print what would change
#   scripts/configure-github-repo.sh [OWNER/REPO] --apply   # apply the settings
#
# Options:
#   --apply                make the changes (the default is a dry run)
#   --allow-admin-bypass   let repository admins bypass the branch and tag rulesets
#   --no-sha-pinning       don't require workflows to pin actions to a full commit SHA
#
# Requires gh (logged in as an admin of the repo, token scopes: repo, workflow) and jq.
# Run it after the repo exists on GitHub and main has been pushed once.
# Safe to re-run: every call sets an absolute value, and rulesets are updated in place.
#
# Before changing anything, it checks the workflows on the default branch: every
# required status check must have run there, and every action must be allow-listed
# (and SHA-pinned, unless --no-sha-pinning). A mismatch would block every merge or
# every workflow run, so --apply stops instead.

set -euo pipefail

REPO=""
APPLY=false
ADMIN_BYPASS=false
SHA_PINNING=true

for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=true ;;
        --allow-admin-bypass) ADMIN_BYPASS=true ;;
        --no-sha-pinning) SHA_PINNING=false ;;
        -h | --help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
        -*) echo "unknown option: $arg" >&2; exit 2 ;;
        *) REPO="$arg" ;;
    esac
done

command -v gh >/dev/null || { echo "gh is required: https://cli.github.com" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

if [[ -z "$REPO" ]]; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
        echo "Pass OWNER/REPO, or run this from a clone that has a GitHub remote." >&2
        exit 2
    }
fi
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "not an OWNER/REPO: $REPO" >&2; exit 2; }

BRANCH_RULESET="protect-main"
TAG_RULESET="protect-release-tags"
RELEASE_TAG_PATTERN="refs/tags/v*"            # tags that trigger .github/workflows/release.yml
REQUIRED_CHECKS=("Test")                      # job names from .github/workflows/ci.yml
GITHUB_ACTIONS_APP_ID=15368                   # accept those checks only from GitHub Actions
ADMIN_ROLE_ID=5                               # built-in repository "admin" role
ALLOWED_ACTIONS=("softprops/action-gh-release@*")  # on top of GitHub-owned actions
CODEQL_LANGUAGES='["actions"]'
TOPICS='["macos","swift","swiftui","menu-bar-app","display","refresh-rate","samsung-odyssey"]'

failures=()

# api METHOD PATH [JSON_BODY]: PATH is relative to repos/OWNER/REPO.
api() {
    local method=$1 path=$2 body=${3:-}
    if ! $APPLY; then
        echo "    would: $method /repos/$REPO$path${body:+ $(jq -c . <<<"$body")}"
        return 0
    fi
    local args=(--method "$method"
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28"
        "repos/$REPO$path")
    if [[ -n "$body" ]]; then
        gh api "${args[@]}" --input - <<<"$body" >/dev/null
    else
        gh api "${args[@]}" >/dev/null
    fi
}

# step "description" METHOD PATH [JSON_BODY]: keep going on failure, report at the end.
step() {
    local desc=$1
    shift
    echo "  - $desc"
    if ! api "$@"; then
        echo "    FAILED: $desc" >&2
        failures+=("$desc")
    fi
}

# upsert_ruleset NAME DESCRIPTION JSON: update the ruleset with this name, or create it.
upsert_ruleset() {
    local name=$1 desc=$2 body=$3 id=""
    if $repo_exists; then
        id=$(gh api --paginate "repos/$REPO/rulesets" |
            jq -rs --arg n "$name" '[.[][] | select(.name == $n) | .id] | first // empty')
    fi
    if [[ -n "$id" ]]; then
        step "Update ruleset $desc" PUT "/rulesets/$id" "$body"
    else
        step "Create ruleset $desc" POST /rulesets "$body"
    fi
}

echo "Repository: $REPO ($($APPLY && echo "apply" || echo "dry run; add --apply to make changes"))"
repo_exists=false
default_branch=""
if repo_json=$(gh api "repos/$REPO" 2>/dev/null); then
    repo_exists=true
    read -r visibility default_branch is_admin < <(jq -r '[.visibility, .default_branch, .permissions.admin] | @tsv' <<<"$repo_json")
    echo "  visibility=$visibility default_branch=$default_branch admin=$is_admin"
    [[ "$is_admin" == true ]] || { echo "You need admin access to $REPO." >&2; exit 1; }
    [[ "$visibility" == public ]] || echo "  warning: the repo is $visibility; several features below are free only for public repos." >&2
elif $APPLY; then
    echo "Repository $REPO not found. Create it and push main first." >&2
    exit 1
else
    echo "  (repository not found yet; showing the planned changes only)"
fi

echo
echo "Preflight"
problems=()
if $repo_exists; then
    ran=$(gh api --paginate "repos/$REPO/commits/$default_branch/check-runs?per_page=100" |
        jq -rs --argjson app "$GITHUB_ACTIONS_APP_ID" '[.[].check_runs[] | select(.app.id == $app) | .name] | unique | .[]')
    for check in "${REQUIRED_CHECKS[@]}"; do
        if grep -qxF "$check" <<<"$ran"; then
            echo "  ok: required check '$check' ran on $default_branch"
        else
            problems+=("required check '$check' has not run on $default_branch; checks seen: $(paste -sd, - <<<"$ran")")
        fi
    done

    workflows=$(gh api "repos/$REPO/contents/.github/workflows?ref=$default_branch" \
        --jq '.[] | select(.name | test("\\.ya?ml$")) | .path' 2>/dev/null || true)
    for wf in $workflows; do
        while read -r use; do
            [[ -z "$use" || "$use" == ./* || "$use" == docker://* ]] && continue
            action=${use%%@*}
            ref=${use#*@}
            owner=${action%%/*}
            if [[ "$owner" != actions && "$owner" != github ]]; then
                allowed=false
                for pattern in "${ALLOWED_ACTIONS[@]}"; do
                    # shellcheck disable=SC2053  # the pattern is a glob on purpose
                    [[ "$use" == $pattern ]] && allowed=true
                done
                $allowed || problems+=("$wf uses $use, which isn't in ALLOWED_ACTIONS")
            fi
            if $SHA_PINNING && [[ ! "$ref" =~ ^[0-9a-f]{40}$ ]]; then
                problems+=("$wf uses $use, which isn't pinned to a full commit SHA")
            fi
        done < <(gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$wf?ref=$default_branch" |
            sed -nE 's/^[[:space:]-]*uses:[[:space:]]*["'\'']?([^"'\''[:space:]#]+).*/\1/p')
    done
    echo "  checked actions in: $(paste -sd" " - <<<"$workflows")"

    others=$(gh api --paginate "repos/$REPO/rulesets" |
        jq -rs --arg b "$BRANCH_RULESET" --arg t "$TAG_RULESET" \
            '[.[][] | select(.name != $b and .name != $t) | "\(.name) (\(.target), \(.enforcement))"] | .[]')
    if [[ -n "$others" ]]; then
        echo "  note: other rulesets also apply and stack with these (the strictest rule wins):"
        while IFS= read -r line; do echo "      $line"; done <<<"$others"
    fi
fi
if ((${#problems[@]})); then
    printf '  PROBLEM: %s\n' "${problems[@]}" | awk '!seen[$0]++' >&2
    if $APPLY; then
        echo "Fix these before applying, so the new settings don't block merges or workflow runs." >&2
        exit 1
    fi
fi

echo
echo "General"
step "Issues on; wiki, projects and discussions off; squash merges only; delete branches after merge" \
    PATCH "" "$(jq -n '{
        has_issues: true, has_wiki: false, has_projects: false, has_discussions: false,
        allow_squash_merge: true, allow_merge_commit: false, allow_rebase_merge: false,
        allow_auto_merge: false, delete_branch_on_merge: true, allow_update_branch: true,
        squash_merge_commit_title: "PR_TITLE", squash_merge_commit_message: "PR_BODY"}')"
step "Topics" PUT /topics "$(jq -n --argjson t "$TOPICS" '{names: $t}')"

echo
echo "Security"
step "Dependabot alerts" PUT /vulnerability-alerts
step "Dependabot security updates" PUT /automated-security-fixes
step "Secret scanning and push protection" PATCH "" \
    '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
step "Private vulnerability reporting (SECURITY.md points here)" PUT /private-vulnerability-reporting
step "CodeQL default setup for $(jq -r 'join(", ")' <<<"$CODEQL_LANGUAGES")" PATCH /code-scanning/default-setup \
    "$(jq -n --argjson l "$CODEQL_LANGUAGES" '{state: "configured", query_suite: "default", languages: $l}')"
step "Immutable releases: a published release's tag and assets can't change" PUT /immutable-releases

echo
echo "Actions"
step "Allow only selected actions; require full-SHA pinning: $SHA_PINNING" PUT /actions/permissions \
    "$(jq -n --argjson pin "$SHA_PINNING" '{enabled: true, allowed_actions: "selected", sha_pinning_required: $pin}')"
step "Allow-list: GitHub-owned actions and ${ALLOWED_ACTIONS[*]}" PUT /actions/permissions/selected-actions \
    "$(printf '%s\n' "${ALLOWED_ACTIONS[@]}" | jq -R . | jq -s '{github_owned_allowed: true, verified_allowed: false, patterns_allowed: .}')"
step "GITHUB_TOKEN read-only by default; workflows can't approve pull requests" PUT /actions/permissions/workflow \
    '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}'
step "Require approval before running workflows from any outside contributor" \
    PUT /actions/permissions/fork-pr-contributor-approval '{"approval_policy":"all_external_contributors"}'

echo
echo "Rulesets"
bypass=$(jq -n --argjson bypass "$ADMIN_BYPASS" --argjson role "$ADMIN_ROLE_ID" \
    'if $bypass then [{actor_id: $role, actor_type: "RepositoryRole", bypass_mode: "always"}] else [] end')
checks=$(printf '%s\n' "${REQUIRED_CHECKS[@]}" |
    jq -R --argjson app "$GITHUB_ACTIONS_APP_ID" '{context: ., integration_id: $app}' | jq -s .)
upsert_ruleset "$BRANCH_RULESET" \
    "'$BRANCH_RULESET' on the default branch: no deletion or force push; PR (squash) with passing ${REQUIRED_CHECKS[*]}; admin bypass: $ADMIN_BYPASS" \
    "$(jq -n --arg name "$BRANCH_RULESET" --argjson checks "$checks" --argjson bypass "$bypass" '{
        name: $name, target: "branch", enforcement: "active",
        conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
        bypass_actors: $bypass,
        rules: [
            {type: "deletion"},
            {type: "non_fast_forward"},
            {type: "pull_request", parameters: {
                required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
                require_code_owner_review: false, require_last_push_approval: false,
                required_review_thread_resolution: false, allowed_merge_methods: ["squash"]}},
            {type: "required_status_checks", parameters: {
                strict_required_status_checks_policy: false, required_status_checks: $checks}}
        ]}')"
upsert_ruleset "$TAG_RULESET" \
    "'$TAG_RULESET' on $RELEASE_TAG_PATTERN: no deletion, force push or moving; admin bypass: $ADMIN_BYPASS" \
    "$(jq -n --arg name "$TAG_RULESET" --arg pattern "$RELEASE_TAG_PATTERN" --argjson bypass "$bypass" '{
        name: $name, target: "tag", enforcement: "active",
        conditions: {ref_name: {include: [$pattern], exclude: []}},
        bypass_actors: $bypass,
        rules: [{type: "deletion"}, {type: "non_fast_forward"}, {type: "update"}]}')"

if $APPLY; then
    echo
    echo "Resulting settings"
    gh api "repos/$REPO" --jq '{visibility, has_wiki, has_projects, has_discussions, allow_squash_merge,
        allow_merge_commit, allow_rebase_merge, delete_branch_on_merge, topics,
        secret_scanning: .security_and_analysis.secret_scanning.status,
        push_protection: .security_and_analysis.secret_scanning_push_protection.status}' || true
    if gh api "repos/$REPO/vulnerability-alerts" --silent 2>/dev/null; then
        echo '{"dependabot_alerts":"enabled"}'
    else
        echo '{"dependabot_alerts":"disabled"}'
    fi
    gh api "repos/$REPO/private-vulnerability-reporting" || true
    gh api "repos/$REPO/immutable-releases" || true
    gh api "repos/$REPO/code-scanning/default-setup" --jq '{codeql: .state, languages}' || true
    gh api "repos/$REPO/actions/permissions" || true
    gh api "repos/$REPO/actions/permissions/selected-actions" || true
    gh api "repos/$REPO/actions/permissions/workflow" || true
    gh api "repos/$REPO/actions/permissions/fork-pr-contributor-approval" || true
    gh api --paginate "repos/$REPO/rulesets" --jq '.[] | {id, name, target, enforcement}' || true
fi

echo
if ((${#failures[@]})); then
    echo "${#failures[@]} step(s) failed:" >&2
    printf '  - %s\n' "${failures[@]}" >&2
    exit 1
fi
if ((${#problems[@]})); then
    echo "Dry run found ${#problems[@]} problem(s) above; --apply will refuse until they're fixed." >&2
    exit 1
fi
echo "Done."
