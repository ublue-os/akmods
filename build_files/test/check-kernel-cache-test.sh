#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/cache"
# Stub only rpm's metadata query; the checker still examines actual filenames
# and the cache metadata. Fixture file contents stand in for queried releases.
cat > "$tmp/bin/rpm" <<'EOF'
#!/usr/bin/env bash
cat "${@: -1}"
EOF
chmod +x "$tmp/bin/rpm"
export PATH="$tmp/bin:$PATH"
release=7.2.11-200.fc44.x86_64
jq -n --arg release "$release" '{kernel_name:"kernel",kernel_release:$release}' > "$tmp/cache/cache.json"
for name in kernel kernel-core; do
    printf '%s' "$release" > "$tmp/cache/$name-$release.rpm"
done
bash build_files/test/check-kernel-cache.sh "$tmp/cache" kernel "$release"
for wrong in 7.2.11-201.fc44.x86_64 7.2.11-200.fc45.x86_64 7.2.11-200.fc44.aarch64; do
    if bash build_files/test/check-kernel-cache.sh "$tmp/cache" kernel "$wrong"; then
        echo "Wrong release accepted: $wrong" >&2
        exit 1
    fi
done
printf '%s' 7.2.11-200.fc45.x86_64 > "$tmp/cache/kernel-mixed.rpm"
if bash build_files/test/check-kernel-cache.sh "$tmp/cache" kernel "$release"; then
    echo 'Mixed RPM cache accepted' >&2
    exit 1
fi
echo 'Kernel cache validation passed'
