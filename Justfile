set unstable := true
set dotenv-load := true

podman := which('podman') || require('podman-remote')
just := just_executable()
BUILDDIR := shell('mkdir -p $1 && echo $1', env('AKMODS_BUILDDIR', absolute_path('build')))
version_cache := shell('mkdir -p $1 && echo $1', BUILDDIR / kernel_flavor + '-' + version)
KCWD := shell('mkdir -p $1 && echo $1', version_cache / 'KCWD')
KCPATH := shell('mkdir -p $1 && echo $1', env('KCPATH', KCWD / 'rpms'))
version_json := KCPATH / 'cache.json'
builder := if kernel_flavor =~ 'centos' { 'quay.io/centos/centos:' + version } else { 'quay.io/fedora/fedora:' + version }


# Inputs

kernel_flavor := env('AKMODS_KERNEL', shell('yq ".defaults.kernel_flavor" images.yaml'))
version := env('AKMODS_VERSION', if kernel_flavor =~ 'centos' { '10' } else { shell('yq ".defaults.version" images.yaml') })
akmods_target := env('AKMODS_TARGET', if kernel_flavor =~ 'centos' { 'zfs' } else { shell('yq ".defaults.akmods_target" images.yaml') })
bazzite_tag := env('AKMODS_BAZZITE_TAG', '')

# Check if valid

check_valid := if shell('yq ".images.$1[\"$2\"].$3" images.yaml', version, kernel_flavor, akmods_target) != 'null' { 'true' } else { error('Invalid Image Combination') }
_description := shell('yq ".images.$1[\"$2\"].$3.description" images.yaml', version, kernel_flavor, akmods_target)
_org := shell('yq ".images.$1[\"$2\"].$3.org" images.yaml', version, kernel_flavor, akmods_target)
_repo := shell('yq ".images.$1[\"$2\"].$3.repo" images.yaml', version, kernel_flavor, akmods_target)
registry := env('AKMODS_REGISTRY', shell('yq ".images.$1[\"$2\"].$3.registry" images.yaml', version, kernel_flavor, akmods_target))
transport := env('AKMODS_TRANSPORT', shell('yq ".images.$1[\"$2\"].$3.transport" images.yaml', version, kernel_flavor, akmods_target))
akmods_name := 'akmods' + if akmods_target != 'common' { '-' +akmods_target } else { '' }

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
    set "${CI:+-x}" -euo pipefail
    if [[ {{ kernel_flavor }} =~ centos|longterm ]]; then
        {{ podman }} pull --retry 3 "{{ builder }}" >&2
        container_name="fq-$(uuidgen)"
        builder=$({{ podman }} run --entrypoint /bin/bash -dt "{{ builder }}")
        dnf="{{ podman }} exec -t $builder dnf"
        $dnf install -y --setopt=install_weak_deps=False dnf-plugins-core >&2
        trap '{{ podman }} rm -f -t 0 $builder &>/dev/null' EXIT SIGTERM
    fi

    coreos_kernel() {
        # query the upstream coreos (stable or testing) image and provide the kernel version
        coreos_version=${1}
        image_linux="$(skopeo inspect docker://quay.io/fedora/fedora-coreos:$coreos_version --format '{{{{ index .Labels "ostree.linux" }}')"

        # Kernel Pin Location
        # this gives us a consistent place to handle pinning for coreos stable dependent usages
        # including: ucore stable, bluefin/aurora stable, bluefin lts (using centos-kmodsig version matching)
        #if [[ "{{ kernel_flavor }}" =~ coreos-stable ]]; then
        #    image_linux="6.14.11-300.fc42.$(uname -m)"
        #fi

        # This always provides kernel version from the upstream image as the resulting $image_linux variable
        # It should be verified downloadable by verify_kernel_fedora() and verify_kernel_centos_kmodsig()
    }

    verify_kernel_fedora() {
        # using the kernel version from upstream image
        # verify the expected version exist in koji packages for Fedora of the required version

        # Get Variables
        coreos_version=${1}
        major_minor_patch="$(echo $image_linux | grep -oP '^\d+\.\d+\.\d+')"
        kernel_rel_part=$(echo $image_linux | grep -oP '^\d+\.\d+\.\d+\-\K([123][0][0-9])')
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
            HTTP_RESP=$(curl -sI "$URL" | grep ^HTTP)
            if grep -qv "200 OK" <<< "${HTTP_RESP}"; then
                echo "Koji re-query failed to find $coreos_version kernel: $kernel_version" >&2
            fi
        fi
        if grep -q "200 OK" <<< "${HTTP_RESP}"; then
            linux=$kernel_version
        fi
    }

    verify_kernel_centos_kmodsig() {
        # using the kernel version from upstream image
        # verify the expected version exist in koji packages for CentOS KMODSIG of the required version

        # Get Variables
        major_minor_patch="$(echo $image_linux | grep -oP '^\d+\.\d+\.\d+')"
        arch="$(echo $image_linux | grep -oP 'fc\d+\.\K.*$')"
        kernel_rel="1.el{{ version }}"
        kernel_version="$major_minor_patch-$kernel_rel.$arch"
        URL="https://cbs.centos.org/kojifiles/packages/kernel/${major_minor_patch}/${kernel_rel}/${arch}/kernel-${kernel_version}.rpm"

        echo "Querying koji for CentOS Kmods SIG kernel: $kernel_version" >&2
        echo "$URL" >&2
        HTTP_RESP=$(curl -sI "$URL" | grep ^HTTP)
        linux=""
        if grep -qv "200 OK" <<< "${HTTP_RESP}"; then
            echo "Koji failed to find CentOS Kmods SIG kernel: $kernel_version" >&2
            # a naive fallback as this could only occur if the .2 release was built and .1 removed
            # however, it provides an example for possible improvements to trying to use the latest release
            kernel_rel="2.el{{ version }}"
            kernel_version="$major_minor_patch-$kernel_rel.$arch"
            URL="https://cbs.centos.org/kojifiles/packages/kernel/${major_minor_patch}/${kernel_rel}/${arch}/kernel-${kernel_version}.rpm"
            echo "Re-querying koji for CentOS Kmods SIG kernel: $kernel_version" >&2
            echo "$URL" >&2
            HTTP_RESP=$(curl -sI "$URL" | grep ^HTTP)
            if grep -qv "200 OK" <<< "${HTTP_RESP}"; then
                echo "Koji re-query failed to find CentOS Kmods SIG kernel: $kernel_version" >&2
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
            $dnf makecache >&2
            linux=$($dnf repoquery --whatprovides kernel | sort -V | tail -n1 | sed 's/.*://')
            ;;
        "centos-kmodsig")
            $dnf -y install centos-release-kmods-kernel >&2
            $dnf makecache >&2
            coreos_kernel stable
            verify_kernel_centos_kmodsig
            # Ideally we could check the value of $linux verified above is available in the `centos-release-kmods-kernel` repo, but at this time,
            # the current CoreOS 6.15.9 kernel is just slightly too old to be available in the SIG repo. Hopefully caching for kojifiles is adequate
            #linux_repo=$($dnf repoquery --enablerepo="centos-kmods-kernel" --whatprovides kernel-core | sort -V | tail -n1 | sed 's/.*://')
            ;;
        "coreos-stable")
            coreos_kernel stable
            verify_kernel_fedora stable
            ;;
        "coreos-testing")
            coreos_kernel testing
            verify_kernel_fedora testing
            ;;
        "longterm"*)
            $dnf copr enable -y kwizart/kernel-{{ kernel_flavor }} >&2
            $dnf makecache >&2
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
    [ ! -f {{ version_json }} ] && {{ just }} get-kernel-version > {{ version_json }} || :

