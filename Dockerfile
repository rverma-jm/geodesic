#
# Geodesic base image
#
FROM nikiai/geodesic-base:debian

ENV BANNER "geodesic"

# Where to store state
ENV CACHE_PATH=/localhost/.geodesic

ENV GEODESIC_PATH=/usr/local/include/toolbox
ENV HOME=/root
ENV CLUSTER_NAME=root.x.y

# Install the select packages from the cloudposse package manager image
#
# Repo: <https://github.com/cloudposse/packages>
#
ARG PACKAGES="aws-iam-authenticator awless chamber fetch figurine gomplate goofys helm helmfile kubectl kubens kfctl sops stern terraform terragrunt yq"

ENV PACKAGES=${PACKAGES}
RUN git clone --depth=1 -b master https://github.com/cloudposse/packages.git && \
    rm -rf packages/.git
RUN make -C /packages/install ${PACKAGES}

#
# Python Dependencies
#
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

#
# helm
#
ENV HELM_HOME /var/lib/helm
ENV HELM_VALUES_PATH=${SECRETS_PATH}/helm/values
RUN helm completion bash > /etc/bash_completion.d/helm.sh \
    && mkdir -p ${HELM_HOME} \
    && mkdir -p ${HELM_HOME}/plugins

#
# Install helm repos
#
RUN helm repo add incubator  https://kubernetes-charts-incubator.storage.googleapis.com/ \
    && helm repo update

#
# Install helm plugins
#
ENV HELM_DIFF_VERSION 3.0.0-rc.7

RUN helm plugin install https://github.com/databus23/helm-diff --version v${HELM_DIFF_VERSION}

RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && dpkg -i session-manager-plugin.deb

#
# AWS
#
ENV AWS_DATA_PATH=/localhost/.aws/
ENV AWS_CONFIG_FILE=/localhost/.aws/config
ENV AWS_SHARED_CREDENTIALS_FILE=/localhost/.aws/credentials

#
# Shell
#
ENV HISTFILE=${CACHE_PATH}/history
ENV SHELL=/bin/bash
ENV LESS=-Xr
ENV SSH_AGENT_CONFIG=/var/tmp/.ssh-agent

# Reduce `make` verbosity
ENV MAKEFLAGS="--no-print-directory"
ENV MAKE_INCLUDES="Makefile Makefile.*"

# This is not a "multi-user" system, so we'll use `/etc` as the global configuration dir
# Read more: <https://wiki.archlinux.org/index.php/XDG_Base_Directory>
ENV XDG_CONFIG_HOME=/etc

# Clean up file modes for scripts
RUN find ${XDG_CONFIG_HOME} -type f -name '*.sh' -exec chmod 755 {} \;

COPY rootfs/ /

WORKDIR /conf

ENV AWS_SDK_LOAD_CONFIG=1

ENTRYPOINT ["/bin/bash"]
CMD ["-c", "init"]
