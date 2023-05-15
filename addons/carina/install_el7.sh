#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CARINA_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CARINA_CONTROLLER_NODE_NAMES="master01,master02"
#
# 2. CARINA_DATA_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CARINA_DATA_NODE_NAMES="node01,node02"
#
# 3. CARINA_SSD_DEV_NAMES MUST be set as environment variable, for an example:
#
#        export CARINA_SSD_DEV_NAMES="/dev/sde,/dev/sdf"
#
# 4. CARINA_HDD_DEV_NAMES MUST be set as environment variable, for an example:
#
#        export CARINA_HDD_DEV_NAMES="/dev/sdb,/dev/sdc"
#

readonly NAMESPACE="kube-system"
readonly CHART="carina-csi-driver/carina-csi-driver"
readonly RELEASE="carina-csi-driver"
readonly TIME_OUT_SECOND="600s"
readonly FS_TYPE="xfs"
readonly NODE_KUBELET="/var/lib/kubelet"
readonly SSD_VG_NAME="carina-ssd-vg"
readonly HDD_VG_NAME="carina-hdd-vg"

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

install_carina() {
  # check if carina already installed
  if helm status ${RELEASE} -n ${NAMESPACE} &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install carina, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set controller.replicas=${CONTROLLER_NODE_COUNT} \
    --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key='carina.io/control-plane' \
    --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator='In' \
    --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values={enable} \
    --set node.kubelet="${NODE_KUBELET}" \
    --set node.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key='carina.io/node' \
    --set node.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator="In" \
    --set node.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values={enable} \
    --set config.diskScanInterval=300 \
    --set config.diskSelector[0].name="${SSD_VG_NAME}" \
    --set config.diskSelector[0].re={${CARINA_SSD_DEV_NAMES}} \
    --set config.diskSelector[0].policy="LVM" \
    --set config.diskSelector[1].name="${HDD_VG_NAME}" \
    --set config.diskSelector[1].re={${CARINA_HDD_DEV_NAMES}} \
    --set config.diskSelector[1].policy="LVM" \
    --set storage.StorageClass[0].disktype="${SSD_VG_NAME}" \
    --set storage.StorageClass[0].fstype="${FS_TYPE}" \
    --set storage.StorageClass[1].disktype="${HDD_VG_NAME}" \
    --set storage.StorageClass[1].fstype="${FS_TYPE}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add carina-csi-driver https://raw.githubusercontent.com/carina-io/charts/main &>/dev/null
  info "Start update helm carina-csi-driver repo"
  if ! helm repo update carina-csi-driver 2>/dev/null; then
    error "Helm update carina carina-csi-driver error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${CARINA_CONTROLLER_NODE_NAMES}" ]]; then
    error "CARINA_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local control_node_array
  IFS="," read -r -a control_node_array <<<"${CARINA_CONTROLLER_NODE_NAMES}"
  CONTROLLER_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'carina.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'carina.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CONTROLLER_NODE_COUNT++))
  done

  if [[ -z "${CARINA_DATA_NODE_NAMES}" ]]; then
    error "CARINA_DATA_NODE_NAMES MUST set in environment variable."
  fi

  local data_node_array
  IFS="," read -r -a data_node_array <<<"${CARINA_DATA_NODE_NAMES}"
  for node in "${data_node_array[@]}"; do
    kubectl label node "${node}" 'carina.io/node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'carina.io/node=enable' failed, use kubectl to check reason"
    }
  done

  if [[ -z "${CARINA_SSD_DEV_NAMES}" ]]; then
    error "CARINA_SSD_DEV_NAMES MUST set in environment variable."
  fi

  if [[ -z "${CARINA_HDD_DEV_NAMES}" ]]; then
    error "CARINA_HDD_DEV_NAMES MUST set in environment variable."
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
  INSTALL_LOG_PATH=/tmp/carina_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  install_carina
  verify_installed
}

main
