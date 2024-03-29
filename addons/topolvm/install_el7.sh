#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. TOPOLVM_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export TOPOLVM_CONTROLLER_NODE_NAMES="master01,master02"
#
# 2. TOPOLVM_DATA_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export TOPOLVM_DATA_NODE_NAMES="node01,node02"
#
# 3. TOPOLVM_VG_NAME MUST be set as environment variable, for an example:
#
#        export TOPOLVM_VG_NAME="local_HDD_VG"
#
# 4. TOPOLVM_DEVICE_CLASSES_NAME MUST be set as environment variable, for an example:
#
#        export TOPOLVM_DEVICE_CLASSES_NAME="hdd"
#

readonly NAMESPACE="topolvm-system"
readonly CHART="topolvm/topolvm"
readonly RELEASE="topolvm"
readonly TIME_OUT_SECOND="600s"
readonly FS_TYPE="xfs"

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

install_topolvm() {
  # check if topolvm already installed
  if helm status ${RELEASE} -n ${NAMESPACE} &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install topolvm, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set controller.replicaCount=${CONTROLLER_NODE_COUNT} \
    --set controller.nodeSelector."topolvm\.io/control-plane"="enable" \
    --set controller.storageCapacityTracking.enabled=true \
    --set scheduler.enabled=false \
    --set webhook.podMutatingWebhook.enabled=false \
    --set lvmd.deviceClasses[0].name="${TOPOLVM_DEVICE_CLASSES_NAME}" \
    --set lvmd.deviceClasses[0].volume-group="${TOPOLVM_VG_NAME}" \
    --set lvmd.deviceClasses[0].default=true \
    --set lvmd.deviceClasses[0].spare-gb=10 \
    --set lvmd.nodeSelector."topolvm\.io/node"="enable" \
    --set node.nodeSelector."topolvm\.io/node"="enable" \
    --set podSecurityPolicy.create=false \
    --set storageClasses[0].name="topolvm-provisioner-${TOPOLVM_DEVICE_CLASSES_NAME}" \
    --set storageClasses[0].storageClass.fsType="${FS_TYPE}" \
    --set storageClasses[0].storageClass.additionalParameters."topolvm\.io/device-class"="${TOPOLVM_DEVICE_CLASSES_NAME}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add topolvm https://topolvm.github.io/topolvm &>/dev/null
  info "Start update helm topolvm repo"
  if ! helm repo update topolvm 2>/dev/null; then
    error "Helm update topolvm repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  kubectl create namespace ${NAMESPACE}

  kubectl label namespace ${NAMESPACE} topolvm.io/webhook=ignore &>/dev/null || {
    error "kubectl label namespace ${NAMESPACE} failed, use kubectl to check reason"
  }

  kubectl label namespace kube-system topolvm.io/webhook=ignore || {
    error "kubectl label namespace kube-system failed, use kubectl  to check reason"
  }

  if [[ -z "${TOPOLVM_VG_NAME}" ]]; then
    error "TOPOLVM_VG_NAME MUST set in environment variable."
  fi

  if [[ -z "${TOPOLVM_DEVICE_CLASSES_NAME}" ]]; then
    error "TOPOLVM_DEVICE_CLASSES_NAME MUST set in environment variable."
  fi

  if [[ -z "${TOPOLVM_CONTROLLER_NODE_NAMES}" ]]; then
    error "TOPOLVM_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local control_node_array
  IFS="," read -r -a control_node_array <<<"${TOPOLVM_CONTROLLER_NODE_NAMES}"
  CONTROLLER_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'topolvm.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'topolvm.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CONTROLLER_NODE_COUNT++))
  done

  if [[ -z "${TOPOLVM_DATA_NODE_NAMES}" ]]; then
    error "TOPOLVM_DATA_NODE_NAMES MUST set in environment variable."
  fi

  local data_node_array
  IFS="," read -r -a data_node_array <<<"${TOPOLVM_DATA_NODE_NAMES}"
  for node in "${data_node_array[@]}"; do
    kubectl label node "${node}" 'topolvm.io/node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'topolvm.io/node=enable' failed, use kubectl to check reason"
    }
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
  INSTALL_LOG_PATH=/tmp/topolvm_install-$(date +'%Y-%m-%d_%H-%M-%S').log
  if ! touch "${INSTALL_LOG_PATH}"; then
    error "Create log file ${INSTALL_LOG_PATH} error"
  fi
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

############################################
# Check if helm release deployment correctly
# Arguments:
#   release
#   namespace
############################################
verify_installed() {
  helm status "${RELEASE}" -n "${NAMESPACE}" | grep deployed &>/dev/null || {
    error "${RELEASE} installed fail, check log use helm and kubectl."
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_topolvm
  verify_installed
}

main
