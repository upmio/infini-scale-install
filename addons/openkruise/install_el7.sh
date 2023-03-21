#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. KRUISE_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export KRUISE_CONTROLLER_NODE_NAMES="master01,master02"
#

readonly KRUISE_NS="kruise-system"
readonly KRUISE_VERSION="1.3.0"
readonly TIME_OUT_SECOND="600s"

INSTALL_LOG_PATH=""

info() {
  echo "[Info][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" | tee -a "${INSTALL_LOG_PATH}"
}

error() {
  echo "[Error][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" | tee -a "${INSTALL_LOG_PATH}"
  exit 1
}

install_kubectl() {
  info "Install kubectl..."
  if ! curl -LOs "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; then
    error "Fail to get kubectl, please confirm whether the connection to dl.k8s.io is ok?"
  fi
  if ! sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; then
    error "Install kubectl fail"
  fi
  info "Kubectl install completed"
}

install_helm() {
  info "Install helm..."
  if ! curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3; then
    error "Fail to get helm installed script, please confirm whether the connection to raw.githubusercontent.com is ok?"
  fi
  chmod 700 get_helm.sh
  if ! ./get_helm.sh; then
    error "Fail to get helm when running get_helm.sh"
  fi
  info "Helm install completed"
}

install_kruise() {
  local release="kruise"
  # check if kruise already installed
  if helm status ${release} -n ${KRUISE_NS} &>/dev/null; then
    error "${release} already installed. Use helm remove it first"
  fi
  info "Install ${release}, It might take a long time..."
  helm install ${release} openkruise/kruise --version "${KRUISE_VERSION}" \
    --debug \
    --namespace ${KRUISE_NS} \
    --create-namespace \
    --set installation.namespace=${KRUISE_NS} \
    --set installation.createNamespace=true \
    --set manager.replicas="${KRUISE_CONTROLLER_NODE_COUNT}" \
    --set manager.nodeSelector."openkruise\.io/control-plane"="enable" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${release}."
  }

  #TODO: check more resources after install

  helm status "${release}" -n "${KRUISE_NS}" | grep deployed &>/dev/null || {
    error "${release} installed fail, check log use helm and kubectl."
  }

  info "${release} Deployment Completed!"
}

init_helm_repo() {
  helm repo add openkruise https://openkruise.github.io/charts/ &>/dev/null
  info "Start update helm kruise repo"
  if ! helm repo update 2>/dev/null; then
    error "Helm update kruise repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${KRUISE_CONTROLLER_NODE_NAMES}" ]]; then
    error "KRUISE_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local control_node_array
  IFS="," read -r -a control_node_array <<<"${KRUISE_CONTROLLER_NODE_NAMES}"
  KRUISE_CONTROLLER_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'kruise.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'kruise.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((KRUISE_CONTROLLER_NODE_COUNT++))
  done

  if [[ "${HAS_CURL}" != "true" ]]; then
    error "curl is required"
  fi

  if [[ "${HAS_HELM}" != "true" ]]; then
    install_helm
  fi

  if [[ "${HAS_KUBECTL}" != "true" ]]; then
    install_kubectl
  fi
}

init_log() {
  INSTALL_LOG_PATH=/tmp/kruise_install-$(date +'%Y-%m-%d_%H-%M-%S').log
  if ! touch "${INSTALL_LOG_PATH}"; then
    error "Create log file ${INSTALL_LOG_PATH} error"
  fi
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_kruise
}

main
