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

[private]
default:
    {{ just }} --list

# Remove  Directory
clean:
    rm -rf {{ BUILDDIR }}

# Get the Kernel Version
[private]
get-kernel-version:
    #!/usr/bin/bash
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
            $dnf makecache >&2
            linux=$($dnf repoquery --whatprovides kernel | sort -V | tail -n1 | sed 's/.*://')
            ;;
        "centos-hsk")
            $dnf -y install centos-release-hyperscale-kernel >&2
            $dnf makecache >&2
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
    # Put into Github Output if it Exists
    {{ if env('GITHUB_OUTPUT', '') != '' { 'echo $output | jq -r "to_entries[] | \"\(.key)=\(.value)\"" | xargs -I "{}" echo "{}" >> ' + env('GITHUB_OUTPUT') } else { '' } }}
    # Put the json into Github Output if it Exists
    {{ if env('GITHUB_OUTPUT', '') != '' { 'echo "json_b64=$(echo $output | base64 -w 0)" >> ' + env('GITHUB_OUTPUT') } else { '' } }}
    
# Cache Kernel Version
@cache-kernel-version:
    [ ! -f {{ version_json }} ] && {{ just }} get-kernel-version > {{ version_json }} || :

# Fetch the desired kernel
fetch-kernel: (cache-kernel-version)
    #!/usr/bin/bash
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
        --env DUAL_SIGN=true \
        --env KERNEL_BUILD_TAG="$(jq -r '.kernel_build_tag' < {{ version_json }})" \
        --env KERNEL_FLAVOR="{{ kernel_flavor }}" \
        --env KERNEL_NAME="$(jq -r '.kernel_name' < {{ version_json }})" \
        --env KERNEL_VERSION="$(jq -r '.kernel_release' < {{ version_json }})" \
        --volume {{ KCWD }}:/tmp/kernel-cache \
        --entrypoint /bin/bash \
        -dt "{{ builder }}")
    trap '{{ podman }} rm -f -t 0 $builder &>/dev/null' EXIT SIGINT
    podman exec $builder bash -x /tmp/kernel-cache/fetch-kernel.sh /tmp/kernel-cache >&2
    echo "{{ datetime_utc('%Y%m%d') }}" > {{ KCPATH / 'kernel-cache-date' }}
    find {{ KCPATH }}

# Check Secureboot (Only Needed for Cache-Hits)
secureboot: (cache-kernel-version) (fetch-kernel)
    #!/usr/bin/bash
    set "${CI:+-x}" -euo pipefail
    kernel_name="$(jq -r '.kernel_name' < {{ version_json }})"
    kernel_release="$(jq -r '.kernel_release' < {{ version_json }})"
    if [[ ! "$(ls -A {{ KCPATH }}/)" ]]; then
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

# Build Akmods
build: (cache-kernel-version) (fetch-kernel)
    #!/usr/bin/bash
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
        "--label" "org.opencontainers.image.source=https://raw.githubusercontent.com/ublue-os/cayo/refs/heads/main/Containerfile.in"
        "--label" "org.opencontainers.image.title=akmods{{ if akmods_target != 'common' { '-' + akmods_target } else { '' } }}"
        "--label" "org.opencontainers.image.url=https://github.com/{{ _org / _repo }}"
        "--label" "org.opencontainers.image.vendor='{{ _org }}'"
        "--label" "org.opencontainers.image.version={{ shell("jq -r '.kernel_release' < $1", version_json) + '-' + datetime_utc('%Y%m%d') }}"
        "--label" "ostree.linux={{ shell("jq -r '.kernel_release' < $1", version_json) }}"
    )
    TAGS=(
        "--tag" "akmods{{ if akmods_target != 'common' { '-' + akmods_target } else { '' } }}:{{ kernel_flavor + '-' + version }}"
        "--tag" "akmods{{ if akmods_target != 'common' { '-' + akmods_target } else { '' } }}:{{ kernel_flavor + '-' + version + '-' + shell("jq -r '.kernel_release' < $1", version_json) }}"
        "--tag" "akmods{{ if akmods_target != 'common' { '-' + akmods_target } else { '' } }}:{{ kernel_flavor + '-' + version + '-' + trim(read(KCPATH / 'kernel-cache-date')) }}"
    )

    {{ podman }} build -f Containerfile.in --volume {{ KCPATH }}:/tmp/kernel_cache:ro "${CPP_FLAGS[@]}" "${LABELS[@]}" "${TAGS[@]}" --target RPMS {{ justfile_dir () }}

test: (cache-kernel-version) (fetch-kernel)
    #!/usr/bin/bash
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
    if ! podman run akmods-test:latest; then
        echo "Signatures Failed" >&2
        exit 1
    fi

# Generate GHA Workflow
generate-workflows:
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
    ---
    # This is a generated workflow. Do not edit by hand.
    # Generate the workflow by running ./generate-workflows.sh at git root
    # Modify the inputs in ./workflow-templates
    EOF
        cat ./workflow-templates/workflow.yaml.in
        for i in "${!workflows[@]}"; do
            version=$(echo "${workflows[$i]}" | cut -d "," -f 1)
            kernel_flavor=$(echo "${workflows[$i]}" | cut -d "," -f 2)
            kernel_flavor_clean=$(echo $kernel_flavor | tr '.' '-')
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
