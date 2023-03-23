#Build from ublue/base, simpley because it's the smallest image
ARG IMAGE_NAME="${IMAGE_NAME:-base-main}"
ARG BASE_IMAGE="ghcr.io/dhoell/${IMAGE_NAME}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

COPY build-others.sh /tmp/build-others.sh

ADD certs /tmp/certs

ADD ublue-os-akmods-key.spec /tmp/ublue-os-akmods-key/ublue-os-akmods-key.spec

RUN /tmp/build-others.sh

FROM scratch

COPY --from=builder /var/cache /var/cache
COPY --from=builder /tmp/ublue-os-akmods-key /tmp/ublue-os-akmods-key
