#Build from base, simpley because it's the smallest image
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-base}"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

COPY build*.sh /tmp
COPY certs /tmp/certs

# files for akmods
COPY ublue-os-akmods-addons.spec /tmp/ublue-os-akmods-addons/ublue-os-akmods-addons.spec
ADD https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/repo/fedora-${FEDORA_MAJOR_VERSION}/ublue-os-akmods-fedora-${FEDORA_MAJOR_VERSION}.repo \
    /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo
ADD https://negativo17.org/repos/fedora-steam.repo \
    /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-steam.repo
ADD https://negativo17.org/repos/fedora-multimedia.repo \
    /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo    

# files for nvidia
COPY ublue-os-nvidia-addons.spec /tmp/ublue-os-nvidia-addons/ublue-os-nvidia-addons.spec
ADD https://nvidia.github.io/nvidia-docker/rhel9.0/nvidia-docker.repo \
    /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/nvidia-container-runtime.repo
ADD https://copr.fedorainfracloud.org/coprs/eyecantcu/supergfxctl/repo/fedora-${FEDORA_MAJOR_VERSION}/eyecantcu-supergfxctl-fedora-${FEDORA_MAJOR_VERSION}.repo \
    /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/eyecantcu-supergfxctl.repo
ADD files/etc/nvidia-container-runtime/config-rootless.toml \
    /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/config-rootless.toml
ADD https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp \
    /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/nvidia-container.pp
ADD files/etc/sway/environment /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/environment


RUN /tmp/build-prep.sh

RUN /tmp/build-ublue-os-akmods-addons.sh
RUN /tmp/build-ublue-os-nvidia-addons.sh

RUN /tmp/build-kmod-evdi.sh
RUN /tmp/build-kmod-gasket.sh
RUN /tmp/build-kmod-gcadapter_oc.sh
RUN /tmp/build-kmod-openrgb.sh
RUN /tmp/build-kmod-steamdeck.sh
RUN /tmp/build-kmod-v4l2loopback.sh
RUN /tmp/build-kmod-wl.sh
RUN /tmp/build-kmod-xpadneo.sh
RUN /tmp/build-kmod-nvidia.sh 470
RUN /tmp/build-kmod-nvidia.sh 535

RUN cp /tmp/ublue-os-akmods-addons/rpmbuild/RPMS/noarch/ublue-os-akmods-addons*.rpm \
       /tmp/ublue-os-nvidia-addons/rpmbuild/RPMS/noarch/ublue-os-nvidia-addons*.rpm \
      /var/cache/rpms/ublue-os/
RUN for RPM in $(find /var/cache/akmods/ -type f -name \*.rpm); do \
        cp "${RPM}" /var/cache/rpms/kmods/; \
    done

RUN find /var/cache/rpms

FROM scratch

COPY --from=builder /var/cache/rpms /rpms
