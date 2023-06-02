#Build from base, simpley because it's the smallest image
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-base}"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

COPY build*.sh /tmp
COPY certs /tmp/certs
COPY ublue-os-akmods-addons.spec /tmp/ublue-os-akmods-addons/ublue-os-akmods-addons.spec

ADD https://negativo17.org/repos/fedora-steam.repo \
    /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-steam.repo

RUN /tmp/build-prep.sh

RUN /tmp/build-ublue-os-akmods-addons.sh

RUN /tmp/build-kmod-v4l2loopback.sh
RUN /tmp/build-kmod-wl.sh
# disabled until has kernel 6.3 support
#RUN /tmp/build-kmod-xone.sh
RUN /tmp/build-kmod-xpadneo.sh

RUN mkdir -p /var/cache/rpms/{kmods,ublue-os}
RUN cp /tmp/ublue-os-akmods-addons/rpmbuild/RPMS/noarch/ublue-os-akmods-addons*.rpm \
        /var/cache/rpms/ublue-os/
RUN for RPM in $(find /var/cache/akmods/ -type f -name \*.rpm); do \
        cp "${RPM}" /var/cache/rpms/kmods/; \
    done

RUN find /var/cache/rpms

FROM scratch

COPY --from=builder /var/cache/rpms /rpms
