#!/bin/bash
# Wrapper to run Kimera-RPGO binaries inside Docker with automatic path mounting.
#
# Usage: ./docker/run.bash <binary_name> [args...]
#
# The script scans arguments to detect file/directory paths, resolves them to
# absolute paths, and bind-mounts each unique parent directory into the
# container at the same path. This means file paths "just work" without
# manual -v flags.

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <binary_name> [args...]" >&2
    echo "  binary_name: RpgoReadG2o | RpgoReadG2oIncremental | GenerateTrajectories" >&2
    exit 1
fi

BINARY="$1"
shift

# Known literal flags that should never be treated as paths
declare -A KNOWN_FLAGS=( [2d]=1 [3d]=1 [v]=1 )

# Collect directories to mount and build the final argument list
declare -a MOUNT_DIRS=()
declare -a ARGS=()

for arg in "$@"; do
    # Skip known flags
    if [[ -n "${KNOWN_FLAGS[$arg]+x}" ]]; then
        ARGS+=("$arg")
        continue
    fi

    # Skip numeric arguments (e.g. -1.0, 0.9, 42)
    if [[ "$arg" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        ARGS+=("$arg")
        continue
    fi

    # Check if it's an existing file or directory
    if [ -e "$arg" ]; then
        abs="$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"
        if [ -d "$abs" ]; then
            MOUNT_DIRS+=("$abs")
        else
            MOUNT_DIRS+=("$(dirname "$abs")")
        fi
        ARGS+=("$abs")
        continue
    fi

    # Check if parent directory exists (future output path)
    parent="$(dirname "$arg")"
    if [ -d "$parent" ]; then
        abs_parent="$(cd "$parent" && pwd)"
        MOUNT_DIRS+=("$abs_parent")
        ARGS+=("$abs_parent/$(basename "$arg")")
        continue
    fi

    # Not a path — pass through unchanged
    ARGS+=("$arg")
done

# Always mount the current working directory (handles relative paths and default "." output)
MOUNT_DIRS+=("$(pwd)")

# Deduplicate and remove child directories when a parent is already mounted
readarray -t UNIQUE_DIRS < <(printf '%s\n' "${MOUNT_DIRS[@]}" | sort -u)

declare -a FINAL_DIRS=()
for dir in "${UNIQUE_DIRS[@]}"; do
    is_child=false
    for other in "${UNIQUE_DIRS[@]}"; do
        if [ "$dir" != "$other" ] && [[ "$dir" == "$other"/* ]]; then
            is_child=true
            break
        fi
    done
    if ! $is_child; then
        FINAL_DIRS+=("$dir")
    fi
done

# Build docker volume mount flags
declare -a VOLUME_FLAGS=()
for dir in "${FINAL_DIRS[@]}"; do
    VOLUME_FLAGS+=("-v" "$dir:$dir")
done

exec docker run --rm \
    --user "$(id -u):$(id -g)" \
    --workdir "$(pwd)" \
    "${VOLUME_FLAGS[@]}" \
    kimera-rpgo \
    "$BINARY" "${ARGS[@]}"
