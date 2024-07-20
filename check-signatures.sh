#!/usr/bin/bash

source /tmp/info.sh

KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
PUBLIC_CHAIN="/tmp/certs/public_key_chain.pem"

for module in /usr/lib/modules/"${KERNEL}"/extra/*/*.ko*;
do
    module_basename=${module:0:-3}
    module_suffix=${module: -3}
    if [[ "$module_suffix" == ".xz" ]]; then
            xz --decompress "$module"
            /tmp/dual-sign-check.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
            xz -f "${module_basename}"
    elif [[ "$module_suffix" == ".gz" ]]; then
            gzip -d "$module"
            /tmp/dual-sign-check.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
            gzip -9f "${module_basename}"
    else
            /tmp/dual-sign-check.sh "${KERNEL}" "${module}" "${PUBLIC_CHAIN}"
    fi
done
