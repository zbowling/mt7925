#!/bin/bash
# MT7925 Patch Validation Script
# Validates that all patches in kernels/ apply cleanly to their target kernel versions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMP_DIR="${TEMP_DIR:-/tmp/mt7925-patch-test}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Kernel versions and their patch directories
declare -A KERNEL_VERSIONS=(
    ["6.17"]="v6.17.13"
    ["6.18"]="v6.18.5"
    ["6.19-rc"]="v6.19-rc5"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Clone kernel with sparse checkout (mt76 only)
clone_kernel() {
    local tag=$1
    local dest="$TEMP_DIR/linux-$tag"

    # Redirect log_info to stderr so it doesn't corrupt the return value
    log_info "Cloning Linux kernel $tag (sparse checkout for mt76)..." >&2

    git clone --depth 1 --filter=blob:none --sparse \
        https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
        -b "$tag" "$dest" 2>/dev/null

    cd "$dest"
    git sparse-checkout set drivers/net/wireless/mediatek/mt76 2>/dev/null
    cd - > /dev/null

    echo "$dest"
}

# Test patches for a specific kernel version
test_patches() {
    local kernel_dir=$1
    local patch_dir=$2
    local version=$3

    local patch_count=0
    local failed=0

    log_info "Testing patches in $patch_dir against kernel $version..."

    cd "$kernel_dir"

    for patch in "$patch_dir"/*.patch; do
        [[ -f "$patch" ]] || continue
        patch_count=$((patch_count + 1))

        if git apply --check "$patch" 2>/dev/null; then
            git apply "$patch"
            echo -e "  ${GREEN}OK${NC}: $(basename "$patch")"
        else
            failed=$((failed + 1))
            echo -e "  ${RED}FAIL${NC}: $(basename "$patch")"
            git apply --check "$patch" 2>&1 | head -3 | sed 's/^/       /'
        fi
    done

    cd - > /dev/null

    if [[ $failed -gt 0 ]]; then
        log_error "$failed/$patch_count patches failed for $version"
        return 1
    else
        log_info "All $patch_count patches applied cleanly for $version"
        return 0
    fi
}

main() {
    local only_version="${1:-}"
    local exit_code=0

    echo "========================================"
    echo "MT7925 Patch Validation"
    echo "========================================"
    echo

    # Ensure we're in the project root
    cd "$PROJECT_ROOT"

    # Create temp directory
    mkdir -p "$TEMP_DIR"
    trap cleanup EXIT

    for kernel_dir in "${!KERNEL_VERSIONS[@]}"; do
        local tag="${KERNEL_VERSIONS[$kernel_dir]}"
        local patch_dir="$PROJECT_ROOT/kernels/$kernel_dir"

        # Skip if user specified a specific version
        if [[ -n "$only_version" && "$kernel_dir" != "$only_version" ]]; then
            continue
        fi

        # Skip if patch directory doesn't exist
        if [[ ! -d "$patch_dir" ]]; then
            log_warn "Patch directory $patch_dir does not exist, skipping"
            continue
        fi

        # Skip if no patches
        if ! ls "$patch_dir"/*.patch &>/dev/null; then
            log_warn "No patches found in $patch_dir, skipping"
            continue
        fi

        echo "----------------------------------------"
        echo "Testing: $kernel_dir ($tag)"
        echo "----------------------------------------"

        # Clone kernel
        local kernel_path
        kernel_path=$(clone_kernel "$tag")

        # Test patches
        if ! test_patches "$kernel_path" "$patch_dir" "$tag"; then
            exit_code=1
        fi

        echo
    done

    echo "========================================"
    if [[ $exit_code -eq 0 ]]; then
        log_info "All patch validations passed!"
    else
        log_error "Some patch validations failed!"
    fi
    echo "========================================"

    return $exit_code
}

# Allow running specific kernel version: ./validate-patches.sh 6.18
main "$@"
