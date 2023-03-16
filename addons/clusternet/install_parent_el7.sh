#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CLUSTERNET_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CLUSTERNET_CONTROLLER_NODE_NAMES="master01,master02"
#

readonly NAMESPACE="clusternet-system"
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

install_clusternet_hub() {
  local release="clusternet-hub"
  # check if clusternet-hub already installed
  if helm status ${release} -n ${NAMESPACE} &>/dev/null; then
    error "${release} already installed. Use helm remove it first"
  fi
  info "Install ${release}, It might take a long time..."
  helm install ${release} clusternet/clusternet-hub \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set replicaCount="${CONTROLLER_NODE_COUNT}" \
    --set nodeSelector."clusternet\.io/control-plane"="enable" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${release}."
  }

  #TODO: check more resources after install

  helm status "${release}" -n "${NAMESPACE}" | grep deployed &>/dev/null || {
    error "${release} installed fail, check log use helm and kubectl."
  }

  info "${release} Deployment Completed!"
}

install_clusternet_scheduler() {
  local release="clusternet-scheduler"
  # check if clusternet-scheduler already installed
  if helm status ${release} -n ${NAMESPACE} &>/dev/null; then
    error "${release} already installed. Use helm remove it first"
  fi
  info "Install ${release}, It might take a long time..."
  helm install ${release} clusternet/clusternet-scheduler \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set replicaCount=${CLUSTERNET_CONTROLLER_NODE_COUNT} \
    --set nodeSelector."clusternet\.io/control-plane"="enable" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${release}."
  }

  #TODO: check more resources after install

  helm status "${release}" -n "${NAMESPACE}" | grep deployed &>/dev/null || {
    error "${release} installed fail, check log use helm and kubectl."
  }

  info "${release} Deployment Completed!"
}

create_token() {
  local token_id
  token_id="$(head /dev/urandom | cksum | md5sum | cut -c 1-6)"
  local token_secret
  token_secret="$(head /dev/urandom | cksum | md5sum | cut -c 1-16)"

  export token_id
  export token_secret
  curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/clusternet/yaml/cluster_bootstrap_token.yaml | envsubst | kubectl apply -f - || {
    error "kubectl create token secret fail, check log use kubectl."
  }

  info "token Created!"
  info "registrationToken=${token_id}.${token_secret}. PLEASE REMEMBER THIS."
}

init_helm_repo() {
  helm repo add clusternet https://clusternet.github.io/charts &>/dev/null
  info "Start update helm clusternet repo"
  if ! helm repo update 2>/dev/null; then
    error "Helm update clusternet repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${CLUSTERNET_CONTROLLER_NODE_NAMES}" ]]; then
    error "CLUSTERNET_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local control_node_array
  IFS="," read -r -a control_node_array <<<"${CLUSTERNET_CONTROLLER_NODE_NAMES}"
  CLUSTERNET_CONTROLLER_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'clusternet.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'clusternet.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CLUSTERNET_CONTROLLER_NODE_COUNT++))
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
  INSTALL_LOG_PATH=/tmp/clusternet_install-$(date +'%Y-%m-%d_%H-%M-%S').log
  if ! touch "${INSTALL_LOG_PATH}"; then
    error "Create log file ${INSTALL_LOG_PATH} error"
  fi
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_clusternet_hub
  install_clusternet_scheduler
  create_token
}

main
