set unstable := true
set lists
set dotenv-load := true

podman := which('podman') || require('podman-remote')
just := just_executable()
yq := 'yq --yaml-fix-merge-anchor-to-spec'
BUILDDIR := shell('mkdir -p $1 && echo $1', env('AKMODS_BUILDDIR', absolute_path('build')))
version_cache := shell('mkdir -p $1 && echo $1', BUILDDIR / kernel_flavor + '-' + version)
KCWD := shell('mkdir -p $1 && echo $1', version_cache / 'KCWD')
KCPATH := shell('mkdir -p $1 && echo $1', env('KCPATH', KCWD / 'rpms'))
version_json := KCPATH / 'cache.json'
builder := 'quay.io/fedora/fedora:' + version
ogc_tag := if kernel_flavor == 'ogc-lts' { 'lts' } else { 'latest' }
ogc_image := "ghcr.io/opengamingcollective/kernel-packages-fedora:" + ogc_tag + "-fc" + version


# Inputs

kernel_flavor := env('AKMODS_KERNEL', shell(yq + ' ".defaults.kernel_flavor" images.yaml'))
version := env('AKMODS_VERSION', shell(yq + ' ".defaults.version" images.yaml'))
akmods_target := env('AKMODS_TARGET', if kernel_flavor =~ 'longterm' { 'zfs' } else { shell(yq + ' ".defaults.akmods_target" images.yaml') })
zfs_version := env(
    'ZFS_VERSION',
    shell(yq + ' ".zfs[\"$1\"].version // .zfs.default.version" images.yaml', kernel_flavor)
)
zfs_linux_experimental_overridden := shell(
    yq + ' ".zfs[\"$1\"] | has(\"linux_experimental\")" images.yaml',
    kernel_flavor
)
zfs_linux_experimental := if zfs_linux_experimental_overridden == 'true' {
    shell(yq + ' ".zfs[\"$1\"].linux_experimental" images.yaml', kernel_flavor)
} else {
    shell(yq + ' ".zfs.default.linux_experimental" images.yaml')
}
zfs_configure_args := env(
    'ZFS_CONFIGURE_ARGS',
    if zfs_linux_experimental == 'true' { '--enable-linux-experimental' } else { '' }
)

# Kernel pin for coreos-stable (maximum version cap)
# Empty '' follows upstream fedora-coreos:stable.
# Set to major.minor.patch (e.g. '6.17.12') to hold all coreos-stable targets.
# When to use this: README.md#pinning-the-coreos-stable-kernel
coreos_stable_kernel_pin := ''

# Check if valid

check_valid := if shell(yq + ' ".images.$1[\"$2\"].$3" images.yaml', version, kernel_flavor, akmods_target) != 'null' { 'true' } else { error('Invalid Image Combination') }
_description := shell(yq + ' ".images.$1[\"$2\"].$3.description" images.yaml', version, kernel_flavor, akmods_target)
_org := shell(yq + ' ".images.$1[\"$2\"].$3.org" images.yaml', version, kernel_flavor, akmods_target)
_repo := shell(yq + ' ".images.$1[\"$2\"].$3.repo" images.yaml', version, kernel_flavor, akmods_target)
registry := env('AKMODS_REGISTRY', shell(yq + ' ".images.$1[\"$2\"].$3.registry" images.yaml', version, kernel_flavor, akmods_target))
transport := env('AKMODS_TRANSPORT', shell(yq + ' ".images.$1[\"$2\"].$3.transport" images.yaml', version, kernel_flavor, akmods_target))
akmods_name := 'akmods' + if akmods_target != 'common' { '-' +akmods_target } else { '' }

# Input fingerprint snapshot, one per target and arch
fingerprint_json := version_cache / 'fingerprint-' + akmods_target + '-' + arch() + '.json'

# Functions
[private]
logsum := '''
log_sum() { echo "$1" >> ${GITHUB_STEP_SUMMARY:-/dev/stdout}; }
log_sum "# Push to GHCR result"
log_sum "\`\`\`"
'''

[private]
default:
    {{ just }} --list

# Remove Build Directory
[group('Utility')]
clean:
    rm -rf {{ BUILDDIR }}

