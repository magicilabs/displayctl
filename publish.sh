#!/bin/sh
# Cuts a release: builds the app, signs it with the Developer ID, has Apple
# notarize it, tags the current commit, uploads the zip to a GitHub release,
# and opens a pull request on ../homebrew-tap with the updated cask and formula.
#
#   ./publish.sh 0.1.6
#
# Run it from main once the release commit is merged. It never pushes a branch
# other than the tap's release branch; the tap change lands when its pull
# request is merged. Casks/displayctl.rb and Formula/displayctl.rb here are
# templates: the version and checksums are filled in on the tap's copy.
#
# Defaults to the first Developer ID Application certificate in the keychain
# and the notarytool profile "magicilabs". Override with SIGN_IDENTITY and
# NOTARY_PROFILE. To create the profile once:
#   xcrun notarytool store-credentials magicilabs --apple-id ... --team-id ...
set -e

cd "$(dirname "$0")"
VERSION="${1:?usage: ./publish.sh 0.1.6}"
REPO="magicilabs/displayctl"
ZIP="dist/DisplayCtl-$VERSION.zip"
TAP=../homebrew-tap
NOTARY_PROFILE="${NOTARY_PROFILE:-magicilabs}"

command -v gh >/dev/null || { echo "install the GitHub CLI first: brew install gh" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "sign in first: gh auth login" >&2; exit 1; }
# Releases show the account that created them, so make sure it is the right one.
[ "$(gh api user --jq .login)" = magicilabs-admin ] || { echo "switch first: gh auth switch -u magicilabs-admin" >&2; exit 1; }
git diff --quiet HEAD || { echo "commit or stash your changes first" >&2; exit 1; }
[ -d "$TAP/.git" ] || { echo "check out magicilabs/homebrew-tap next to this repo first" >&2; exit 1; }

if [ -z "$SIGN_IDENTITY" ]; then
	SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
fi
[ -n "$SIGN_IDENTITY" ] || { echo "no Developer ID Application certificate in the keychain" >&2; exit 1; }
export SIGN_IDENTITY

VERSION="$VERSION" ./make-app.sh >/dev/null
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent DisplayCtl.app "$ZIP"

# Notarize and staple the ticket to the app, so Gatekeeper opens it without
# asking even offline. Stapling fails unless Apple accepted it, which stops
# the release here.
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple DisplayCtl.app
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent DisplayCtl.app "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

git tag -f "v$VERSION"
git push -qf origin "v$VERSION"
gh release create "v$VERSION" "$ZIP" --repo "$REPO" --title "v$VERSION" --generate-notes \
	|| gh release upload "v$VERSION" "$ZIP" --repo "$REPO" --clobber

# The formula builds from the tag's source tarball, which only exists once the
# tag is pushed. Download to a file first: in a pipe, a failed download would
# go unnoticed and leave the checksum of empty input.
TARBALL="https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz"
curl -fsSL -o dist/source.tar.gz "$TARBALL" || { echo "cannot download $TARBALL" >&2; exit 1; }
SRC_SHA=$(shasum -a 256 dist/source.tar.gz | cut -d' ' -f1)

# The cask and formula go to the tap on their own branch and a pull request.
BRANCH="displayctl-$VERSION"
git -C "$TAP" fetch -q origin
git -C "$TAP" checkout -q -B "$BRANCH" origin/main
mkdir -p "$TAP/Casks" "$TAP/Formula"
sed -e "s|^  version \".*\"|  version \"$VERSION\"|" \
    -e "s|^  sha256 \".*\"|  sha256 \"$SHA\"|" Casks/displayctl.rb > "$TAP/Casks/displayctl.rb"
sed -e "s|^  url \".*\"|  url \"$TARBALL\"|" \
    -e "s|^  sha256 \".*\"|  sha256 \"$SRC_SHA\"|" Formula/displayctl.rb > "$TAP/Formula/displayctl.rb"
git -C "$TAP" add Casks/displayctl.rb Formula/displayctl.rb
git -C "$TAP" commit -q -m "displayctl $VERSION"
git -C "$TAP" push -qf origin "$BRANCH"
gh pr create --repo magicilabs/homebrew-tap --head "$BRANCH" --base main \
	--title "displayctl $VERSION" --body "Cask and formula for displayctl $VERSION." \
	|| echo "pull request for $BRANCH already open"
git -C "$TAP" checkout -q main

echo
echo "released v$VERSION  sha256=$SHA"
echo "merge the tap pull request, then: brew upgrade --cask displayctl"
