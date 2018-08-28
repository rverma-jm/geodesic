ARG PACKAGES_IMAGE=cloudposse/packages:0.8.1
FROM ${PACKAGES_IMAGE} as packages

WORKDIR /packages

#
# Install the select packages from the cloudposse package manager image
#
# Repo: <https://github.com/cloudposse/packages>
#
ARG PACKAGES="awless cfssl cfssljson chamber fetch gomplate goofys helm helmfile kubens sops stern terraform yq"
ENV PACKAGES=${PACKAGES}
RUN make dist

FROM nikiai/geodesic-base:debian

ENV BANNER "geodesic"

# Where to store state
ENV CACHE_PATH=/localhost/.geodesic

ENV GEODESIC_PATH=/usr/local/include/toolbox
ENV HOME=/conf
ENV SECRETS_PATH=${HOME}

WORKDIR /tmp

# Copy installer over to make package upgrades easy
COPY --from=packages /packages/install/ /packages/install/

# Copy select binary packages
COPY --from=packages /dist/ /usr/local/bin/

#
# Install kubeaws
#
ENV KOPS_VERSION=1.10.0
RUN curl --fail -sSL -O https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64\
    && mv kops-linux-amd64 /usr/local/bin/kops \
    && chmod +x /usr/local/bin/kops \
    && /usr/local/bin/kops completion bash > /etc/profile.d/kops.sh \
    && chmod 755 /etc/profile.d/kops.sh
ENV KOPS_MANIFEST=/conf/kops/manifest.yaml
ENV KOPS_TEMPLATE=/templates/kops/default.yaml

#
# Install kubectl
#
ENV KUBECTL_VERSION=1.10.3
RUN curl --fail -sSL -O https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && mv kubectl /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && kubectl completion bash > /etc/bash_completion.d/kubectl.sh

#
# Install heptio
#
ENV HEPTIO_VERSION=1.10.3
RUN curl --fail -sSL -O https://amazon-eks.s3-us-west-2.amazonaws.com/${HEPTIO_VERSION}/2018-06-05/bin/linux/amd64/heptio-authenticator-aws \
    && mv heptio-authenticator-aws /usr/local/bin/aws-iam-authenticator \
    && chmod +x /usr/local/bin/aws-iam-authenticator

#
# Install helm
#
ENV HELM_HOME /var/lib/helm
ENV HELM_VALUES_PATH=${SECRETS_PATH}/helm/values
RUN helm completion bash > /etc/bash_completion.d/helm.sh \
    && mkdir -p ${HELM_HOME} \
    && helm init --client-only \
    && mkdir -p ${HELM_HOME}/plugins

#
# Install helm repos
#
RUN helm repo add incubator  https://kubernetes-charts-incubator.storage.googleapis.com/ \
    && helm repo add coreos-stable https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/ \
    && helm repo update

#
# Install helm plugins
#
ENV HELM_APPR_VERSION 0.7.0
ENV HELM_EDIT_VERSION 0.2.0
ENV HELM_GITHUB_VERSION 0.2.0
ENV HELM_SECRETS_VERSION 1.2.9

RUN helm plugin install https://github.com/app-registry/appr-helm-plugin --version v${HELM_APPR_VERSION} \
    && helm plugin install https://github.com/mstrzele/helm-edit --version v${HELM_EDIT_VERSION} \
    && helm plugin install https://github.com/futuresimple/helm-secrets --version ${HELM_SECRETS_VERSION} \
    && helm plugin install https://github.com/sagansystems/helm-github --version ${HELM_GITHUB_VERSION}


# Install aws cli bundle
#
ENV AWSCLI_VERSION=1.15.66
RUN pip install --no-cache-dir awscli==${AWSCLI_VERSION} && \
    rm -rf /root/.cache && \
    find / -type f -regex '.*\.py[co]' -delete && \
    ln -s /usr/local/aws/bin/aws_bash_completer /etc/bash_completion.d/aws.sh

#
# AWS
#
ENV AWS_DATA_PATH=/localhost/.aws/ \
    AWS_CONFIG_FILE=/localhost/.aws/config \
    AWS_SHARED_CREDENTIALS_FILE=/localhost/.aws/credentials

COPY rootfs/ /

WORKDIR /conf

ENTRYPOINT ["/bin/bash"]
CMD ["-c", "bootstrap"]
