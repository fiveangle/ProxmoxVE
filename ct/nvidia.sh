#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: fiveangle
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://immich.app

APP="nvidia"
var_tags="${var_tags:-gpu,media}"
var_disk="${var_disk:-20}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
var_gpu="${var_gpu:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  $STD apt install --no-install-recommends curl gnupg2

  if [[ ! -f /usr/bin/nvidia-persistenced ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  if [[ ! -f /etc/apt/sources.list.d/non-free.sources ]]; then
      msg_error "Adding Debian 13 non-free and non-free-firmware repos"
      cat <<'EOF' >/etc/apt/sources.list.d/non-free.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: non-free non-free-firmware

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: trixie-security
Components: non-free non-free-firmware
EOF
  fi
  if [[ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]]; then
    msg_info "Adding Nvidia Container Toolkit repo"
    msg_info "Install to support GPU/ML inside docker containers."
    msg_info "Install to support GPU/ML inside docker containers."
    if [[ ! -f /etc/apt/preferences.d/nvidia-container-toolkit.list ]]; then
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |  \
      gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg  && \
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |  \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |  \
      tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    fi
    $STD apt update
    msg_ok "Added dependancies repos"
    msg_info "Installing Nvidia graphics and CUDA libraries"
    $STD apt install --no-install-recommends lshw menu libcuda1 nvtop nvidia-driver-libs  
   

    msg_ok "Installed Nvidia graphics and CUDA libraries"
  fi
  STAGING_DIR=/opt/staging
  BASE_DIR=${STAGING_DIR}/base-images
  SOURCE_DIR=${STAGING_DIR}/image-source
  cd /tmp
  if [[ -f ~/.intel_version ]]; then
    curl -fsSLO https://raw.githubusercontent.com/immich-app/base-images/refs/heads/main/server/Dockerfile
    readarray -t INTEL_URLS < <(
      sed -n "/intel-[igc|opencl]/p" ./Dockerfile | awk '{print $2}'
      sed -n "/libigdgmm12/p" ./Dockerfile | awk '{print $3}'
    )
    INTEL_RELEASE="$(grep "intel-opencl-icd_" ./Dockerfile | awk -F '_' '{print $2}')"
    if [[ "$INTEL_RELEASE" != "$(cat ~/.intel_version)" ]]; then
      msg_info "Updating Intel iGPU dependencies"
      for url in "${INTEL_URLS[@]}"; do
        curl -fsSLO "$url"
      done
      $STD apt-mark unhold libigdgmm12
      $STD apt install -y ./libigdgmm12*.deb
      rm ./libigdgmm12*.deb
      $STD apt install -y ./*.deb
      rm ./*.deb
      $STD apt-mark hold libigdgmm12
      msg_ok "Intel iGPU dependencies updated"
    fi
    rm ./Dockerfile
  fi
  RELEASE="555.135"
  if check_for_gh_release "nvidia" "nvidia-lxc/nvidia" "${RELEASE}"; then
    msg_err "Not upgradable!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following IP:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}${IP}${CL}"
