#!/bin/bash

# =================================================================
# 脚本名称: hfs_upload.sh
# 描述: 专为 HFS 设计的无痕上传脚本 (适用于 Cloudflare Tunnel 场景)
# =================================================================

# 1. 交互式获取域名
read -p "请输入 HFS 域名 (例如: hfs.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "错误: 域名不能为空！"
    exit 1
fi

# 格式化域名：去除开头可能的 http(s):// 和结尾的 /
DOMAIN=$(echo $DOMAIN | sed -e 's|^http://||' -e 's|^https://||' -e 's|/$||')

# 2. 交互式获取文件路径
# 支持直接拖入文件获取路径，或手动输入
read -p "请输入要上传的文件本地路径: " FILE_PATH

# 去除路径两端可能存在的引号（如果是拖拽进入终端通常会有引号）
FILE_PATH=$(echo $FILE_PATH | sed "s/['\"]//g")

# 3. 健壮性检查：文件是否存在
if [ ! -f "$FILE_PATH" ]; then
    echo "错误: 找不到文件 '$FILE_PATH'，请检查路径是否正确。"
    exit 1
fi

# 4. 定义固定路径
UPLOAD_ENDPOINT="/AnonymousUpload/"
TARGET_URL="http://${DOMAIN}${UPLOAD_ENDPOINT}"

# 获取文件名用于显示
FILENAME=$(basename "$FILE_PATH")

echo "-----------------------------------------------"
echo "准备上传: $FILENAME"
echo "目标地址: https://${DOMAIN}${UPLOAD_ENDPOINT}"
echo "-----------------------------------------------"

# 5. 执行上传命令
# -L: 跟随 Cloudflare 的 HTTPS 重定向
# -#: 显示进度条
# -H: 伪装 User-Agent
# -F: 构造表单上传
curl -L \
     -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
     -# \
     -F "file=@${FILE_PATH}" \
     "$TARGET_URL"

# 6. 检查执行结果
if [ $? -eq 0 ]; then
    echo -e "\n✅ 上传完成！"
else
    echo -e "\n❌ 上传失败，请检查网络或域名是否正确。"
    exit 1
fi