# Get the Kernel Version
[private]
get-kernel-version:
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    if [[ {{ kernel_flavor }} =~ longterm ]]; then
        {{ podman }} pull --retry 3 "{{ builder }}" >&2
        builder=$({{ podman }} run --entrypoint /bin/bash -dt "{{ builder }}")
        dnf="{{ podman }} exec -t $builder dnf"
        $dnf install -y --setopt=install_weak_deps=False dnf-plugins-core >&2
        trap '{{ podman }} rm -f -t 0 $builder &>/dev/null' EXIT SIGTERM
    fi

    coreos_kernel() {
        # Read the kernel from CoreOS build metadata. Pulling the image just to run
        # rpm -q kernel fails when the quay.io CDN drops the blob connection.
        local coreos_version=${1}
        local arch="{{ arch() }}" oci_arch
        case "$arch" in
            x86_64)  oci_arch=amd64 ;;
            aarch64) oci_arch=arm64 ;;
            *) echo "unsupported arch ${arch}" >&2; exit 1 ;;
        esac
        local build
        build=$(skopeo --override-arch "$oci_arch" inspect --retry-times 3 --no-tags \
            "docker://quay.io/fedora/fedora-coreos:${coreos_version}" \
            | jq -r '.Labels["org.opencontainers.image.version"] // empty')
        [[ -n "$build" ]] || { echo "no CoreOS build id for ${coreos_version}/${arch}" >&2; exit 1; }

        local meta
        meta=$(curl --fail --silent --show-error --location --retry 5 --retry-all-errors \
            "https://builds.coreos.fedoraproject.org/prod/streams/${coreos_version}/builds/${build}/${arch}/commitmeta.json")

        coreos_linux=$(jq -r '.["ostree.linux"] // empty' <<< "$meta")
        local kernels=()
        mapfile -t kernels < <(jq -r --arg arch "$arch" \
            '.["rpmostree.rpmdb.pkglist"][] | select(.[0] == "kernel" and .[4] == $arch) | "\(.[2])-\(.[3]).\(.[4])"' \
            <<< "$meta")
        if [[ -z "$coreos_linux" || "$coreos_linux" != *".${arch}" ]] \
            || (( ${#kernels[@]} != 1 )) || [[ "${kernels[0]}" != "$coreos_linux" ]]; then
            echo "CoreOS ${build}/${arch}: ostree.linux='${coreos_linux}', kernel entries: ${kernels[*]:-none}" >&2
            exit 1
        fi

        # This gives us a consistent place to handle pinning for coreos stable dependent usages
        # including: ucore stable, aurora stable and bluefin stable
        # This pin acts as a ceiling - kernels newer than this version will be held back to the pinned version
        # Kernels at or below this version will pass through unchanged
        # Edit coreos_stable_kernel_pin at the top of this Justfile to enable/disable
        if [[ "{{ kernel_flavor }}" =~ coreos-stable ]] && [[ -n "{{ coreos_stable_kernel_pin }}" ]]; then
            local pin_version="{{ coreos_stable_kernel_pin }}"
            # Extract major.minor.patch from detected kernel (e.g., "6.17.11" from "6.17.11-300.fc43.x86_64")
            local detected_version=$(echo "$coreos_linux" | grep -oP '^\d+\.\d+\.\d+')

            # Compare versions: only apply pin if detected kernel is newer than pinned
            if [[ "$(printf '%s\n' "$pin_version" "$detected_version" | sort -V | tail -n1)" == "$detected_version" ]] && \
               [[ "$detected_version" != "$pin_version" ]]; then
                echo "Detected coreos-stable kernel $coreos_linux (${detected_version}) is newer than pin ${pin_version}, applying pin" >&2
                # Reconstruct full kernel version with pinned major.minor.patch
                local suffix=$(echo "$coreos_linux" | grep -oP '^\d+\.\d+\.\d+\K.*')
                coreos_linux="${pin_version}${suffix}"
            else
                echo "Detected coreos-stable kernel $coreos_linux is at or below pin $pin_version, no pin applied" >&2
            fi
        fi

        # This always provides kernel version from the upstream image as the resulting $coreos_linux variable
        # It should be verified downloadable by verify_kernel_fedora()
    }

    # Prints the HTTP status for a successful request; returns 2 on transport failure.
    koji_status() {
        local url="$1" code rc=0
        code=$(curl --silent --show-error --head --output /dev/null --write-out '%{http_code}' \
            --retry 5 --retry-delay 5 --retry-connrefused "$url") || rc=$?
        if (( rc != 0 )); then
            echo "koji: request failed (curl exit ${rc}) for ${url}" >&2
            return 2
        fi
        printf '%s\n' "$code"
    }

    verify_kernel_fedora() {
        # using the kernel version from upstream image
        # verify the expected version exist in koji packages for Fedora of the required version

        # Get Variables
        coreos_version=${1}
        major_minor_patch="$(echo $coreos_linux | grep -oP '^\d+\.\d+\.\d+')"
        kernel_rel_part=$(echo $coreos_linux | grep -oP '^\d+\.\d+\.\d+\-\K([123][0][0-9])')
        arch="$(echo $coreos_linux | grep -oP 'fc\d+\.\K.*$')"
        kernel_rel="$kernel_rel_part.fc{{ version }}"
        kernel_version="$major_minor_patch-$kernel_rel.$arch"
        URL="https://kojipkgs.fedoraproject.org/packages/kernel/"$major_minor_patch"/"$kernel_rel"/"$arch"/kernel-"$kernel_version".rpm"

        echo "Querying koji for ${coreos_version} kernel: $kernel_version" >&2
        echo "$URL" >&2
        linux=""
        status=$(koji_status "$URL") || exit 1
        case "$status" in
            200) linux="$kernel_version" ;;
            404)
                echo "Koji failed to find $coreos_version kernel: $kernel_version" >&2
                case "$kernel_rel_part" in
                    30[0-9]|20[0-9])
                        kernel_rel_part_new=$((10#$kernel_rel_part - 100))
                        kernel_rel_part=$(printf "%03d" "$kernel_rel_part_new")   # zero pad to 3 digits
                        ;;
                    10[0-9]) ;;
                    *) echo "unexpected kernel_rel_part ${kernel_rel_part}" >&2 ;;
                esac
                kernel_rel="$kernel_rel_part.fc{{ version }}"
                kernel_version="$major_minor_patch-$kernel_rel.$arch"
                URL="https://kojipkgs.fedoraproject.org/packages/kernel/"$major_minor_patch"/"$kernel_rel"/"$arch"/kernel-"$kernel_version".rpm"
                echo "Re-querying koji for ${coreos_version} kernel: $kernel_version" >&2
                echo "$URL" >&2
                status=$(koji_status "$URL") || exit 1
                [[ "$status" == 200 ]] && linux="$kernel_version" \
                    || { echo "koji: ${status} for ${URL} after fallback" >&2; exit 1; }
                ;;
            *) echo "koji: unexpected HTTP ${status} for ${URL}" >&2; exit 1 ;;
        esac
    }

    kernel_name=kernel
    case {{ kernel_flavor }} in
        "coreos-stable")
            coreos_kernel stable
            verify_kernel_fedora stable
            # '$linux' set by verify_kernel_fedora
            ;;
        "coreos-testing")
            coreos_kernel testing
            verify_kernel_fedora testing
            # '$linux' set by verify_kernel_fedora
            ;;
        "longterm"*)
            $dnf copr enable -y kwizart/kernel-{{ kernel_flavor }} >&2
            $dnf makecache >&2
            linux=$($dnf repoquery --whatprovides kernel-longterm | sort -V | tail -n1 | sed 's/.*://')
            kernel_name=kernel-longterm
            ;;
        "ogc"|"ogc-lts")
            ogc_manifest=$(skopeo inspect --raw "docker://{{ ogc_image }}")
            linux=$(echo "$ogc_manifest" | jq -r '
                .layers[].annotations["org.opencontainers.image.title"]
                | select(startswith("kernel-core-"))
                | ltrimstr("kernel-core-") | rtrimstr(".rpm")
            ')
            ;;
        "main")
            base_image_name="base-atomic"
            linux=$(skopeo inspect docker://quay.io/fedora-ostree-desktops/$base_image_name:{{ version }} --format '{{{{ index .Labels "ostree.linux" }}')
            ;;
        *)
            echo "unexpected kernel_flavor '{{ kernel_flavor }}' for query" >&2
            exit 1
            ;;
    esac
    if [ -z "$linux" ] || [ "null" = "$linux" ]; then
        echo "inspected image linux version must not be empty or null" >&2
        exit 1
    fi
    major=$(echo "$linux" | cut -d '.' -f 1)
    minor=$(echo "$linux" | cut -d '.' -f 2)
    patch=$(echo "$linux" | cut -d '.' -f 3)
    kernel_major_minor_patch="${major}.${minor}.${patch}"
    if [[ "{{ kernel_flavor }}" =~ ^ogc ]]; then
        kernel_major_minor_patch=$(echo "$linux" | sed 's/\.fc.*$//')
    fi
    linux="$(echo $linux | tr -d '[:cntrl:]')"

    # Debug Output
    echo "kernel_flavor: {{ kernel_flavor }}" >&2
    echo "kernel_major_minor_patch: ${kernel_major_minor_patch}" >&2
    echo "kernel_release: ${linux}" >&2
    echo "kernel_name: ${kernel_name}" >&2

    # Return
    output=$(jq -nM \
        --arg build_tag "${build_tag:-}" \
        --arg kernel_flavor "{{ kernel_flavor}}" \
        --arg kernel_major_minor_patch "$kernel_major_minor_patch" \
        --arg kernel_release "$linux" \
        --arg kernel_name "$kernel_name" \
        --arg KCWD "{{ KCWD }}" \
        --arg KCPATH "{{ KCPATH }}" \
        '{
            "kernel_build_tag": $build_tag,
            "kernel_flavor": $kernel_flavor,
            "kernel_major_minor_patch": $kernel_major_minor_patch,
            "kernel_release": $kernel_release,
            "kernel_name": $kernel_name,
            "KCWD": $KCWD,
            "KCPATH": $KCPATH
        }')

    echo $output

