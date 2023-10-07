#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. MYSQL_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export MYSQL_STORAGECLASS_NAME=""
#
# 2. MYSQL_PVC_SIZE_G MUST be set as environment variable, for an example:
#
#        export MYSQL_PVC_SIZE_G="50"
#
# 3. MYSQL_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export MYSQL_NODE_NAMES="kube-node01"

readonly NAMESPACE="nacos"
readonly CHART="helm-nacos/nacos"
readonly RELEASE="nacos"
readonly TIME_OUT_SECOND="600s"
readonly RESOURCE_LIMITS_CPU="2"
readonly RESOURCE_LIMITS_MEMORY="4Gi"
readonly RESOURCE_REQUESTS_CPU="2"
readonly RESOURCE_REQUESTS_MEMORY="4Gi"

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

install_nacos() {
  info "Install mysql, It might take a long time..."

#helm install <release-name> <chart-name> --set replicaCount=3 --set service.type=NodePort --set service.ingressPort=8848 --set service.ports.http.port=8848 --set service.ports.http.nodePort=30031 --set podSecurityContext.enabled=true --set containerSecurityContext.enabled=true --set persistentVolume.enabled=true --set persistentVolume.storageClass="openebs-lvmsc-hdd" --set persistentVolume.accessMode="ReadWriteOnce" --set persistentVolume.size=10Gi --set mysql.enabled=true --set mysql.architecture="standalone" --set mysql.auth.rootPassword="nacos" --set mysql.auth.database="nacos" --set mysql.auth.username="nacos" --set mysql.auth.password="nacos123456"

  helm install ${RELEASE} helm-nacos/nacos \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --version '2.1.4' \
    --set image.debug=true \
    --set replicaCount=1 \
    --set service.type="ClusterIP" \
    --set service.ingressPort=8848 \
    --set service.ports.http.port=8848 \
    --set service.ports.http.protocol="TCP" \
    --set service.ports.client\-rpc.port=9848 \
    --set service.ports.raft\-rpc.port=9849 \
    --set mysql.enabled=true \
    --set mysql.architecture="standalone" \
    --set mysql.auth.rootPassword="nacos" \
    --set mysql.auth.database="nacos" \
    --set mysql.auth.username="nacos" \
    --set mysql.auth.password="nacos123456" \
    --set primary.resources.limits.cpu=''${RESOURCE_LIMITS_CPU}'' \
    --set primary.resources.limits.memory=''${RESOURCE_LIMITS_MEMORY}'' \
    --set primary.resources.requests.cpu=''${RESOURCE_REQUESTS_CPU}'' \
    --set primary.resources.requests.memory=''${RESOURCE_REQUESTS_MEMORY}'' \
    --set primary.persistence.storageClass=''"${MYSQL_STORAGECLASS_NAME}"'' \
    --set primary.persistence.size=''"${MYSQL_PVC_SIZE_G}Gi"'' \
    --set primary.nodeAffinityPreset.type="hard" \
    --set primary.nodeAffinityPreset.key="mysql\.standalone\.node" \
    --set primary.nodeAffinityPreset.values='{enable}' \
    --set primary.podSecurityContext.fsGroup=1001 \
    --set primary.containerSecurityContext.runAsUser=1001 \
    --set primary.containerSecurityContext.runAsNonRoot=true \
    --set ingress.enabled=false \
    --timeout $TIME_OUT_SECOND 
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
    }
  #TODO: check more resources after install
}

init_helm_repo() {
  info "Start add helm helm-nacos repo"
  helm repo add helm-nacos https://smoothies.com.cn/helm-nacos/ &>/dev/null || {
    error "Helm add helm-nacos repo error."
  }

  info "Start update helm helm-nacos repo"
  helm repo update helm-nacos 2>/dev/null || {
    error "Helm update helm-nacos repo error."
  }
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"


  if [[ -z "${MYSQL_NODE_NAMES}" ]]; then
    error "DB_NODE_NAMES MUST set in environment variable."
  fi

  local db_node_array
  IFS="," read -r -a db_node_array <<<"${MYSQL_NODE_NAMES}"
  for node in "${db_node_array[@]}"; do
    kubectl label node "${node}" 'mysql.standalone.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'mysql.standalone.node=enable' failed, use kubectl to check reason"
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
  INSTALL_LOG_PATH=/tmp/mysql_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  install_nacos
  verify_installed
}

main
