#!/bin/bash
# Update changelog files that tbump can't handle automatically
# Called by tbump before_commit hook
#
# Usage: ./scripts/update-changelogs.sh <new_version> <prev_version> [message]

set -e

NEW_VERSION="$1"
PREV_VERSION="$2"
MESSAGE="${3:-Version bump}"
DATE=$(date -R)  # RFC 2822 format for debian
RPM_DATE=$(date "+%a %b %d %Y")  # RPM changelog format

if [[ -z "$NEW_VERSION" ]] || [[ -z "$PREV_VERSION" ]]; then
    echo "Usage: $0 <new_version> <prev_version> [message]"
    exit 1
fi

# =============================================================================
# Debian changelog (dkms/debian/changelog)
# =============================================================================

DEBIAN_CHANGELOG="dkms/debian/changelog"

if [[ -f "$DEBIAN_CHANGELOG" ]]; then
    echo "Updating $DEBIAN_CHANGELOG..."

    # Create new entry
    NEW_ENTRY="mt76-mt7925-dkms (${NEW_VERSION}-1) unstable; urgency=medium

  * ${MESSAGE}

 -- Zac Bowling <zac@zacbowling.com>  ${DATE}
"

    # Prepend to existing changelog
    echo "$NEW_ENTRY" | cat - "$DEBIAN_CHANGELOG" > "${DEBIAN_CHANGELOG}.tmp"
    mv "${DEBIAN_CHANGELOG}.tmp" "$DEBIAN_CHANGELOG"

    echo "  Added entry for ${NEW_VERSION}"
fi

# =============================================================================
# RPM spec changelog (dkms/mt76-mt7925-dkms.spec)
# =============================================================================

RPM_SPEC="dkms/mt76-mt7925-dkms.spec"

if [[ -f "$RPM_SPEC" ]]; then
    echo "Updating $RPM_SPEC %changelog..."

    # Insert new changelog entry after %changelog line
    NEW_RPM_ENTRY="* ${RPM_DATE} Zac Bowling <zac@zacbowling.com> - ${NEW_VERSION}-1\n- ${MESSAGE}\n"

    sed -i "s/^%changelog$/%changelog\n${NEW_RPM_ENTRY}/" "$RPM_SPEC"

    echo "  Added entry for ${NEW_VERSION}"
fi

# =============================================================================
# Main CHANGELOG.md
# =============================================================================

CHANGELOG="CHANGELOG.md"

if [[ -f "$CHANGELOG" ]]; then
    echo "Updating $CHANGELOG..."

    TODAY=$(date "+%Y-%m-%d")

    # Insert new version section after ## [Unreleased]
    NEW_SECTION="## [Unreleased]\n\n## [${NEW_VERSION}] - ${TODAY}\n\n### Changed\n\n- ${MESSAGE}"

    sed -i "s/^## \[Unreleased\]$/${NEW_SECTION}/" "$CHANGELOG"

    # Update the comparison links at the bottom
    # Note: tbump already updated the [Unreleased] link, so we just add the new version link
    # PREV_VERSION is passed as parameter since tbump already modified the file

    # Add new version link after Unreleased link
    NEW_LINK="[${NEW_VERSION}]: https://github.com/zbowling/mt7925/compare/v${PREV_VERSION}...v${NEW_VERSION}"
    sed -i "/^\[Unreleased\]:.*HEAD$/a ${NEW_LINK}" "$CHANGELOG"

    echo "  Added section for ${NEW_VERSION}"
fi

echo ""
echo "Changelogs updated for version ${NEW_VERSION}"
echo ""
echo "IMPORTANT: Review and edit the changelog entries before committing!"
echo "  - $DEBIAN_CHANGELOG"
echo "  - $RPM_SPEC"
echo "  - $CHANGELOG"
