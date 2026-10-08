#!/bin/bash
# Moves Formula/tailscale.rb to Tailscale's latest release with the exit-node
# patch merged onto it, and opens a pull request when the merge is clean and
# the router tests and build pass. Opens an issue instead when the patch no
# longer applies or Tailscale has shipped the fix itself.
#
# Written for the GitHub macOS runner: bash 3.2 and BSD tools. LATEST
# overrides the release to target; DRY_RUN=1 prints instead of pushing.
set -euo pipefail

formula=Formula/tailscale.rb
router=wgengine/router/osrouter/router_userspace_bsd.go
upstream_fix=https://github.com/tailscale/tailscale/pull/18202

current=$(sed -n 's/^ *tag: *"\(v[0-9.]*\)",$/\1/p' "$formula")
latest=${LATEST:-$(gh release view --repo tailscale/tailscale --json tagName --jq .tagName)}
if [ -z "$current" ] || [ -z "$latest" ]; then
	echo "could not read the current ($current) or latest ($latest) version" >&2
	exit 1
fi
if [ "$current" = "$latest" ]; then
	echo "tailscale is up to date at $current"
	exit 0
fi
branch="tailscale-$latest"
if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
	echo "$branch already has a pull request"
	exit 0
fi

# issue opens an issue once; an open one with the same title means a person
# already knows.
issue() {
	if [ -n "${DRY_RUN:-}" ]; then
		printf 'would open issue: %s\n%s\n' "$1" "$2"
		return
	fi
	if [ "$(gh issue list --state open --search "in:title \"$1\"" --json number --jq length)" != 0 ]; then
		return
	fi
	gh issue create --title "$1" --body "$2"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk 'found { print } /^__END__$/ { found = 1 }' "$formula" >"$work/exit-nodes.patch"
# A full clone, since the three-way merge needs the blob the patch was cut
# from, which lives in the old release's history.
git clone --quiet --branch "$latest" https://github.com/tailscale/tailscale.git "$work/src"

if git -C "$work/src" apply --reverse --check "$work/exit-nodes.patch" 2>/dev/null; then
	issue "Tailscale $latest includes the exit-node fix" "Tailscale $latest already contains the exit-node patch ($upstream_fix), so Formula/tailscale.rb can go back to Homebrew core's tailscale."
	exit 0
fi
if ! out=$(git -C "$work/src" apply -3 "$work/exit-nodes.patch" 2>&1); then
	state=$(gh pr view "$upstream_fix" --json state --jq .state 2>/dev/null || echo unknown)
	issue "The exit-node patch no longer applies to Tailscale $latest" "$(printf 'Merging the patch onto %s failed. The upstream fix (%s) is %s.\n\n~~~\n%s\n~~~' "$latest" "$upstream_fix" "$state" "$out")"
	exit 1
fi
if ! out=$(cd "$work/src" && go test ./wgengine/router/osrouter/ 2>&1 && go build ./cmd/tailscale ./cmd/tailscaled 2>&1); then
	issue "The exit-node patch fails tests on Tailscale $latest" "$(printf 'The patch merged onto %s, but the router tests or the build failed.\n\n~~~\n%s\n~~~' "$latest" "$out")"
	exit 1
fi

revision=$(git -C "$work/src" rev-parse "$latest^{commit}")
awk -v tag="$latest" -v rev="$revision" '
	/^ *tag: *"v/ { sub(/"v[^"]*"/, "\"" tag "\"") }
	/^ *revision: *"/ { sub(/"[0-9a-f]+"/, "\"" rev "\"") }
	{ print }
	/^__END__$/ { exit }
' "$formula" >"$work/formula.rb"
git -C "$work/src" diff --full-index HEAD -- "$router" >>"$work/formula.rb"
mv "$work/formula.rb" "$formula"

if [ -n "${DRY_RUN:-}" ]; then
	git diff --stat -- "$formula"
	exit 0
fi
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git switch --create "$branch"
git commit --quiet --all --message "chore: update tailscale to $latest with the exit-node patch"
git push --quiet origin "$branch"
gh pr create --head "$branch" --title "chore: update tailscale to $latest with the exit-node patch" \
	--body "Tailscale $latest is out. The exit-node patch ($upstream_fix) merged onto it cleanly, and the router tests and the build pass on macOS. Merge this, and the next brewski builds and installs it."
