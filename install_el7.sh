#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. DB_USER MUST be set as environment variable, for an example:
#
#        export DB_USER="admin"
#
# 2. DB_PWD MUST be set as environment variable, for an example:
#
#        export DB_PWD="passwords"
#
# 3. DB_HOST MUST be set as environment variable, for an example:
#
#        export DB_HOST="mysql-0.mysql"
#
# 4. REDIS_PWD MUST be set as environment variable, for an example:
#
#        export REDIS_PWD="passwords"
#
# 5. REDIS_HOST MUST be set as environment variable, for an example:
#
#        export REDIS_HOST="redis.redis"
#
# 6. INFINI_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export INFINI_CONTROLLER_NODE_NAMES=""

readonly NAMESPACE="infinilabs"
readonly CHART="infini-scale/infini-scale"
readonly RELEASE="infini-scale"
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

install_infini_scale() {
  # check if infini_scale already installed
  if helm status ${RELEASE} -n ${NAMESPACE} &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install redis, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set manager.mysql.username=''${DB_USER}'' \
    --set manager.mysql.password=''${DB_PWD}'' \
    --set manager.mysql.host="${DB_HOST}" \
    --set apiserver.redis.auth=''${REDIS_PWD}'' \
    --set apiserver.redis.host="${REDIS_HOST}" \
    --set apiserver.mysql.username=''${DB_USER}'' \
    --set apiserver.mysql.password=''${DB_PWD}'' \
    --set apiserver.mysql.host="${DB_HOST}" \
    --set apiserver.es.addr='1.1.1.1' \
    --set apiserver.es.pwd='pwd' \
    --set apiserver.es.user='user' \
    --set apiserver.console.addr='1.1.1.1 ' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add infini-scale "https://bsg-dbscale-helm.pkg.coding.net/infini-scale/charts" &>/dev/null
  info "Start update helm redis repo"
  if ! helm repo update 2>/dev/null; then
    error "Helm update redis repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${DB_USER}" ]]; then
    error "DB_USER MUST set in environment variable."
  fi

  if [[ -z "${DB_PWD}" ]]; then
    error "DB_PWD MUST set in environment variable."
  fi

  if [[ -z "${DB_HOST}" ]]; then
    error "DB_HOST MUST set in environment variable."
  fi

  if [[ -z "${REDIS_PWD}" ]]; then
    error "REDIS_PWD MUST set in environment variable."
  fi

  if [[ -z "${REDIS_HOST}" ]]; then
    error "REDIS_HOST MUST set in environment variable."
  fi

  if [[ -z "${INFINI_CONTROLLER_NODE_NAMES}" ]]; then
    error "INFINI_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local controller_node_array
  IFS="，" read -r -a controller_node_array <<<"${INFINI_CONTROLLER_NODE_NAMES}"
  for node in "${controller_node_array[@]}"; do
    kubectl label node "${node}" infinilabs-controller="" &>/dev/null || {
      error "kubectl label node ${node} infinilabs-controller= failed, use kubectl to check reason"
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
  INSTALL_LOG_PATH=/tmp/infini-scale_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  install_infini_scale
  verify_installed
}

main
