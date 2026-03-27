---
title: 更安全地部署OpenClaw：我的容器化隔离实践
date: 2026-03-25
version: 1.1
tags: [OpenClaw, 安全, 容器化, Podman, 部署, 实战经验]
---

# 更安全地部署OpenClaw：我的容器化隔离实践

国家网络安全通报中心最近预警：全球超20万个OpenClaw互联网资产中，大量暴露于公网的实例存在严重安全隐患——架构缺陷、默认高危配置、漏洞利用门槛低、供应链投毒比例高达10.8%。

**作为在服务器上跑OpenClaw的人，我仔细看了这份通报，决定做一件事：把OpenClaw关进笼子里。**

不是不用它，而是让它既能干活，又碰不到我的核心系统。

---

## 我的思路：运行隔离

通报里提到的风险，归根结底都是同一个问题：**OpenClaw和你服务器的边界太模糊了。**

- 默认绑定0.0.0.0，谁都能连
- 插件运行在和你一样的权限环境里
- 智能体一旦失控，直接操作宿主机

**解决方案很简单：隔离。**

让OpenClaw跑在一个"沙盒"里，它能访问什么、能做什么，全部由你说了算。即使出问题，也只影响那个沙盒。

我用的是 **Podman**——比Docker更轻量，不需要守护进程，资源占用更少。

---

## 具体操作：三步走

### 第一步：创建隔离容器

```bash
podman run -d \
  --name claw \
  --user root \
  -p 13000-13005:13000-13005 \
  -v /data/openclaw-docker/data:/root \
  -e NODE_OPTIONS="--max-old-space-size=4096" \
  ghcr.io/openclaw/openclaw:latest
```

**为什么这样配？**

| 参数 | 我的考虑 |
|------|----------|
| `--user root` | 容器内的root，不是宿主机的root。省去容器内权限折腾，又不影响宿主机安全 |
| `-p 13000-13005` | 我预留了6个端口给后续服务用，现在不暴露18789（那个默认管理端口太危险） |
| `-v /data/...:/root` | 数据持久化到宿主机，容器删了数据还在 |
| `NODE_OPTIONS` | 给Node.js 4GB内存，够用又不至于吃光系统资源 |

**关键点：18789端口没有映射。** 这意味着即使有人扫描到你的服务器，也找不到OpenClaw的默认入口。

### 第二步：Systemd自动重启

手动启动的容器，服务器重启后就没了。我要它像系统服务一样稳定：

```bash
# 1. 准备systemd目录
mkdir -p ~/.config/systemd/user

# 2. 生成服务文件（--restart-policy=always 是关键）
podman generate systemd --name --restart-policy=always --files claw

# ⚠️ 重要：打开container-claw.service检查
# 确保没有 podman rm 这种会删容器的操作
vim container-claw.service

# 3. 复制到systemd目录
cp container-claw.service ~/.config/systemd/user
systemctl --user daemon-reload

# 4. 设置开机自启
systemctl --user enable container-claw.service
sudo loginctl enable-linger $USER

# 5. 切换到systemd管理
podman stop claw
systemctl --user start container-claw.service
```

**验证一下**：
```bash
systemctl --user status container-claw.service
# 看到 Active: active (running) 就稳了
```

现在即使服务器重启，OpenClaw也会自动恢复，不需要你登录手动启动。

### 第三步：安全地远程控制

18789没暴露，我怎么控制OpenClaw？

**答案是：通过IM。**

```bash
# 进入容器
podman exec -it claw /bin/bash

# 运行配置向导
openclaw onboard
```

按提示绑定Telegram/Discord/Slack，之后你就可以通过安全的IM通道和OpenClaw交互——不需要暴露任何管理端口到公网。

| 方式 | 风险 | 我的选择 |
|------|------|----------|
| 直接暴露18789 | 极高，通报里说的85%公网暴露就是这个 | ❌ 不用 |
| IM集成 | 低，消息通道本身有平台安全机制保护 | ✅ 采用 |

---

## 这样部署，我得到了什么

✅ **边界清晰**：OpenClaw被关在容器里，即使智能体"发疯"也出不来  
✅ **端口可控**：只开放必要的服务端口，高危管理端口完全隔离  
✅ **数据安全**：重要数据挂载在宿主机，容器只是"运行环境"  
✅ **自动恢复**：Systemd确保服务高可用，不用手动维护  
✅ **远程安全**：通过IM控制，彻底摆脱端口暴露的风险

**这套方案不是完美的**——它不能阻止你安装恶意插件，也不能修复OpenClaw本身的漏洞。但它做了一件事：**把"一旦被攻破就全盘皆输"变成"即使被攻破也只在沙盒里"。**

对于跑在生产环境的服务器来说，这个区别可能就是"睡一觉起来一切正常"和"紧急修复到凌晨3点"的差距。

---

## 几个额外的建议

如果你也准备这么干，这几件事值得注意：

**1. 定期备份数据目录**
```bash
# 数据存在这里，记得备份
cp -r /data/openclaw-docker/data /backup/openclaw-$(date +%Y%m%d)
```

**2. 防火墙限制端口访问**
即使只映射了13000-13005，也建议用防火墙限制来源IP：
```bash
# 只允许特定IP访问
ufw allow from 你的IP to any port 13000:13005
```

**3. 插件审慎安装**
通报里说的10.8%恶意插件比例不是吓唬人。安装前花两分钟看看代码，或者只从可信来源安装。

**4. 定期更新镜像**
```bash
podman pull ghcr.io/openclaw/openclaw:latest
systemctl --user restart container-claw.service
```

---

## 写在最后

网络安全通报中心的预警不是让我们不用OpenClaw，而是提醒我们用得更聪明。

容器化隔离不是什么高深技术，Podman+Systemd的组合也很成熟。**关键是意识到风险在哪里，然后采取行动。**

如果你也在用OpenClaw跑业务，希望这篇文章能给你一些参考。

---

**我的配置**：
- 服务器：Linux (Ubuntu 22.04)
- 容器：Podman 4.x
- OpenClaw：ghcr.io/openclaw/openclaw:latest

有问题欢迎交流。

---

*本文采用 Build with Public 方式创作——实战经验，全程透明。*
