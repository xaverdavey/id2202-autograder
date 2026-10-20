FROM quay.io/podman/stable:v5.8.2

SHELL [ "/bin/bash", "-c" ]
WORKDIR /root

# Install rust
RUN dnf -y install gcc libpq-devel git file \
    && curl -Lo rustup.sh --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    && chmod +x rustup.sh \
    && ./rustup.sh -y \
    && rm rustup.sh

# Copy over the repo (except for the Docker files)
ADD .gitignore README.md LICENSE Cargo.toml Cargo.lock build.rs diesel.toml sailfish.toml /autograder/
ADD diesel    /autograder/diesel
ADD example   /autograder/example
ADD macros    /autograder/macros
ADD src       /autograder/src
ADD web       /autograder/web

WORKDIR /autograder

# Build the autograder
ARG CARGO_BUILD_FLAGS
RUN source /root/.bashrc \
    && cargo build ${CARGO_BUILD_FLAGS} \
    && cargo install diesel_cli --no-default-features --features "postgres"

# The base image is configured for rootless podman, which has to go through
# fuse-overlayfs. Here podman runs as root on a volume that supports overlayfs
# natively, so let it use the kernel driver: binaries cannot be executed from a
# FUSE mount on some kernels (notably the one Docker Desktop ships), which
# otherwise fails every grading container with "exec container process:
# Invalid argument". `fsync=0` goes along with it, as the kernel driver
# rejects that fuse-overlayfs option with EINVAL when mounting.
RUN sed -i -e '/^\s*mount_program\s*=/d' \
           -e 's/^\s*mountopt\s*=.*/mountopt = "nodev"/' \
           /etc/containers/storage.conf

# The base image is set up for podman where cgroups are not to be had, and
# turns them off: so every limit a grading container is given (--memory,
# --pids-limit) is dropped without a word. Here they are to be had (see
# delegate-cgroups below), so on, each container in its own cgroup and IPC
# namespace, so that one grading's processes and shared memory are no other's.
RUN sed -i -e 's/^cgroups="disabled"/cgroups="enabled"/' \
           -e 's/^cgroupns="host"/cgroupns="private"/' \
           -e 's/^ipcns="host"/ipcns="private"/' \
           /etc/containers/containers.conf \
    && grep -q '^cgroups="enabled"' /etc/containers/containers.conf

ENV PATH="/root/.cargo/bin:$PATH"

# Hands the cgroup controllers down to the grading containers, so that their
# memory and process limits hold (misc/container/delegate-cgroups.sh).
ADD misc/container/delegate-cgroups.sh /usr/local/bin/delegate-cgroups
ENTRYPOINT [ "/usr/local/bin/delegate-cgroups" ]
CMD [ "bash" ]
