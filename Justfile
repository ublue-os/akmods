set unstable := true
set dotenv-load := true

podman := which('podman') || require('podman-remote')
just := just_executable()
version_cache := shell('mkdir -p $1 && echo $1', absolute_path('build'/kernel_flavor + '-' + version))
version_json := version_cache / 'cache.json'
KCWD := shell('mkdir -p $1 && echo $1', version_cache / 'KCWD')

kernel_flavor := env('AKMODS_KERNEL', 'main')
version := env('AKMODS_VERSION', '42')
akmods_target := env('AKMODS_TARGET', 'common')
bazzite_tag := env('AKMODS_BAZZITE_TAG', '')

[private]
default:
    {{ just }} --list

# Remove Build Directory
clean:
    rm -rf {{ justfile_dir() }}/build

# Get the Kernel Version
[private]
get-kernel-version:
    #!/usr/bin/bash
    set "${CI:+-x}" -euo pipefail
    build_image={{ if kernel_flavor =~ 'centos' { 'quay.io/centos/centos:' + version } else if  kernel_flavor =~ 'longterm' { 'quay.io/fedora/fedora:' + version } else { '' } }}
    if [[ -n "$build_image" ]]; then
        {{ podman }} pull --retry 3 "$build_image" >&2
        container_name="fq-$(uuidgen)"
        dnf="{{ podman }} exec -t $container_name dnf"
        {{ podman }} run --entrypoint /bin/bash --name "$container_name" -dt "$build_image" >&2
        $dnf install -y --setopt=install_weak_deps=False dnf-plugins-core >&2
        trap '{{ podman }} rm -f -t 0 $container_name &>/dev/null' EXIT SIGTERM
    fi

    coreos_kernel() {
        coreos_version=${1}
        image_linux="$(skopeo inspect docker://quay.io/fedora/fedora-coreos:$coreos_version --format '{{{{ index .Labels "ostree.linux" }}')"
        # Kernel Pin Location
        # if [[ "{{ kernel_flavor }}" =~ coreos-stable ]]; then
        #     image_linux=""
        # fi

        # Get Variables
        major_minor_patch="$(echo $image_linux | grep -oP '^\d+\.\d+\.\d+')"
        kernel_rel_part=$(echo $image_linux | grep -oP '^\d+\.\d+\.\d+\-\K([123][0]{2})')
        arch="$(echo $image_linux | grep -oP 'fc\d+\.\K.*$')"
        kernel_rel="$kernel_rel_part.fc{{ version }}"
        kernel_version="$major_minor_patch-$kernel_rel.$arch"
        URL="https://kojipkgs.fedoraproject.org/packages/kernel/"$major_minor_patch"/"$kernel_rel"/"$arch"/kernel-"$kernel_version".rpm"

        echo "Querying koji for ${coreos_version} kernel: $kernel_version" >&2
        echo "$URL" >&2
        HTTP_RESP=$(curl -sI "$URL" | grep ^HTTP)
        linux=""
        if grep -qv "200 OK" <<< "${HTTP_RESP}"; then
            echo "Koji failed to find $coreos_version kernel: $kernel_version" >&2
            case "$kernel_rel_part" in
                "300") kernel_rel_part="200" ;;
                "200") kernel_rel_part="100" ;;
                "100") ;;
                *) echo "unexpected kernel_rel_part ${kernel_rel_part}" >&2 ;;
            esac
            kernel_rel="$kernel_rel_part.fc{{ version }}"
            kernel_version="$major_minor_patch-$kernel_rel.$arch"
            URL="https://kojipkgs.fedoraproject.org/packages/kernel/"$major_minor_patch"/"$kernel_rel"/"$arch"/kernel-"$kernel_version".rpm"
            echo "Re-querying koji for ${coreos_version} kernel: $kernel_version" >&2
            echo "$URL" >&2
            HTTP_RESP=$(curl -sI "$URL" | grep ^HTTP)
            if grep -qv "200 OK" <<< "${HTTP_RESP}"; then
                echo "Koji failed to find $coreos_version kernel: $kernel_version" >&2
            fi
        fi
        if grep -q "200 OK" <<< "${HTTP_RESP}"; then
            linux=$kernel_version
        fi
    }

    kernel_name=kernel
    case {{ kernel_flavor }} in
        "bazzite")
            if [[ -n "{{ bazzite_tag }}" ]]; then
                latest="$(curl -s "https://api.github.com/repos/bazzite-org/kernel-bazzite/releases/tags/{{ bazzite_tag }}" )"
            else
                latest="$(curl -s "https://api.github.com/repos/bazzite-org/kernel-bazzite/releases/latest")"
            fi
            linux=$(echo "$latest" | jq -r '.assets[].name | match("kernel-.*fc{{ version }}.{{ arch() }}.rpm").string' | head -1 | sed "s/kernel-//g;s/.rpm//g")
            build_tag=$(echo -E $latest | jq -r '.tag_name')
            ;;
        "centos")
            $dnf repoquery --whatprovides kernel >&2
            linux=$($dnf repoquery --whatprovides kernel | sort -V | tail -n1 | sed 's/.*://')
            ;;
        "centos-hsk")
            $dnf -y install centos-release-hyperscale-kernel >&2
            $dnf repoquery --whatprovides kernel >&2
            linux=$($dnf repoquery --enablerepo="centos-hyperscale" --whatprovides kernel | sort -V | tail -n1 | sed 's/.*://')
            ;;
        "coreos-stable")
            coreos_kernel stable
            ;;
        "coreos-testing")
            coreos_kernel testing
            ;;
        "longterm"*)
            $dnf copr enable -y kwizart/kernel-{{ kernel_flavor }} >&2
            $dnf repoquery --whatprovides kernel-longterm >&2
            linux=$($dnf repoquery --whatprovides kernel-longterm | sort -V | tail -n1 | sed 's/.*://')
            kernel_name=kernel-longterm
            ;;
        "main")
            base_image_name="base"
            if [[ {{ version }} > 40 ]]; then
                base_image_name+="-atomic"
            fi
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
    linux="$(echo $linux | tr -d '[:cntrl:]')"

    # Debug Output
    {{ if bazzite_tag != '' { 'echo "kernel_build_tag: ${build_tag}" >&2' } else { '' } }}
    echo "kernel_flavor: {{ kernel_flavor }}" >&2
    echo "kernel_major_minor_patch: ${kernel_major_minor_patch}" >&2
    echo "kernel_release: ${linux}" >&2
    echo "kernel_name: ${kernel_name}" >&2

    # Return
    jq -nM \
        --arg build_tag "${build_tag:-}" \
        --arg kernel_flavor "{{ kernel_flavor}}" \
        --arg kernel_major_minor_patch "$kernel_major_minor_patch" \
        --arg kernel_release "$linux" \
        --arg kernel_name "$kernel_name" \
        '{
            "kernel_build_tag": $build_tag,
            "kernel_flavor": $kernel_flavor,
            "kernel_major_minor_patch": $kernel_major_minor_patch,
            "kernel_release": $kernel_release,
            "kernel_name": $kernel_name
        }'
    
