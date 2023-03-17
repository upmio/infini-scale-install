#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CLUSTERNET_PARENT_URL MUST be set as environment variable, for an example:
#
#        export CLUSTERNET_PARENT_URL="https://xxxx:6443"
#
# 2. CLUSTERNET_REGISTRATION_TOKEN MUST be set as environment variable, for an example:
#
#        export CLUSTERNET_REGISTRATION_TOKEN="xxxxxx.xxxxxxxxxxxxxx"
#
# 3. CLUSTERNET_AGENT_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CLUSTERNET_AGENT_NODE_NAMES="clusternet-agent01"
#
# 4. CLUSTERNET_REG_NAME MUST be set as environment variable, for an example:
#
#        export CLUSTERNET_REG_NAME="mycluster"
#
# 5. CLUSTERNET_REG_NAMESPACE MUST be set as environment variable, for an example:
#
#        export CLUSTERNET_REG_NAMESPACE="mycluster-ns"
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

install_clusternet_agent() {
  local release="clusternet-agent"
  # check if clusternet-hub already installed
  if helm status ${release} -n ${NAMESPACE} &>/dev/null; then
    error "${release} already installed. Use helm remove it first"
  fi
  info "Install ${release}, It might take a long time..."
  helm install ${release} clusternet/clusternet-agent \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set parentURL="${CLUSTERNET_PARENT_URL}" \
    --set registrationToken="${CLUSTERNET_REGISTRATION_TOKEN}" \
    --set replicaCount="${CLUSTERNET_AGENT_NODE_COUNT}" \
    --set extraArgs.cluster-reg-name="${CLUSTERNET_REG_NAME}" \
    --set extraArgs.cluster-reg-namespace="${CLUSTERNET_REG_NAMESPACE}" \
    --set nodeSelector."clusternet\.io/agent"="enable" \
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

  if [[ -z "${CLUSTERNET_PARENT_URL}" ]]; then
    error "CLUSTERNET_PARENT_URL MUST set in environment variable."
  fi

  if [[ -z "${CLUSTERNET_REGISTRATION_TOKEN}" ]]; then
    error "CLUSTERNET_REGISTRATION_TOKEN MUST set in environment variable."
  fi

  if [[ -z "${CLUSTERNET_AGENT_NODE_NAMES}" ]]; then
    error "CLUSTERNET_AGENT_NODE_NAMES MUST set in environment variable."
  fi
  local control_node_array
  IFS="," read -r -a control_node_array <<<"${CLUSTERNET_AGENT_NODE_NAMES}"
  CLUSTERNET_AGENT_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'clusternet.io/agent=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'clusternet.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CLUSTERNET_AGENT_NODE_COUNT++))
  done

  # 检查变量 CLUSTERNET_REG_NAME 不能为空
  if [[ -z "${CLUSTERNET_REG_NAME}" ]]; then
    error "CLUSTERNET_REG_NAME MUST set in environment variable."
  fi

  # 检查变量 CLUSTERNET_REG_NAME 的值不能包含 . _
  if [[ "${CLUSTERNET_REG_NAME}" =~ [._] ]]; then
    error "CLUSTERNET_REG_NAME MUST NOT contain . or _"
  fi

  # 检查变量 CLUSTERNET_REG_NAMESPACE 不能为空
  if [[ -z "${CLUSTERNET_REG_NAMESPACE}" ]]; then
    error "CLUSTERNET_REG_NAMESPACE MUST set in environment variable."
  fi

  # 检查变量 CLUSTERNET_REG_NAMESPACE 的值不能包含 . _
  if [[ "${CLUSTERNET_REG_NAMESPACE}" =~ [._] ]]; then
    error "CLUSTERNET_REG_NAMESPACE MUST NOT contain . or _"
  fi

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
  install_clusternet_agent
}

main
