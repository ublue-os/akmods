#Build from base, simpley because it's the smallest image
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-base}"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

COPY build*.sh /tmp
COPY certs /tmp/certs
COPY ublue-os-akmods-key.spec /tmp/ublue-os-akmods-key/ublue-os-akmods-key.spec

RUN /tmp/build-prep.sh

RUN /tmp/build-ublue-os-akmods-key.sh

RUN /tmp/build-kmod-v4l2loopback.sh
RUN /tmp/build-kmod-wl.sh

RUN mkdir /var/cache/rpms && \
    for RPM in $(find /var/cache/akmods/ -type f -name \*.rpm); do \
        echo ${RPM}; \
        cp "${RPM}" /var/cache/rpms/; \
    done && \
    cp /tmp/ublue-os-akmods-key/rpmbuild/RPMS/noarch/ublue-os-akmods-key*.rpm /var/cache/rpms/

FROM scratch

COPY --from=builder /var/cache/rpms /rpms