# Cache Version Json
[group('Build')]
@cache-kernel-version: && populate-github-output
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    cache="{{ version_json }}"
    valid() {
        jq -e --arg flavor "{{ kernel_flavor }}" --arg kcpath "{{ KCPATH }}" '
            def str: type == "string" and length > 0 and . != "null";
            (.kernel_flavor == $flavor)
            and (.kernel_release | str)
            and (.kernel_name | str)
            and (.kernel_major_minor_patch | str)
            and (.KCPATH == $kcpath)
            and (.KCWD | str)
        ' "$1" > /dev/null 2>&1
    }
    if [[ -e "$cache" ]]; then
        valid "$cache" && exit 0
        echo "Discarding invalid ${cache}" >&2
        rm -f "$cache"
    fi
    tmp="$(mktemp "${cache}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    {{ just }} get-kernel-version > "$tmp"
    valid "$tmp" || { echo "get-kernel-version produced invalid output" >&2; exit 1; }
    mv -f "$tmp" "$cache"
    trap - EXIT

# Populate Github Output
[private]
@populate-github-output:
    {{ if env('GITHUB_OUTPUT', '') != '' { 'jq -r "to_entries[] | \"\(.key)=\(.value)\"" < ' + version_json + ' | xargs -I "{}" echo "{}" >> ' + env('GITHUB_OUTPUT') } else { '' } }}

# Fingerprint inputs that need no network, as canonical JSON.
# The fingerprint logic must stay in a file that is itself an input (this
# Justfile), so changing how the fingerprint is computed changes the hash.
[private]
fingerprint-inputs:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ justfile_dir() }}"

    # A mirror URL lands in the image label, so refuse anything that can carry credentials
    mirror="${RPMFUSION_MIRROR:-}"
    if [[ -n "$mirror" && ! "$mirror" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/%-]*)?$ ]]; then
        echo "fingerprint: RPMFUSION_MIRROR must be a plain http(s) URL without userinfo, query, or fragment" >&2
        exit 1
    fi

    kernel_release="$(jq -er --arg flavor "{{ kernel_flavor }}" '
        select(.kernel_flavor == $flavor)
        | .kernel_release
        | select(type == "string" and length > 0 and . != "null")
    ' "{{ version_json }}")" || { echo "fingerprint: no valid {{ version_json }}" >&2; exit 1; }

    trees=(build_files files)
    blobs=(Containerfile.in Justfile fetch-kernel.sh)
    # Committed public and test keys only. certs/private_key*.priv are placeholders
    # that CI overwrites with secrets, so they must never be hashed or labeled.
    certs=(
        certs/public_key.der certs/public_key_2.der
        certs/public_key.der.test certs/public_key_2.der.test
        certs/private_key.priv.test certs/private_key_2.priv.test
    )
    workflows=(.github/workflows/reusable-build.yml .github/workflows/reusable-cache-kernel.yml)

    objects() {
        local path
        for path in "$@"; do
            jq -nc --arg k "$path" --arg v "$(git rev-parse --verify --quiet "HEAD:${path}")" \
                'if $v == "" then error("missing \($k)") else {($k): $v} end'
        done | jq -sc 'add // {}'
    }

    dirty=false
    status="$(git status --porcelain --untracked-files=all -- \
        "${trees[@]}" "${blobs[@]}" images.yaml "${certs[@]}" "${workflows[@]}")"
    [[ -z "$status" ]] || dirty=true

    git_trees="$(objects "${trees[@]}")"
    git_blobs="$(objects "${blobs[@]}")"
    git_certs="$(objects "${certs[@]}")"
    git_workflows="$(objects "${workflows[@]}")"

    target_config="$({{ yq }} -o json -I0 'explode(.).images.{{ version }}["{{ kernel_flavor }}"]["{{ akmods_target }}"]' images.yaml)"
    jq -e 'type == "object"' <<< "$target_config" > /dev/null

    jq -nSc \
        --arg kernel_flavor "{{ kernel_flavor }}" \
        --arg version "{{ version }}" \
        --arg akmods_target "{{ akmods_target }}" \
        --arg arch "{{ arch() }}" \
        --arg kernel_release "$kernel_release" \
        --argjson trees "$git_trees" \
        --argjson blobs "$git_blobs" \
        --argjson certs "$git_certs" \
        --argjson workflows "$git_workflows" \
        --argjson target_config "$target_config" \
        --arg mirror "$mirror" \
        --argjson dirty "$dirty" \
        --arg zfs_version "{{ zfs_version }}" \
        --arg zfs_configure_args "{{ zfs_configure_args }}" \
        '{
            kernel_flavor: $kernel_flavor,
            version: $version,
            akmods_target: $akmods_target,
            arch: $arch,
            kernel_release: $kernel_release,
            git: ($trees + {blobs: $blobs, certs: $certs, workflows: $workflows}),
            target_config: $target_config,
            overrides: {RPMFUSION_MIRROR: $mirror},
            dirty: $dirty
        }
        + if $akmods_target == "zfs" then
            {zfs: {version: $zfs_version, configure_args: $zfs_configure_args}}
          else {} end'

