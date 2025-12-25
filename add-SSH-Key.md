你这一步其实已经**走对一半了**：
前面那段 “authenticity… Are you sure…” 是 **第一次连 GitHub 时的正常安全提示**（把 GitHub 的主机指纹加入 `known_hosts`）。真正的问题在这里：

> `Permission denied (publickey).`

意思是：**你用 SSH 方式连接 GitHub，但本机没有可用的 SSH 公钥被 GitHub 认可**（或没有把正确的 key 用上）。

下面按“最稳最少坑”的流程修好（直接照抄跑即可）。

---

## 1）先确认你本机有没有 SSH key

```bash
ls -al ~/.ssh
```

看有没有这些文件之一（通常成对出现）：

* `id_ed25519` 和 `id_ed25519.pub`（推荐）
* 或 `id_rsa` 和 `id_rsa.pub`

### 如果你根本没有 `.pub` 文件

那就去第 2 步生成。

---

## 2）生成一个新的 SSH key（推荐 ED25519）

把邮箱换成你 GitHub 的邮箱：

```bash
ssh-keygen -t ed25519 -C "你的邮箱"
```

一路回车即可（会提示保存路径、是否设置密码）。
生成好后，再确认：

```bash
ls -al ~/.ssh
```

应该能看到：

* `id_ed25519`
* `id_ed25519.pub`

---

## 3）启动 ssh-agent 并把 key 加进去（mac 常用）

```bash
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

如果你用的是旧版 macOS，不认 `--apple-use-keychain`，就用：

```bash
ssh-add ~/.ssh/id_ed25519
```

---

## 4）把公钥添加到 GitHub（关键一步）

把公钥复制出来：

```bash
cat ~/.ssh/id_ed25519.pub
```

复制输出的整行（以 `ssh-ed25519` 开头）。

然后去 GitHub：

* 头像 → **Settings**
* **SSH and GPG keys**
* **New SSH key**
* Title 随便写（如 “MacBook”）
* Key 粘贴刚刚那行公钥
* Add

（这一步你自己操作即可，我不需要你给我你的 key 内容。）

---

## 5）测试 SSH 是否能连上 GitHub

```bash
ssh -T git@github.com
```

正常成功会看到类似：

* “Hi xxx! You've successfully authenticated…”

如果还是失败，把它输出的错误信息发我，我直接定位是哪一层的问题。

---

## 6）重新 clone（这次应该就 OK）

回到你想放代码的目录：

```bash
cd ~/Documents
git clone git@github.com:Walker-King-Z/ProgramingStudy.git
```

---

## 7）顺带提醒：你这个仓库你有没有权限？

即使 SSH 配好，如果仓库是**私有**且你不在协作者里，也会没权限。
但那种通常会更像“repository not found”或权限相关提示。

你现在报的是典型的 **SSH key 没配/没生效**。

---

## 8）你这个 IP 看起来有点怪：`198.18.0.47`

GitHub 常见是公网 IP / 域名解析，不太会是 `198.18.x.x` 这种（这是保留地址段，常用于网络测试环境）。
这可能意味着你：

* 开了代理/加速器/公司网络中间人
* 或者改了 hosts / DNS
* 或者某个工具在“接管” github.com 解析

它不一定会导致失败，但**可能让问题更难排查**。
等你做完第 5 步测试，如果仍不行，我会让你跑两条命令确认解析路径：

```bash
ssh -vT git@github.com
```

（先别急着跑，按上面 1→6 走更快。）

---

你现在先做：**第 2、3、4、5 步**。
把你运行 `ssh -T git@github.com` 的输出（成功或失败都行）贴给我，我就能带你把最后一步彻底搞定。
