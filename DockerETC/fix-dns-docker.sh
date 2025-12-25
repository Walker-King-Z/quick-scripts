#!/usr/bin/env bash
set -euo pipefail

# ================== 参数处理 ==================
MODE="apply"
if [[ "${1:-}" == "--rollback" ]]; then
  MODE="rollback"
fi

# ================== 可配置 DNS ==================
DNS4_PRIMARY="1.1.1.1"
DNS4_SECONDARY="8.8.8.8"
DNS6_PRIMARY="2606:4700:4700::1111"
DNS6_SECONDARY="2001:4860:4860::8888"

TEST_DOMAIN="registry-1.docker.io"
BK_DIR="/root/nm-backup"

# ================== 工具检查 ==================
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "❌ 缺少命令：$1"; exit 1; }; }
need_cmd nmcli
need_cmd systemctl
need_cmd getent
need_cmd ip

if [[ $EUID -ne 0 ]]; then
  echo "❌ 请用 root 运行：sudo $0"
  exit 1
fi

# ================== 找默认路由对应连接 ==================
DEFAULT_DEV="$(ip route show default | awk 'NR==1{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
[[ -z "$DEFAULT_DEV" ]] && { echo "❌ 未找到默认路由网卡"; exit 1; }

CONN_NAME="$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v dev="$DEFAULT_DEV" '$2==dev{print $1; exit}')"
[[ -z "$CONN_NAME" ]] && { echo "❌ 未找到与 $DEFAULT_DEV 对应的 NetworkManager 连接"; exit 1; }

echo "➡️  当前连接：$CONN_NAME （设备：$DEFAULT_DEV）"

# ================== 回滚模式 ==================
if [[ "$MODE" == "rollback" ]]; then
  echo "==> 回滚模式：恢复最近一次 NetworkManager 备份"

  [[ ! -d "$BK_DIR" ]] && { echo "❌ 未找到备份目录 $BK_DIR"; exit 1; }

  LAST_BK="$(ls -1t "$BK_DIR"/"${CONN_NAME}".before.* 2>/dev/null | head -n1 || true)"
  [[ -z "$LAST_BK" ]] && { echo "❌ 未找到 $CONN_NAME 的备份文件"; exit 1; }

  echo "➡️  使用备份文件：$LAST_BK"
  echo "⚠️  请注意：NetworkManager 无法直接导入 show 输出"
  echo "➡️  将仅恢复 DNS 相关设置为“自动获取”"

  nmcli con mod "$CONN_NAME" ipv4.ignore-auto-dns no
  nmcli con mod "$CONN_NAME" ipv6.ignore-auto-dns no
  nmcli con mod "$CONN_NAME" ipv4.dns ""
  nmcli con mod "$CONN_NAME" ipv6.dns ""

  nmcli con down "$CONN_NAME" || true
  nmcli con up "$CONN_NAME"

  echo "✅ 回滚完成（DNS 已交还 DHCP）"
  exit 0
fi

# ================== 应用模式 ==================
echo "==> 应用模式：驯服 NetworkManager + Docker DNS"

echo "==> 1) 备份当前连接配置"
mkdir -p "$BK_DIR"
nmcli con show "$CONN_NAME" > "$BK_DIR/${CONN_NAME}.before.$(date +%F_%H%M%S).txt"

echo "==> 2) 固定 NetworkManager DNS（忽略 DHCP DNS）"
nmcli con mod "$CONN_NAME" ipv4.ignore-auto-dns yes
nmcli con mod "$CONN_NAME" ipv4.dns "$DNS4_PRIMARY $DNS4_SECONDARY"

nmcli con mod "$CONN_NAME" ipv6.ignore-auto-dns yes || true
nmcli con mod "$CONN_NAME" ipv6.dns "$DNS6_PRIMARY $DNS6_SECONDARY" || true

echo "==> 3) 重新激活连接（短暂断网正常）"
nmcli con down "$CONN_NAME" || true
nmcli con up "$CONN_NAME"

echo "==> 4) 配置 Docker daemon DNS"
mkdir -p /etc/docker
[[ -f /etc/docker/daemon.json ]] && cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%F_%H%M%S)"

cat >/etc/docker/daemon.json <<EOF
{
  "dns": ["$DNS4_PRIMARY", "$DNS4_SECONDARY"]
}
EOF

systemctl restart docker

echo "==> 5) 验证解析结果"
getent hosts "$TEST_DOMAIN" || true

if getent hosts "$TEST_DOMAIN" | grep -qE '^198\.18\.'; then
  echo "❌ 仍解析到 198.18.*，可能存在内网 DNS 劫持"
  exit 2
fi

echo "✅ DNS 驯服完成"
echo "👉 下一步验证："
echo "   docker pull hello-world"
echo "   docker run --rm hello-world"
