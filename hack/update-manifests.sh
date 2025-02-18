#! /usr/bin/env bash
set -x
set -o errexit
set -o nounset
set -o pipefail

SRCROOT="$(git rev-parse --show-toplevel)"
AUTOGENMSG="# This is an auto-generated file. DO NOT EDIT"

KUSTOMIZE=kustomize
[ -f "$SRCROOT/dist/kustomize" ] && KUSTOMIZE="$SRCROOT/dist/kustomize"

cd ${SRCROOT}/manifests/ha/base/redis-ha && ./generate.sh

IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-quay.io/argoproj}"
RELEASE_VERSION=v$(cat $SRCROOT/VERSION)
IMAGE_TAG="${IMAGE_TAG:-$RELEASE_VERSION}"

$KUSTOMIZE version
which $KUSTOMIZE

cd ${SRCROOT}/manifests/base && $KUSTOMIZE edit set image quay.io/argoproj/argocd=${IMAGE_NAMESPACE}/argocd:${IMAGE_TAG}
cd ${SRCROOT}/manifests/ha/base && $KUSTOMIZE edit set image quay.io/argoproj/argocd=${IMAGE_NAMESPACE}/argocd:${IMAGE_TAG}
cd ${SRCROOT}/manifests/core-install && $KUSTOMIZE edit set image quay.io/argoproj/argocd=${IMAGE_NAMESPACE}/argocd:${IMAGE_TAG}

echo "${AUTOGENMSG}" > "${SRCROOT}/manifests/install.yaml"
$KUSTOMIZE build "${SRCROOT}/manifests/cluster-install" >> "${SRCROOT}/manifests/install.yaml"

echo "${AUTOGENMSG}" > "${SRCROOT}/manifests/namespace-install.yaml"
$KUSTOMIZE build "${SRCROOT}/manifests/namespace-install" >> "${SRCROOT}/manifests/namespace-install.yaml"

echo "${AUTOGENMSG}" > "${SRCROOT}/manifests/ha/install.yaml"
$KUSTOMIZE build "${SRCROOT}/manifests/ha/cluster-install" >> "${SRCROOT}/manifests/ha/install.yaml"

echo "${AUTOGENMSG}" > "${SRCROOT}/manifests/ha/namespace-install.yaml"
$KUSTOMIZE build "${SRCROOT}/manifests/ha/namespace-install" >> "${SRCROOT}/manifests/ha/namespace-install.yaml"

echo "${AUTOGENMSG}" > "${SRCROOT}/manifests/core-install.yaml"
$KUSTOMIZE build "${SRCROOT}/manifests/core-install" >> "${SRCROOT}/manifests/core-install.yaml"