# Latest akmod-nvidia EVR from the negativo17 repo the build uses
[private]
nvidia-akmod-evr:
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    cd "{{ justfile_dir() }}"
    kmod_repo="{{ if akmods_target =~ 'lts' { 'nvidia-lts' } else { 'nvidia' } }}"

    # Read the repo URL from the script that writes the build's repo file, so the two can't drift
    mapfile -t urls < <(awk -v dest="/negativo17-fedora-${kmod_repo}.repo" '
        /curl -L/ { url = ""; for (i = 1; i <= NF; i++) if ($i ~ /^https:\/\//) url = $i }
        / -o / && index($0, dest) && url != "" { print url; url = "" }
    ' build_files/nvidia/build-ublue-os-nvidia-addons.sh)
    if (( ${#urls[@]} != 1 )) || [[ ! "${urls[0]}" =~ ^https://negativo17\.org/repos/fedora-nvidia[a-z0-9-]*\.repo$ ]]; then
        echo "nvidia-akmod-evr: cannot find the negativo17 repo URL for ${kmod_repo}" >&2
        exit 1
    fi

    {{ podman }} pull --retry 3 "{{ builder }}" >&2
    output="$({{ podman }} run --rm \
        --security-opt label=disable \
        --env REPO_URL="${urls[0]}" \
        --volume "{{ justfile_dir() / 'build_files/prep/dnf-retry.sh' }}":/tmp/dnf-retry.sh:ro \
        --entrypoint /bin/bash \
        "{{ builder }}" -c '
            set -euo pipefail
            source /tmp/dnf-retry.sh
            curl --fail --silent --show-error --location --retry 5 --retry-all-errors \
                "$REPO_URL" -o /etc/yum.repos.d/negativo17-query.repo >&2
            repo="$(sed -n "s/^\[\(.*\)\]$/\1/p" /etc/yum.repos.d/negativo17-query.repo | head -n1)"
            dnf_retry -q repoquery --disablerepo="*" --enablerepo="$repo" \
                --setopt="${repo}.skip_if_unavailable=0" \
                --latest-limit=1 --arch="$(uname -m)" \
                --qf "%{epoch}:%{version}-%{release}\n" akmod-nvidia
        ')"

    # repoquery can succeed with no matches, so require exactly one well-formed EVR
    mapfile -t lines <<< "$output"
    if (( ${#lines[@]} != 1 )) || [[ ! "${lines[0]}" =~ ^[0-9]+:[0-9][0-9.]*-[^[:space:]]+$ ]]; then
        echo "nvidia-akmod-evr: expected one EVR, got: ${output@Q}" >&2
        exit 1
    fi
    echo "${lines[0]}"

# Write the input fingerprint snapshot for this target and arch
[group('Build')]
fingerprint: (cache-kernel-version)
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    out="{{ fingerprint_json }}"
    # A failed run must not leave an older snapshot behind
    rm -f "$out"

    inputs="$({{ just }} fingerprint-inputs)"
    if [[ "{{ akmods_target }}" =~ nvidia ]]; then
        evr="$({{ just }} nvidia-akmod-evr)"
        inputs="$(jq -Sc --arg evr "$evr" '. + {nvidia_akmod_evr: $evr}' <<< "$inputs")"
    fi
    if [[ "$(jq -r .dirty <<< "$inputs")" == true ]]; then
        # Local edits: label the image so it can never match a published one
        inputs="$(jq -Sc --arg nonce "$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')" '. + {nonce: $nonce}' <<< "$inputs")"
    fi
    hash="$(printf '%s' "$inputs" | sha256sum | cut -d ' ' -f 1)"

    tmp="$(mktemp "${out}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    jq -nSc --arg hash "$hash" --argjson inputs "$inputs" '{hash: $hash, inputs: $inputs}' > "$tmp"
    mv -f "$tmp" "$out"
    trap - EXIT
    cat "$out"

# Remove the input fingerprint snapshot for this target and arch
[group('Build')]
fingerprint-clear:
    rm -f "{{ fingerprint_json }}"

# Print the snapshot if it still describes the current checkout, else fail
[private]
fingerprint-snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    snapshot="{{ fingerprint_json }}"
    [[ -s "$snapshot" ]] || { echo "fingerprint: no snapshot at ${snapshot}" >&2; exit 1; }
    current="$({{ just }} fingerprint-inputs)"
    jq -e --argjson current "$current" --arg target "{{ akmods_target }}" '
        (.hash | type == "string" and test("^[0-9a-f]{64}$"))
        and (.inputs | type == "object")
        and ((.inputs | del(.nvidia_akmod_evr, .nonce)) == $current)
        and (if $target | test("nvidia") then
                .inputs.nvidia_akmod_evr | type == "string" and test("^[0-9]+:[0-9][0-9.]*-[^\\s]+$")
             else (.inputs | has("nvidia_akmod_evr") | not) end)
        and (if .inputs.dirty then
                .inputs.nonce | type == "string" and test("^[0-9a-f]{32}$")
             else (.inputs | has("nonce") | not) end)
    ' "$snapshot" > /dev/null || { echo "fingerprint: ${snapshot} does not match the current inputs" >&2; exit 1; }
    [[ "$(printf '%s' "$(jq -Sc .inputs "$snapshot")" | sha256sum | cut -d ' ' -f 1)" == "$(jq -r .hash "$snapshot")" ]] \
        || { echo "fingerprint: ${snapshot} hash does not match its inputs" >&2; exit 1; }
    jq -Sc . "$snapshot"

# Decide whether the published image is stale. Any doubt means build.
[group('Registry')]
build-needed:
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    cd "{{ justfile_dir() }}"
    summary() { echo "$1" >> "${GITHUB_STEP_SUMMARY:-/dev/stderr}"; }
    # The only place outputs are written, once, as the last action
    finish() {
        summary "Build guard ({{ arch() }}): skip=$1 reason=$2"
        printf 'skip=%s\nreason=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT:-/dev/stdout}"
        exit 0
    }

    [[ "${AKMODS_FORCE_BUILD:-false}" != true ]] || finish false forced

    snapshot="$({{ just }} fingerprint-snapshot)" || finish false fingerprint-error
    local_hash="$(jq -r .hash <<< "$snapshot")"
    local_inputs="$(jq -Sc .inputs <<< "$snapshot")"

    repo="{{ registry / _org / akmods_name }}"
    published="$(skopeo inspect --retry-times 3 "{{ transport }}${repo}:{{ kernel_flavor }}-{{ version }}-{{ arch() }}")" \
        || finish false no-published-image

    published_hash="$(jq -r '.Labels["io.github.ublue-os.akmods.fingerprint"] // ""' <<< "$published")"
    [[ -n "$published_hash" && "$published_hash" != unavailable ]] || finish false unlabeled
    [[ "$published_hash" =~ ^[0-9a-f]{64}$ ]] || finish false malformed-label

    if [[ "$published_hash" != "$local_hash" ]]; then
        flatten() { jq -r 'paths(scalars) as $p | "\($p | map(tostring) | join(".")) = \(getpath($p))"'; }
        published_inputs="$(jq -r '.Labels["io.github.ublue-os.akmods.fingerprint-inputs"] // "{}"' <<< "$published")"
        summary '```diff'
        summary "$(diff <(flatten <<< "$published_inputs" 2> /dev/null || true) <(flatten <<< "$local_inputs") || true)"
        summary '```'
        finish false inputs-changed
    fi

    # An image pushed without its signature would otherwise be skipped forever
    digest="$(jq -r '.Digest // ""' <<< "$published")"
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || finish false unsigned
    verify() {
        local attempt
        for attempt in 1 2 3; do
            cosign verify --key cosign.pub "$@" "${repo}@${digest}" > /dev/null && return 0
            sleep $((attempt * 5))
        done
        return 1
    }
    verify || finish false unsigned
    verify --new-bundle-format=false || finish false unsigned

    created="$(jq -r '.Created // ""' <<< "$published")"
    created_epoch="$(date -d "$created" +%s 2> /dev/null)" && [[ -n "$created" ]] || finish false bad-timestamp
    now="$(date +%s)"
    (( created_epoch <= now + 600 )) || finish false future-timestamp
    max_age_days="${AKMODS_MAX_AGE_DAYS:-7}"
    [[ "$max_age_days" =~ ^[1-9][0-9]*$ ]] || max_age_days=7
    (( now - created_epoch <= max_age_days * 86400 )) || finish false max-age

    finish true unchanged

# Fetch and Sign Kernel RPMs
[group('Build')]
fetch-kernel: (cache-kernel-version)
    #!/usr/bin/env bash
    {{ if path_exists(version_json) != 'true' { error('Need to run just cache-kernel-version first for dry-run') } else { '' } }}
    {{ if path_exists( KCPATH / shell("jq -r '.kernel_name + \"-\" + .kernel_release + \".rpm\"' < $1", version_json)) == 'true' { 'exit 0' } else { '' } }}
    set ${CI:+-x} -euo pipefail

    # Pull Build Image
    {{ podman }} pull --retry 3 "{{ builder }}" >&2

    # Prep Environment
    cp -a fetch-kernel.sh build_files/prep/dnf-retry.sh certs {{ KCWD }} >&2

    # Fetch Kernels
    builder=$(podman run \
        --security-opt label=disable \
        {{ if env('CI', '') != '' { '--env CI=1' } else { '' } }} \
        --env DUAL_SIGN=true \
        --env KERNEL_BUILD_TAG="{{ shell('jq -r .kernel_build_tag < $1', version_json) }}" \
        --env KERNEL_FLAVOR="{{ kernel_flavor }}" \
        --env KERNEL_NAME="{{ shell('jq -r .kernel_name < $1', version_json) }}" \
        --env KERNEL_VERSION="{{ shell('jq -r .kernel_release < $1' , version_json) }}" \
        --env OGC_IMAGE="{{ ogc_image }}" \
        --volume "{{ KCWD }}":/tmp/kernel-cache \
        --entrypoint /bin/bash \
        -dt "{{ builder }}")
    trap '{{ podman }} rm -f -t 0 $builder &>/dev/null' EXIT SIGINT
    podman exec $builder bash /tmp/kernel-cache/fetch-kernel.sh >&2
    echo "{{ datetime_utc('%Y%m%d') }}" > "{{ KCPATH / 'kernel-cache-date' }}"
    find "{{ KCPATH }}"

# Build Akmod Image
[group('Build')]
build: (cache-kernel-version) (fetch-kernel)
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    {{ if path_exists(version_json) != 'true' { error('Need to run just cache-kernel-version first for dry-run') } else { '' } }}
    {{ if path_exists( KCPATH / shell("jq -r '.kernel_name + \"-\" + .kernel_release + \".rpm\"' < $1", version_json)) != 'true' { error('No Cached RPMs') } else { '' } }}
    CPP_FLAGS=(
        {{ if env('CI', '') != '' { "--cpp-flag=-DCI_SETX" } else { '' } }}
        "--cpp-flag=-DBUILDER={{ builder }}"
        "--cpp-flag=-DKERNEL_FLAVOR_ARG=KERNEL_FLAVOR={{ kernel_flavor }}"
        "--cpp-flag=-DKERNEL_NAME_ARG=KERNEL_NAME={{ shell("jq -r '.kernel_name' < $1", version_json) }}"
        "--cpp-flag=-DRPMFUSION_MIRROR_ARG=RPMFUSION_MIRROR={{ env('RPMFUSION_MIRROR', '') }}"
        "--cpp-flag=-DVERSION_ARG=VERSION={{ version }}"
        "--cpp-flag=-D{{ replace_regex(uppercase(akmods_target), '-.*', '') }}"
        "--cpp-flag=-D{{ replace_regex(uppercase(kernel_flavor), '-.*', '') }}"
    )
    if [[ "{{ akmods_target }}" =~ nvidia ]]; then
        CPP_FLAGS+=(
            "--cpp-flag=-DKMOD_REPO_ARG=KMOD_REPO={{ if akmods_target =~ 'lts' { "nvidia-lts" } else { 'nvidia' } }}"
        )
    fi
    if [[ "{{ akmods_target }}" == "zfs" ]]; then
        CPP_FLAGS+=(
            "--cpp-flag=-DZFS_VERSION_ARG=ZFS_VERSION={{ zfs_version }}"
            "--cpp-flag=-DZFS_CONFIGURE_ARGS_ARG=ZFS_CONFIGURE_ARGS=\"{{ zfs_configure_args }}\""
        )
    fi
    # Consume the snapshot from `just fingerprint`; without a valid one, build unpinned
    if snapshot="$({{ just }} fingerprint-snapshot)"; then
        if [[ "{{ akmods_target }}" =~ nvidia ]]; then
            CPP_FLAGS+=(
                "--cpp-flag=-DNVIDIA_AKMOD_EVR_ARG=NVIDIA_AKMOD_EVR=$(jq -r .inputs.nvidia_akmod_evr <<< "$snapshot")"
            )
        fi
    else
        snapshot=""
        echo "WARNING: no valid fingerprint snapshot, building unpinned (run 'just fingerprint' first)" >&2
    fi
    LABELS=(
        "--label" "io.artifacthub.package.deprecated=false"
        "--label" "io.artifacthub.package.keywords=bootc,fedora,bluefin,cayo,aurora,ublue,universal-blue"
        "--label" "io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
        "--label" "io.artifacthub.package.maintainers=[{\"name\": \"castrojo\", \"email\": \"jorge.castro@gmail.com\"}]"
        "--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/ublue-os/akmods/refs/heads/main/README.md"
        "--label" "org.opencontainers.image.created={{ datetime_utc('%Y-%m-%dT%H:%M:%SZ') }}"
        "--label" "org.opencontainers.image.description='{{ _description }}'"
        "--label" "org.opencontainers.image.license=Apache-2.0"
        "--label" "org.opencontainers.image.source=https://raw.githubusercontent.com/ublue-os/akmods/refs/heads/main/Containerfile.in"
        "--label" "org.opencontainers.image.title={{ akmods_name }}"
        "--label" "org.opencontainers.image.url=https://github.com/{{ _org / _repo }}"
        "--label" "org.opencontainers.image.vendor='{{ _org }}'"
        "--label" "org.opencontainers.image.version={{ shell("jq -r '.kernel_release' < $1", version_json) + '-' + trim(read(KCPATH / 'kernel-cache-date')) }}"
        "--label" "ostree.linux={{ shell("jq -r '.kernel_release' < $1", version_json) }}"
    )
    if [[ -n "$snapshot" ]]; then
        LABELS+=(
            "--label" "io.github.ublue-os.akmods.fingerprint=$(jq -r .hash <<< "$snapshot")"
            "--label" "io.github.ublue-os.akmods.fingerprint-inputs=$(jq -Sc .inputs <<< "$snapshot")"
        )
    else
        LABELS+=("--label" "io.github.ublue-os.akmods.fingerprint=unavailable")
    fi
    TAGS=(
        "--tag" "{{ akmods_name + ':' + kernel_flavor + '-' + version + '-' + arch() }}"
        "--tag" "{{ akmods_name + ':' + kernel_flavor + '-' + version + '-' + shell("jq -r '.kernel_release' < $1", version_json) }}"
    )

    {{ podman }} build -f Containerfile.in --volume {{ KCPATH }}:/tmp/kernel_cache:ro "${CPP_FLAGS[@]}" "${LABELS[@]}" "${TAGS[@]}" --target RPMS {{ justfile_dir () }}

# Test Cached Akmod RPMs
[group('Build')]
test: (cache-kernel-version) (fetch-kernel)
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    {{ if path_exists(version_json) != 'true' { error('Need to run just cache-kernel-version first for dry-run') } else { '' } }}
    {{ if path_exists( KCPATH / shell("jq -r '.kernel_name + \"-\" + .kernel_release + \".rpm\"' < $1", version_json)) != 'true' { error('No Cached RPMs') } else { '' } }}
    CPP_FLAGS=(
        {{ if env('CI', '') != '' { "--cpp-flag=-DCI_SETX" } else { '' } }}
        "--cpp-flag=-DBUILDER={{ builder }}"
        "--cpp-flag=-DKERNEL_FLAVOR_ARG=KERNEL_FLAVOR={{ kernel_flavor }}"
        "--cpp-flag=-DKERNEL_NAME_ARG=KERNEL_NAME={{ shell("jq -r '.kernel_name' < $1", version_json) }}"
        "--cpp-flag=-DRPMFUSION_MIRROR_ARG=RPMFUSION_MIRROR={{ env('RPMFUSION_MIRROR', '') }}"
        "--cpp-flag=-DVERSION_ARG=VERSION={{ version }}"
        "--cpp-flag=-D{{ replace_regex(uppercase(akmods_target), '-.*', '') }}"
        "--cpp-flag=-D{{ replace_regex(uppercase(kernel_flavor), '-.*', '') }}"
    )
    if [[ "{{ akmods_target }}" =~ nvidia ]]; then
        CPP_FLAGS+=(
            "--cpp-flag=-DKMOD_REPO_ARG=KMOD_REPO={{ if akmods_target =~ 'lts' { "nvidia-lts" } else { 'nvidia' } }}"
        )
    fi
    if [[ "{{ akmods_target }}" == "zfs" ]]; then
        CPP_FLAGS+=(
            "--cpp-flag=-DZFS_VERSION_ARG=ZFS_VERSION={{ zfs_version }}"
            "--cpp-flag=-DZFS_CONFIGURE_ARGS_ARG=ZFS_CONFIGURE_ARGS=\"{{ zfs_configure_args }}\""
        )
    fi
    # Consume the snapshot from `just fingerprint`; without a valid one, build unpinned
    if snapshot="$({{ just }} fingerprint-snapshot)"; then
        if [[ "{{ akmods_target }}" =~ nvidia ]]; then
            CPP_FLAGS+=(
                "--cpp-flag=-DNVIDIA_AKMOD_EVR_ARG=NVIDIA_AKMOD_EVR=$(jq -r .inputs.nvidia_akmod_evr <<< "$snapshot")"
            )
        fi
    else
        snapshot=""
        echo "WARNING: no valid fingerprint snapshot, building unpinned (run 'just fingerprint' first)" >&2
    fi

    {{ podman }} build -f Containerfile.in --volume {{ KCPATH }}:/tmp/kernel_cache:ro "${CPP_FLAGS[@]}" --target test --tag akmods-test:latest {{ justfile_dir () }}
    if ! podman run --rm akmods-test:latest; then
        echo "Signatures Failed" >&2
        exit 1
    fi

# Login to Registry
[group('Registry')]
@login:
    {{ podman }} login {{ registry }} -u "$REGISTRY_ACTOR"  -p "$REGISTRY_TOKEN"

# Push Images to Registry
[group('Registry')]
push:
    #!/usr/bin/env bash
    {{ if env('COSIGN_PRIVATE_KEY', '') != '' { 'printf "%s" "$COSIGN_PRIVATE_KEY" > /tmp/cosign.key' } else { '' } }}
    {{ if env('CI', '') != '' { logsum } else { '' } }}

    set ${CI:+-x} -eou pipefail
    declare -a TAGS=($({{ podman }} image list {{ shell('$1 images --filter=reference=localhost/$2:$3-$4-$5 --format "{{.ID}}"', podman, akmods_name, kernel_flavor, version, arch()) }} --noheading --format 'table {{{{ .Tag }}'))
    for tag in "${TAGS[@]}"; do
        for i in {1..5}; do
            {{ podman }} push {{ if env('COSIGN_PRIVATE_KEY', '') != '' { '--sign-by-sigstore=/etc/ublue-os-param-file.yaml' } else { '' } }} "{{ 'localhost' / akmods_name + ':' + kernel_flavor + '-' + version + '-' + arch() }}" "{{ transport + registry / _org / akmods_name }}:$tag" && break || sleep $((5 * i));
            if [[ $i -eq '5' ]]; then
                exit 1
            fi
        done
        {{ if env('CI', '') != '' { 'log_sum "' + registry / _org / akmods_name + ':$tag"' } else { '' } }}
    done
    {{ if env('CI', '') != '' { 'log_sum "\`\`\`"' } else { '' } }}

# Generate Manifest and Push to Registry
manifest_tag := kernel_flavor + "-" + version
manifest_tag_kernel :=  kernel_flavor + "-" + version + '-' + if path_exists(version_json) != 'true' { 'UNKNOWN' } else { replace_regex(shell("jq -r '.kernel_release' < $1", version_json), '.x86_64|.aarch64', '' ) }
manifest_image := registry / _org / akmods_name+ ':' + manifest_tag
manifest_image_kernel := registry / _org / akmods_name + ':' + manifest_tag_kernel

[group('Registry')]
manifest:
    #!/usr/bin/env bash
    {{ if env('COSIGN_PRIVATE_KEY', '') != '' { 'printf "%s" "$COSIGN_PRIVATE_KEY" > /tmp/cosign.key' } else { '' } }}
    {{ if env('CI', '') != '' { logsum } else { '' } }}

    set ${CI:+-x} -eou pipefail

    LABELS=(
        "io.artifacthub.package.deprecated=false"
        "io.artifacthub.package.keywords=bootc,fedora,bluefin,cayo,aurora,ublue,universal-blue"
        "io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
        "io.artifacthub.package.maintainers=[{\"name\": \"castrojo\", \"email\": \"jorge.castro@gmail.com\"}]"
        "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/ublue-os/akmods/refs/heads/main/README.md"
        "org.opencontainers.image.created={{ datetime_utc('%Y-%m-%dT%H:%M:%SZ') }}"
        "org.opencontainers.image.description={{ _description }}"
        "org.opencontainers.image.license=Apache-2.0"
        "org.opencontainers.image.source=https://raw.githubusercontent.com/ublue-os/akmods/refs/heads/main/Containerfile.in"
        "org.opencontainers.image.title={{ akmods_name }}"
        "org.opencontainers.image.url=https://github.com/{{ _org / _repo }}"
        "org.opencontainers.image.vendor={{ _org }}"
        "org.opencontainers.image.version={{ manifest_tag_kernel }}"
    )
    # Create Manifest
    MANIFEST=$({{ podman }} manifest create {{ manifest_image }})

    for label in "${LABELS[@]}"; do
        echo "Applying label "${label}" to manifest"
        podman manifest annotate --index --annotation "$label" "${MANIFEST}"
    done

    MANIFEST=$({{ podman }} manifest create {{ manifest_image_kernel }})

    for label in "${LABELS[@]}"; do
        echo "Applying label "${label}" to manifest"
        podman manifest annotate --index --annotation "$label" "${MANIFEST}"
    done

    # Add to Manifest
    TAGS="$(skopeo list-tags docker://{{ registry / _org / akmods_name }} | jq -r '.Tags | map(select(contains("{{ kernel_flavor }}-{{ version }}")))')"
    if echo "$TAGS" | jq -re '.[] | select(test("{{ manifest_tag }}-x86_64"))' >/dev/null; then
        echo "Adding {{ manifest_image }}-x86_64 to {{ manifest_image }} manifest"
        {{ podman }} manifest add {{ manifest_image }} docker://{{ manifest_image }}-x86_64
    fi
    if echo "$TAGS" | jq -re '.[] | select(test("{{ manifest_tag }}-aarch64"))' >/dev/null; then
        echo "Adding {{ manifest_image }}-aarch64 to {{ manifest_image }} manifest"
        {{ podman }} manifest add {{ manifest_image }} docker://{{ manifest_image }}-aarch64
    fi
    if echo "$TAGS" | jq -re '.[] | select(test("{{ manifest_tag_kernel }}.x86_64"))' >/dev/null; then
        echo "Adding {{ manifest_image_kernel }}.x86_64 to {{ manifest_image_kernel }} manifest"
        {{ podman }} manifest add {{ manifest_image_kernel }} docker://{{ manifest_image_kernel }}.x86_64
    fi
    if echo "$TAGS" | jq -re '.[] | select(test("{{ manifest_tag_kernel }}.aarch64"))' >/dev/null; then
        echo "Adding {{ manifest_image_kernel }}.aarch64 to {{ manifest_image_kernel }} manifest"
        {{ podman }} manifest add {{ manifest_image_kernel }} docker://{{ manifest_image_kernel }}.aarch64
    fi

    # Push Manifest
    for i in {1..5}; do
        {{ podman }} manifest push --all {{ if env('COSIGN_PRIVATE_KEY', '') != '' { '--sign-by-sigstore=/etc/ublue-os-param-file.yaml' } else { '' } }} {{ manifest_image }} && break || sleep $((5 * i));
        if [[ $i -eq '5' ]]; then
            exit 1
        fi
    done
    {{ if env('CI', '') != '' { 'log_sum "' + manifest_image + '"' } else { '' } }}

    for i in {1..5}; do
        {{ podman }} manifest push --all {{ if env('COSIGN_PRIVATE_KEY', '') != '' { '--sign-by-sigstore=/etc/ublue-os-param-file.yaml' } else { '' } }} {{ manifest_image_kernel }} && break || sleep $((5 * i));
        if [[ $i -eq '5' ]]; then
            exit 1
        fi
    done
    {{ if env('CI', '') != '' { 'log_sum "' + manifest_image_kernel + '"' } else { '' } }}

    {{ if env('CI', '') != '' { 'log_sum "\`\`\`"' } else { '' } }}

# Decide whether both published manifests already match the per-arch images. Any doubt means regenerate.
[group('Registry')]
manifest-needed:
    #!/usr/bin/env bash
    set ${CI:+-x} -euo pipefail
    cd "{{ justfile_dir() }}"
    # The only place outputs are written, once, as the last action
    finish() {
        echo "Manifest guard: skip=$1 reason=$2" >> "${GITHUB_STEP_SUMMARY:-/dev/stderr}"
        printf 'skip=%s\nreason=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT:-/dev/stdout}"
        exit 0
    }
    {{ if path_exists(version_json) != 'true' { 'finish false no-kernel-version' } else { '' } }}

    mapfile -t expected < <({{ yq }} -o json 'explode(.).images.{{ version }}["{{ kernel_flavor }}"]["{{ akmods_target }}"].architecture' images.yaml | jq -r '.[]' | sort)
    (( ${#expected[@]} > 0 )) || finish false no-architectures
    repo="{{ registry / _org / akmods_name }}"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    # check_index <index ref> <member separator>
    check_index() {
        local index="$1" sep="$2" raw="$tmp/raw.json" arch digest member
        skopeo inspect --raw --retry-times 3 "{{ transport }}${index}" > "$raw" || return 1
        jq -e '.mediaType == "application/vnd.oci.image.index.v1+json"
            or .mediaType == "application/vnd.docker.distribution.manifest.list.v2+json"' "$raw" > /dev/null || return 1
        mapfile -t found < <(jq -r '.manifests[].platform.architecture
            | if . == "amd64" then "x86_64" elif . == "arm64" then "aarch64" else . end' "$raw" | sort)
        [[ "${found[*]}" == "${expected[*]}" ]] || return 1
        for arch in "${expected[@]}"; do
            digest="$(jq -r --arg arch "$arch" '.manifests[]
                | select((.platform.architecture | if . == "amd64" then "x86_64" elif . == "arm64" then "aarch64" else . end) == $arch)
                | .digest' "$raw")"
            member="$(skopeo inspect --retry-times 3 --format '{{{{ .Digest }}' "{{ transport }}${index}${sep}${arch}")" || return 1
            [[ -n "$digest" && "$digest" == "$member" ]] || return 1
        done
        # Signed indexes only, or verify-publication would fail on every later run
        digest="$(skopeo manifest-digest "$raw")" || return 1
        cosign verify --key cosign.pub "${repo}@${digest}" > /dev/null || return 1
        cosign verify --new-bundle-format=false --key cosign.pub "${repo}@${digest}" > /dev/null || return 1
    }

    check_index "{{ manifest_image }}" - || finish false rolling-index-stale
    check_index "{{ manifest_image_kernel }}" . || finish false kernel-index-stale
    finish true unchanged

# Generate GHA Workflows
[group('Utility')]
generate-workflows:
    #!/usr/bin/env bash
    set -euo pipefail

    main() {
        if [[ ! -d .github ]]; then
            echo "This script must be run at the root of the repo" >&2
            exit 1
        fi

        # Preserve each flavor's already-assigned cron minute across regenerations so
        # unrelated images.yaml/template edits don't produce spurious cron diffs. A
        # flavor only gets a freshly randomized minute if it has no prior generated
        # file (e.g. it's brand new, or a previous run was interrupted mid-rm).
        declare -A cron_minutes=()
        for f in ./.github/workflows/build-akmods-*.yml; do
            [[ -e "$f" ]] || continue
            flavor="$(basename "$f" .yml)"
            flavor="${flavor#build-akmods-}"
            minute=$(sed -n "s/.*cron: '\([0-9]\{1,2\}\) .*/\1/p" "$f")
            [[ -n "$minute" ]] && cron_minutes[$flavor]="$minute"
        done

        rm -f "./.github/workflows/build"*".yml"

        declare -A images=()
        declare -A workflows=()
        versions=($({{ yq }} '.images | keys | .[]' images.yaml | sort | uniq))
        flavors=($({{ yq }} '.images.* | keys | .[]' images.yaml | sort | uniq))
        targets=($({{ yq }} 'explode(.).images.*.* | keys | .[]' images.yaml | sort | uniq))

        for i in "${versions[@]}"; do
            for j in "${flavors[@]}"; do
                for k in "${targets[@]}"; do
                    #shellcheck disable=SC1087
                    if [[ "$({{ yq }} ".images.$i[\"$j\"].$k" images.yaml)" != "null" ]]; then
                        arch=$({{ yq }} -o json "explode(.).images.$i[\"$j\"].$k.architecture" images.yaml | jq -c)
                        images+=(["$i-$j-$k"]="$i,$j,$k,$arch")
                        workflows+=(["$i-$j"]="$i,$j,$arch")
                    fi
                done
            done
        done
        for i in "${flavors[@]}"; do
        {
        cat <<'EOF'
    ---
    #
    # WARNING THIS IS A GENERATED WORKFLOW. DO NOT EDIT BY HAND!
    #
    # Generate the workflow by running `just generate-workflows` at git root
    # Modify the inputs in workflow-templates
    EOF
            minute="${cron_minutes[$i]:-$(printf '%02d' $(( RANDOM % 30 )))}"
            sed "s/AKMODs/${i^^} akmods/;s/%%CRON_MINUTE%%/$minute/g" ./workflow-templates/workflow.yaml.in

            echo "jobs:"
            for j in "${!workflows[@]}"; do
                if [[ ! "$j" =~ $i$ ]]; then
                    continue
                fi
                version=$(echo "${workflows[$j]}" | cut -d "," -f 1)
                kernel_flavor=$(echo "${workflows[$j]}" | cut -d "," -f 2)
                kernel_flavor_clean=$(echo $kernel_flavor | tr '.' '-')
                kernel_arch=$(echo "${workflows[$j]}" | cut -d "," -f 3-)
                sed -e "s/%%ARCHITECTURE%%/$kernel_arch/;s/%%KERNEL_FLAVOR%%/$kernel_flavor/;s/%%KERNEL_FLAVOR_CLEAN%%/$kernel_flavor_clean/;s/%%VERSION%%/$version/" ./workflow-templates/cache_kernel.yaml.in
                workflow_targets=()
                for k in "${targets[@]}"; do
                    value="${images[$j-$k]:-}"
                    if [ -z "$value" ]; then
                        continue
                    fi
                    image_arch="$(echo "$value" | cut -d "," -f 4-)"
                    akmods_target="$(echo "$value" | cut -d "," -f 3)"
                    workflow_targets+=(build-"$kernel_flavor_clean"_"$version"_"$akmods_target")
                    sed "s/%%ARCHITECTURE%%/$image_arch/;s/%%VERSION%%/$version/;s/%%KERNEL_FLAVOR%%/$kernel_flavor/;s/%%AKMODS_TARGET%%/$akmods_target/;s/%%KERNEL_FLAVOR_CLEAN%%/$kernel_flavor_clean/" "./workflow-templates/job.yaml.in"
                done
                json_needs="$(jq -nM '$ARGS.positional' --args ${workflow_targets[@]} | jq @json)"
                json_needs=${json_needs//[\\\"]}
                sed -e "s|%%KERNEL_FLAVOR%%|$kernel_flavor|;s|%%KERNEL_FLAVOR_CLEAN%%|$kernel_flavor_clean|;s|%%VERSION%%|$version|;s|%%NEEDS%%|$json_needs|" ./workflow-templates/check-status.yaml.in
            done
            } > "./.github/workflows/build-akmods-$i.yml"
        done
    }

    main
