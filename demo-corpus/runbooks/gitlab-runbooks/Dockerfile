ARG GL_ASDF_AMTOOL_VERSION
ARG GL_ASDF_GO_JSONNET_VERSION
ARG GL_ASDF_JB_VERSION
ARG GL_ASDF_JSONNET_TOOL_VERSION
ARG GL_ASDF_RUBY_VERSION
ARG GL_ASDF_TERRAFORM_VERSION
ARG GL_ASDF_VAULT_VERSION
ARG GL_ASDF_YQ_VERSION
ARG GL_ASDF_GOLANG_VERSION
ARG GL_ASDF_ORAS_VERSION

# renovate: datasource=github-releases depName=grafana/mimir
ARG MIMIRTOOL_VERSION=3.0.5

# Referenced container images
FROM docker.io/mikefarah/yq:${GL_ASDF_YQ_VERSION} AS yq
FROM ghcr.io/oras-project/oras:v${GL_ASDF_ORAS_VERSION} as oras
FROM grafana/mimirtool:${MIMIRTOOL_VERSION} AS mimirtool
FROM hashicorp/terraform:${GL_ASDF_TERRAFORM_VERSION} AS terraform
FROM hashicorp/vault:${GL_ASDF_VAULT_VERSION} AS vault
FROM quay.io/prometheus/alertmanager:v${GL_ASDF_AMTOOL_VERSION} AS amtool
FROM registry.gitlab.com/gitlab-com/gl-infra/jsonnet-tool:v${GL_ASDF_JSONNET_TOOL_VERSION} AS jsonnet-tool
FROM registry.gitlab.com/gitlab-com/gl-infra/common-ci-tasks-images/go-jsonnet:v${GL_ASDF_GO_JSONNET_VERSION} AS go-jsonnet
FROM registry.gitlab.com/gitlab-com/gl-infra/common-ci-tasks-images/jb:v${GL_ASDF_JB_VERSION} AS jb
# There is no official mixtool Docker image from the author, so we need to create one
FROM golang:${GL_ASDF_GOLANG_VERSION}-alpine AS mixtool

RUN go install github.com/monitoring-mixins/mixtool/cmd/mixtool@main

# Main stage build
FROM ruby:${GL_ASDF_RUBY_VERSION}-alpine

ARG GL_ASDF_KUBECONFORM_VERSION
ARG GL_ASDF_KUBECTL_VERSION

RUN apk add --no-cache \
  python3 curl bash build-base git jq make \
  openssl tar yamllint zlib npm \
  parallel coreutils

ENV PATH=$PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Download and install gcloud
RUN  curl --silent -o /tmp/google-cloud-sdk.tar.gz -L --fail  https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz \
  && mkdir -p /usr/local/gcloud \
  && tar -C /usr/local/gcloud -xf /tmp/google-cloud-sdk.tar.gz \
  && rm /tmp/google-cloud-sdk.tar.gz \
  && /usr/local/gcloud/google-cloud-sdk/install.sh

# Install kubectl
RUN  curl --silent --fail --show-error -L -o /bin/kubectl https://dl.k8s.io/release/v${GL_ASDF_KUBECTL_VERSION}/bin/linux/amd64/kubectl \
  && kubectl_sha256sum="$(curl --silent --fail --show-error -L https://dl.k8s.io/release/v${GL_ASDF_KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256)" \
  && echo "${kubectl_sha256sum}  /bin/kubectl" | sha256sum -c \
  && chmod +x /bin/kubectl

# Install kubeconform
RUN  curl --silent --fail --show-error -L https://github.com/yannh/kubeconform/releases/download/v${GL_ASDF_KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz | tar xvz --exclude "LICENSE" -C /usr/local/bin/ \
  && chmod +x /usr/local/bin/kubeconform

# Install binary tools
COPY --from=amtool /bin/amtool /bin/amtool
COPY --from=go-jsonnet /usr/bin/jsonnet /bin/jsonnet
COPY --from=go-jsonnet /usr/bin/jsonnetfmt /bin/jsonnetfmt
COPY --from=go-jsonnet /usr/bin/jsonnet-deps /bin/jsonnet-deps
COPY --from=go-jsonnet /usr/bin/jsonnet-lint /bin/jsonnet-lint
COPY --from=jb /usr/bin/jb /bin/jb
COPY --from=jsonnet-tool /usr/local/bin/jsonnet-tool /bin/jsonnet-tool
COPY --from=terraform /bin/terraform /bin/terraform
COPY --from=vault /bin/vault /bin/vault
COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY --from=mimirtool /bin/mimirtool /bin/mimirtool
COPY --from=mixtool /go/bin/mixtool /bin/mixtool
COPY --from=oras /bin/oras /bin/oras

# Ship jsonnet dependencies as a part of this image
RUN mkdir /jsonnet-deps
COPY jsonnetfile.json /jsonnet-deps
COPY jsonnetfile.lock.json /jsonnet-deps
RUN cd /jsonnet-deps && jb install
ENV JSONNET_VENDOR_DIR=/jsonnet-deps/vendor

ENTRYPOINT ["/bin/sh", "-c"]
