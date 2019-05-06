FROM make-rpm-base:latest
LABEL maintainer="ncutler@suse.com"

RUN source ~/.bashrc \
    && echo "osc version: $($oosc --version)" \
    && $oosc co filesystems:ceph:octopus:upstream ceph