# Cache Kernel Version
[private]
@cache-kernel-version:
    [ ! -f {{ version_json }} ] && {{ just }} get-kernel-version > {{ version_json }} || :

# Fetch the desired kernel
fetch-kernel: (cache-kernel-version)
    #!/usr/bin/bash
    set "${CI:+-x}" -euo pipefail

    # Pull Build Image
    build_image={{ if kernel_flavor =~ 'centos' { 'quay.io/centos/centos:' } else { 'quay.io/fedora/fedora:' } }}{{ version }}
    {{ podman }} pull --retry 3 "$build_image" >&2

    # Prep Environment
    cp -a fetch-kernel.sh certs {{ KCWD }} >&2

    # Fetch Kernels
    builder=$(podman run \
        --security-opt label=disable \
        --env DUAL_SIGN=true \
        --env KERNEL_BUILD_TAG="$(jq -r '.kernel_build_tag' < {{ version_json }})" \
        --env KERNEL_FLAVOR="{{ kernel_flavor }}" \
        --env KERNEL_NAME="$(jq -r '.kernel_name' < {{ version_json }})" \
        --env KERNEL_VERSION="$(jq -r '.kernel_release' < {{ version_json }})" \
        --volume {{ KCWD }}:/tmp/kernel-cache \
        --entrypoint /bin/bash \
        -dt "$build_image")
    trap '{{ podman }} rm -f -t 0 $builder &>/dev/null' EXIT SIGINT
    podman exec $builder bash -x /tmp/kernel-cache/fetch-kernel.sh /tmp/kernel-cache >&2
    find {{ KCWD }}/rpms

# Check Secureboot (Only Needed for Cache-Hits)
secureboot: (cache-kernel-version)
    #!/usr/bin/bash
    set "${CI:+-x}" -euo pipefail
    kernel_name="$(jq -r '.kernel_name' < {{ version_json }})"
    kernel_release="$(jq -r '.kernel_release' < {{ version_json }})"
    if [[ ! -d {{ KCWD }}/rpms ]]; then
        echo "No RPMs staged" >&2
        exit 1
    fi
    pushd {{ KCWD }}/rpms >/dev/null
    SBTEMP="$(mktemp -d -p {{ version_cache }})"
    trap 'rm -rf $SBTEMP' EXIT SIGINT
    rpm2cpio "${kernel_name}-core-${kernel_release}.rpm" | cpio -D $SBTEMP -idm &>/dev/null
    popd >/dev/null
    if [[ "{{ env('GITHUB_EVENT_NAME', '') }}" =~ schedule|workflow_dispatch|merge_group ]]; then
        cp certs/public_key.der "$SBTEMP/lib/modules/$kernel_release/kernel-sign.der"
        cp certs/public_key_2.der "$SBTEMP/lib/modules/$kernel_release/akmods.der"
    else
        cp certs/public_key.der.test "$SBTEMP/lib/modules/$kernel_release/kernel-sign.der"
        cp certs/public_key_2.der.test "$SBTEMP/lib/modules/$kernel_release/akmods.der"
    fi
    pushd "$SBTEMP/lib/modules/$kernel_release/" >/dev/null
    openssl x509 -in kernel-sign.der -out kernel-sign.crt
    openssl x509 -in akmods.der -out akmods.crt
    if ! sbverify --cert kernel-sign.crt vmlinuz >/dev/null || ! sbverify --cert akmods.crt vmlinuz >/dev/null; then
        popd >/dev/null
        echo "Signatures Failed" >&2
        exit 1
    fi
    popd >/dev/null
