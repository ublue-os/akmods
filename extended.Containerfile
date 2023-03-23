ARG IMAGE_NAME="${IMAGE_NAME:-silverblue}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-silverblue}"
ARG BASE_IMAGE="ghcr.io/dhoell/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

ARG IMAGE_NAME="${IMAGE_NAME}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION}"
ARG AKMOD_OTHERS="ghcr.io/dhoell/ublue-akmod-others"
ARG AKMODS_VERSION="${FEDORA_MAJOR_VERSION}"

COPY --from=${AKMOD_OTHERS}:${AKMODS_VERSION} / .

ADD justfile-akmods /tmp/justfile-akmods
RUN cat /tmp/justfile-akmods >> /usr/share/ublue-os/ublue-os-just/justfile

ADD extended-install.sh /tmp/extended-install.sh

RUN /tmp/extended-install.sh
RUN rm -rf /tmp/* /var/*
RUN ostree container commit
RUN mkdir -p /var/tmp && chmod -R 1777 /var/tmp
