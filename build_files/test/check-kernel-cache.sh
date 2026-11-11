#!/usr/bin/env bash

set -euo pipefail
cache_dir="$1"
kernel_name="$2"
kernel_release="$3"

jq -e --arg name "$kernel_name" --arg release "$kernel_release" \
    '.kernel_name == $name and .kernel_release == $release' \
    "$cache_dir/cache.json" > /dev/null

shopt -s nullglob
rpms=("$cache_dir"/*.rpm)
(( ${#rpms[@]} > 0 )) || { echo 'Kernel cache has no RPMs' >&2; exit 1; }
[[ -s "$cache_dir/$kernel_name-$kernel_release.rpm" ]]
[[ -s "$cache_dir/$kernel_name-core-$kernel_release.rpm" ]]
for package in "${rpms[@]}"; do
    release=$(rpm -qp --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$package")
    [[ "$release" == "$kernel_release" ]] || {
        echo "Unexpected kernel RPM in cache: $package ($release)" >&2
        exit 1
    }
done
