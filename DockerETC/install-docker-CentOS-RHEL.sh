#!/usr/bin/env bash
set -Eeuo pipefail
# 设置脚本执行时的严格模式，确保脚本在遇到错误时能够立即停止执行。

# ========== 配置区（按需改） ==========
TEST_DOMAIN="registry-1.docker.io"
DNS_BAD_PREFIX="198.18."   # 你之前遇到过的伪解析网段
# ====================================

# 彩色输出（可选）
RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; RST=$'\e[0m'

log()  { echo "${GRN}[INFO]${RST} $*"; }
warn() { echo "${YLW}[WARN]${RST} $*"; }
die()  { echo "${RED}[FAIL]${RST} $*"; exit 1; }

# 出错时打印行号 + 失败命令
on_err() {
  local code=$?
  die "脚本在第 ${BASH_LINENO[0]} 行失败：${BASH_COMMAND}（退出码 $code）"
}
trap on_err ERR
# 通过trap on_err ERR命令，可以确保脚本在任何命令出错时都会调用on_err函数，从而提高脚本的健壮性。

run() {
  # 用法：run "dnf -y install xxx"
  local cmd="$1"
  log "执行：$cmd"
  # shellcheck disable=SC2086
  eval "$cmd"
}

need_root() {
  [[ $EUID -eq 0 ]] || die "请用 root 运行：sudo $0"
}

detect_os() {
  log "系统信息："
  cat /etc/os-release || true
  command -v dnf >/dev/null 2>&1 || die "未找到 dnf（这不是 RHEL/CentOS 系？）"
}

check_network_dns() {
  log "检查网络与 DNS（避免装到一半才发现拉不下来）"

  # 1) 能否出网（IP 连通）
  if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    die "无法连通外网 IP（1.1.1.1）。请检查虚拟机网卡/NAT/网关。"
  fi

  # 2) 域名解析（重点）
  local resolved
  resolved="$(getent hosts "$TEST_DOMAIN" | awk 'NR==1{print $1}' || true)"
  if [[ -z "$resolved" ]]; then
    die "域名解析失败：$TEST_DOMAIN。请检查 /etc/resolv.conf 或 NetworkManager DNS。"
  fi

  if [[ "$resolved" == ${DNS_BAD_PREFIX}* ]]; then
    die "DNS 解析异常：$TEST_DOMAIN -> $resolved（疑似伪解析/劫持）。请先修复 DNS（例如改为 1.1.1.1/8.8.8.8）。"
  fi

  log "DNS 正常：$TEST_DOMAIN -> $resolved"
}

install_prereq() {
  log "安装依赖工具"
  run "dnf -y install dnf-plugins-core ca-certificates curl"
}

add_docker_repo() {
  log "添加 Docker 官方仓库"
  run "dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
}

install_docker() {
  log "安装 Docker Engine"
  # 安装常用组件：docker-ce + docker-ce-cli + containerd.io
  run "dnf -y install docker-ce docker-ce-cli containerd.io"
}

enable_start() {
  log "启动并设置开机自启"
  run "systemctl enable --now docker"
  run "docker version"
}

verify() {
  log "验证：拉取并运行 hello-world"
  run "docker pull hello-world"
  run "docker run --rm hello-world"
  log "Docker 安装验证通过 ✅"
}

main() {
  need_root
  detect_os
  check_network_dns
  install_prereq
  add_docker_repo
  install_docker
  enable_start
  verify
}

main "$@"
