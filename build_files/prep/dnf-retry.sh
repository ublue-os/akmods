# shellcheck shell=bash
# dnf_retry <dnf args...>: retry dnf with fresh metadata after a failure.
dnf_retry() {
    local attempts="${DNF_RETRY_ATTEMPTS:-3}" delay="${DNF_RETRY_DELAY:-90}"
    local attempt=1 rc=0
    while :; do
        if (( attempt == 1 )); then
            dnf "$@" && return 0 || rc=$?
        else
            dnf --refresh "$@" && return 0 || rc=$?
        fi
        if (( attempt >= attempts )); then
            echo "dnf_retry: giving up after ${attempt} attempts (exit ${rc})" >&2
            return "$rc"
        fi
        echo "dnf_retry: attempt ${attempt}/${attempts} failed (exit ${rc}); refreshing metadata" >&2
        dnf clean metadata || echo "dnf_retry: 'dnf clean metadata' failed (exit $?), continuing" >&2
        sleep $(( delay * attempt ))
        attempt=$(( attempt + 1 ))
    done
}
