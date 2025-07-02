#!/usr/bin/bash

set -euo pipefail

main() {
    if [[ ! -d .github || ! -d .git ]]; then 
        echo "This script must be run at the root of the repo" >&2
        exit 1
    fi

    rm -f "./.github/workflows/build"*".yml"

    declare -A images=()
    declare -A workflows=()
    # TODO: How to make this not static?
    for i in 10 41 42; do
        for j in bazzite centos centos-hsk coreos-stable coreos-testing longterm-6.12 main; do
            for k in common extra nvidia nvidia-open zfs; do
                #shellcheck disable=SC1087
                if [[ "$(yq ".images.$i[\"$j\"].$k" images.yaml)" != "null" ]]; then
                    images+=(["$i-$j-$k"]="$i,$j,$k")
                    workflows+=(["$i-$j"]="$i,$j")
                fi
            done
        done
    done
    {
    cat <<'EOF'
# This is a generated workflow. Do not edit by hand.
# Generate the workflow by running ./generate-workflows.sh at git root
# Modify the inputs in ./workflow-templates
EOF
    cat ./workflow-templates/workflow.yaml.in
    for i in "${!workflows[@]}"; do
        version="$(echo "${workflows[$i]}" | cut -d "," -f 1)"
        kernel_flavor="$(echo "${workflows[$i]}" | cut -d "," -f 2)"
        kernel_flavor_clean="$(echo $kernel_flavor | tr '.' '-')"
        sed -e "s/%%KERNEL_FLAVOR%%/$kernel_flavor/;s/%%KERNEL_FLAVOR_CLEAN%%/$kernel_flavor_clean/;s/%%VERSION%%/$version/" ./workflow-templates/cache_kernel.yaml.in
        for j in common extra nvidia nvidia-open zfs; do
            value="${images[$i-$j]:-}"
            if [ -z "$value" ]; then
                continue
            fi
            akmods_target="$(echo "$value" | cut -d "," -f 3)"
            sed "s/%%VERSION%%/$version/;s/%%KERNEL_FLAVOR%%/$kernel_flavor/;s/%%AKMODS_TARGET%%/$akmods_target/;s/%%KERNEL_FLAVOR_CLEAN%%/$kernel_flavor_clean/" "./workflow-templates/job.yaml.in"
        done
    done
    } > "./.github/workflows/build-akmods.yml"
}

main
