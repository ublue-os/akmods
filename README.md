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

## [![Repography logo](https://images.repography.com/logo.svg)](https://repography.com) / Recent activity [![Time period](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_badge.svg)](https://repography.com)
[![Timeline graph](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_timeline.svg)](https://github.com/ublue-os/akmods/commits)
[![Issue status graph](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_issues.svg)](https://github.com/ublue-os/akmods/issues)
[![Pull request status graph](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_prs.svg)](https://github.com/ublue-os/akmods/pulls)
[![Trending topics](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_words.svg)](https://github.com/ublue-os/akmods/commits)
[![Top contributors](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_users.svg)](https://github.com/ublue-os/akmods/graphs/contributors)
[![Activity map](https://images.repography.com/35181738/ublue-os/akmods/recent-activity/T0Pa2apPYwHMixrcCV3Uqb0q0CYYEtoNogUxrGLx_44/ktMjGfqYgbIT8oaj-vwafgnfXyAGRUbKQkejtxhCscI_map.svg)](https://github.com/ublue-os/akmods/commits)

