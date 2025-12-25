## 一、脚本功能说明
``` bash
# 默认：驯服 NetworkManager + Docker DNS
sudo ./fix-dns-docker.sh

# 回滚：恢复最近一次 NetworkManager 连接备份
sudo ./fix-dns-docker.sh --rollback
```

## 二、脚本实现功能

✅ 自动识别真实出网卡
✅ 只驯服 `NetworkManager`，不关服务
✅ Docker / 系统 DNS 同步
✅ 带备份 + 一键回滚
✅ 可反复执行，不破坏系统

## 三、备份回滚（如果你想恢复到以前）

脚本会把当前连接配置备份到 `/root/nm-backup/`，你可以用备份文件对照手动改回去；加一个 `--rollback 参数`（自动回滚到上一次备份）