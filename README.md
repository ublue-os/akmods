[![build-ublue](https://github.com/ublue-os/akmods/actions/workflows/build.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build.yml)

# ublue-os akmods

A layer for adding extra kernel modules to your image. Use for better hardware support and a few other features!

# Usage

Add this to your Containerfile to install all the RPM packages:

    COPY --from=ghcr.io/ublue-os/akmods:latest /rpms/ /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/*.rpm

# Features

Feel free to PR more kmod build scripts into this repo!

- ublue-os-akmods-key - installs our kmods signing key; install and import to allow SecureBoot systems to use these kmods
- [v4l2loopback](https://github.com/umlaeute/v4l2loopback) - allows creating "virtual video devices"

# Adding kmods

If you have a kmod you want to contribute send a pull request by adding a script using [build-kmod-v4l2loopback.sh](https://github.com/ublue-os/akmods/blob/main/build-kmod-v4l2loopback.sh) as an example.

# Verification

These images are signed with sisgstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command:

    cosign verify --key cosign.pub ghcr.io/ublue-os/akmods