# Populate Github Output
[private]
@populate-github-output:
    {{ if env('GITHUB_OUTPUT', '') != '' { 'jq -r "to_entries[] | \"\(.key)=\(.value)\"" < ' + version_json + ' | xargs -I "{}" echo "{}" >> ' + env('GITHUB_OUTPUT') } else { '' } }}

# Fetch and Sign Kernel RPMs
[group('Build')]
fetch-kernel: (cache-kernel-version)
    #!/usr/bin/env bash
    {{ if path_exists(version_json) != 'true' { error('Need to run just cache-kernel-version first for dry-run') } else { '' } }}
    {{ if path_exists( KCPATH / shell("jq -r '.kernel_name + \"-\" + .kernel_release + \".rpm\"' < $1", version_json)) == 'true' { 'exit 0' } else { '' } }}
    set "${CI:+-x}" -euo pipefail

    # Pull Build Image
    {{ podman }} pull --retry 3 "{{ builder }}" >&2

    # Prep Environment
    cp -a fetch-kernel.sh certs {{ KCWD }} >&2

    # Fetch Kernels
    builder=$(podman run \
        --security-opt label=disable \
        {{ if env('CI', '') != '' { '--env CI=1' } else { '' } }} \
        --env DUAL_SIGN=true \
        --env KERNEL_BUILD_TAG="{{ shell('jq -r .kernel_build_tag < $1', version_json) }}" \
        --env KERNEL_FLAVOR="{{ kernel_flavor }}" \
        --env KERNEL_NAME="{{ shell('jq -r .kernel_name < $1', version_json) }}" \
        --env KERNEL_VERSION="{{ shell('jq -r .kernel_release < $1' , version_json) }}" \
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
    set "${CI:+-x}" -euo pipefail
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
            "--cpp-flag=-DKMOD_MODULE_ARG=KMOD_MODULE={{ if akmods_target =~ 'open' { "kernel-open" } else { 'kernel' } }}"
        )
    fi
    LABELS=(
        "--label" "io.artifacthub.package.deprecated=false"
        "--label" "io.artifacthub.package.keywords=bootc,fedora,bluefin,bazzite,centos,cayo,aurora,ublue,universal-blue"
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
    TAGS=(
        "--tag" "{{ akmods_name + ':' + kernel_flavor + '-' + version + '-' + arch() }}"
        "--tag" "{{ akmods_name + ':' + kernel_flavor + '-' + version + '-' + shell("jq -r '.kernel_release' < $1", version_json) }}"
    )

    {{ podman }} build -f Containerfile.in --volume {{ KCPATH }}:/tmp/kernel_cache:ro "${CPP_FLAGS[@]}" "${LABELS[@]}" "${TAGS[@]}" --target RPMS {{ justfile_dir () }}

# Test Cached Akmod RPMs
[group('Build')]
test: (cache-kernel-version) (fetch-kernel)
    #!/usr/bin/env bash
    set "${CI:+-x}" -euo pipefail
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
            "--cpp-flag=-DKMOD_MODULE_ARG=KMOD_MODULE={{ if akmods_target =~ 'open' { "kernel-open" } else { 'kernel' } }}"
        )
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

    declare -a TAGS=($({{ podman }} image list {{ 'localhost' / akmods_name + ':' + kernel_flavor + '-' + version + '-' + arch() }} --noheading --format 'table {{{{ .Tag }}'))
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
        "io.artifacthub.package.keywords=bootc,fedora,bluefin,bazzite,centos,cayo,aurora,ublue,universal-blue"
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
    if skopeo inspect docker://{{ manifest_image }}-x86_64 &>/dev/null; then
        {{ podman }} manifest add {{ manifest_image }} docker://{{ manifest_image }}-x86_64
    fi
    if skopeo inspect docker://{{ manifest_image }}-aarch64 &>/dev/null; then
        {{ podman }} manifest add {{ manifest_image }} docker://{{ manifest_image }}-aarch64
    fi
    if skopeo inspect docker://{{ manifest_image_kernel }}-x86_64 &>/dev/null; then
        {{ podman }} manifest add {{ manifest_image_kernel }} docker://{{ manifest_image_kernel }}-x86_64
    fi
    if skopeo inspect docker://{{ manifest_image_kernel }}-aarch64 &>/dev/null; then
        {{ podman }} manifest add {{ manifest_image_kernel }} docker://{{ manifest_image_kernel }}-aarch64
    fi

    # Push Manifest
    for i in {1..5}; do
        {{ podman }} manifest push --all {{ if env('COSIGN_PRIVATE_KEY', '') != '' { '--sign-by-sigstore=/etc/ublue-os-param-file.yaml' } else { '' } }} {{ manifest_image }} && break || sleep $((5 * i));
        if [[ $i -eq '5' ]]; then
            exit 1
        fi
    done
    {{ if env('CI', '') != '' { 'log_sum "{{ manifest_image }}"' } else { '' } }}

    for i in {1..5}; do
        {{ podman }} manifest push --all {{ if env('COSIGN_PRIVATE_KEY', '') != '' { '--sign-by-sigstore=/etc/ublue-os-param-file.yaml' } else { '' } }} {{ manifest_image }} && break || sleep $((5 * i));
        if [[ $i -eq '5' ]]; then
            exit 1
        fi
    done
    {{ if env('CI', '') != '' { 'log_sum "{{ manifest_image_kernel }}"' } else { '' } }}

    {{ if env('CI', '') != '' { 'log_sum "\`\`\`"' } else { '' } }}

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

        rm -f "./.github/workflows/build"*".yml"

        declare -A images=()
        declare -A workflows=()
        versions=($(yq '.images | keys | .[]' images.yaml | sort | uniq))
        flavors=($(yq '.images.* | keys | .[]' images.yaml | sort | uniq))
        targets=($(yq 'explode(.).images.*.* | keys | .[]' images.yaml | sort | uniq))

        for i in "${versions[@]}"; do
            for j in "${flavors[@]}"; do
                for k in "${targets[@]}"; do
                    #shellcheck disable=SC1087
                    if [[ "$(yq ".images.$i[\"$j\"].$k" images.yaml)" != "null" ]]; then
                        arch=$(yq -o json "explode(.).images.$i[\"$j\"].$k.architecture" images.yaml | jq -c)
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
            sed "s/AKMODs/${i^^} akmods/;s/05/$(printf '%02d' $(( RANDOM % 30)))/g" ./workflow-templates/workflow.yaml.in
            if [[ "$i" =~ bazzite ]]; then
            cat <<'EOF'
        inputs:
          bazzite_tag:
            description: "The release tag for the bazzite kernel"
            required: false
            type: string
    EOF
            fi
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
                if [[ "$i" =~ bazzite ]]; then
                    printf '      %s\n' 'bazzite_tag: ${{{{ inputs.bazzite_tag }}'
                fi
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
