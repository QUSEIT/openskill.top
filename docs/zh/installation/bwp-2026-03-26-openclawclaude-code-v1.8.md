---
title: 在 OpenClaw 容器里装 Claude Code（上）：手机上也能开发软件项目了
date: 2026-03-26
version: v1.8
---

# 在 OpenClaw 容器里装 Claude Code（上）：手机上也能开发软件项目了

## 这件事的起因

上周末带娃去公园，正看着他荡秋千，产品群里冒出一条消息：「登录页按钮颜色不对，能改一下吗？」

改，当然能改。但我面前只有一部手机。

类似的时刻其实挺多的。地铁上忽然想到一个 BUG 的修法，躺沙发上想顺手重构一段逻辑——每次都得等回到电脑前才能动手，等到了，那股劲儿早过了。

我就在想，能不能打开飞书 @一下，就像给同事发消息一样，让 AI 直接帮我改？不用开电脑，不用连 SSH。

折腾了一阵，还真跑通了：把 Claude Code 装进 OpenClaw 容器，飞书当入口，国内网络环境下稳定运行。

昨天写了[安全部署 OpenClaw](https://www.openskill.top/zh/installation/bwp-2026-03-25-openclaw-v1.1/) 的部分，今天接着往下——怎么在容器里装好 Claude Code，再通过飞书把它叫起来。

整个过程我会分三篇写：
- **上篇（就是这篇）**：容器内安装 Claude Code + 飞书桥接，跑通基础链路
- **中篇**：Deploy Bot 和 Bot-to-Bot 配置，让几个 AI 员工能互相协作
- **下篇**：完整闭环——从一句话需求到自动部署

---

## 它需要做到什么

有了前面的想法，接下来就是明确需求。我梳理了三个核心场景：

**碎片时间改代码。** 下午带娃在游乐场，产品经理群里说「登录按钮样式要改为蓝色」。我打开飞书，@Claude Bot：「登录按钮背景色改成品牌蓝，圆角再大一些」。两分钟后收到回复：「已修改，diff 如下...」

**复杂任务丢给它跑。** 晚上8点，我扔一个任务：「重构用户模块，把耦合的业务逻辑拆成独立服务」。它默默干活，第二天早上我看代码、提意见，它继续改。

**几个 Bot 之间能接力。** 我在飞书群里说：「@PM Bot 我要一个新功能」。PM Bot 拆解完任务 → @Claude Bot 写代码 → @Deploy Bot 自动部署 → 所有人收到通知。

说到底就一件事：让 Claude Code 像团队成员一样随时在线，而不是一个得开电脑才能用的工具。

---

## 为什么选了 OpenClaw + Claude Code

你可能想问，直接用 Claude 网页版或者 App 不就行了？

我都试过。Claude 网页版每次都得登录，代码复制粘贴很麻烦。Claude App 手机端操作不了服务器文件。Cursor 和 Trae 需要打开 IDE，碎片时间用不了。Claude 官方的 Discord Bot 在国内又不太稳定。

试了一圈之后，我发现 OpenClaw + Claude Code 这个组合刚好补上了这些缺口：Claude Code 跑在服务器容器里，24小时在线；飞书做入口，国内团队本来就在用，消息即指令；代码写在 `/root/projects`，容器内外都能访问；后续还能接 Deploy Bot、PM Bot，慢慢搭出一个团队。

目前来看，这是我试下来在国内环境里体验最顺畅的方案。

---

## 第一步：在 OpenClaw 容器里装 Claude Code

### 进入容器

假设你已经跟着[上一篇](https://www.openskill.top/zh/installation/bwp-2026-03-25-openclaw-v1.1/)把 OpenClaw 跑起来了，先确认容器还在：

```bash
docker ps | grep openclaw
```

进入容器，工作目录直接定在 `/root`——后面所有代码都放这里，容器和宿主机共享：

```bash
docker exec -it -w /root openclaw /bin/bash
```

### 安装

OpenClaw 容器自带 Node.js，一行搞定：

```bash
npm install -g @anthropic-ai/claude-code
```

装完验证一下：

```bash
claude --version
```

能看到版本号就行。

### 配置 API Key

Claude Code 需要 `ANTHROPIC_API_KEY` 环境变量。如果你用 Anthropic 原版，就配原版的 Key；如果用国内的平替模型（Kimi、MiniMax、DeepSeek 之类），就根据它们文档给的方法设置对应的变量。

写进 `~/.bashrc` 或 `/root/.env` 都行，关键是 Claude Code 启动时能读到。

试一下：

```bash
claude
```

输入 `hello`，有回复就说明通了。`Ctrl+D` 退出。

---

## 第二步：飞书桥接

### 先理清数据怎么走

整个链路其实很简单：

```
我（飞书）
  ↓ @Claude Bot
Claude Bot（飞书 Bot，跑在容器里）
  ↓ 本地调用
Claude Code（同一容器内）
  ↓ 读写文件
/root/projects（持久化目录）
```

Claude Bot 和 Claude Code 在同一个容器里，通过本地进程调用，不走外部网络。代码存在 `/root/projects`，容器重启也不丢。

### 装 claude-client

```bash
docker exec -it -w /root openclaw /bin/bash

git clone https://github.com/Hanson/claude-client.git claude-feishu
cd claude-feishu
npm install
```

创建 `.env` 文件：

```bash
FEISHU_APP_ID=cli_xxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FEISHU_ENCRYPT_KEY=your_encrypt_key
FEISHU_VERIFICATION_TOKEN=your_verification_token
PORT=3000
HOST=0.0.0.0
```

这些值要从飞书开发者平台拿，下面一步步说，也推荐看看[项目的官网](https://github.com/Hanson/claude-client.git)。

### 飞书那边的配置

这部分步骤多一点，但按顺序走就好，不复杂。

**创建应用：** 打开 [飞书开发者平台](https://open.feishu.cn/)，创建「企业自建应用」，把 App ID 和 App Secret 记下来。

**拿到密钥：** 左侧菜单「凭证与基础信息」里有 App ID 和 App Secret；「事件订阅」里有 Encrypt Key 和 Verification Token。

**申请权限：** 进「权限管理」，加这三个：
- `im:chat:readonly` — 获取群组信息
- `im:message.group_msg` — 接收群消息
- `im:message:send_as_bot` — 以机器人身份发消息

**事件订阅：** 进「事件与回调」→「事件订阅」，添加 `im.message.receive_v1`。请求地址 URL 不用填，claude-client 走的是长连接。

**回调配置（容易漏）：** 同样在「事件与回调」里，切到「回调设置」Tab，点「回调」，选中 `card.action.trigger` 并保存。这步漏了的话卡片交互会不工作。

**发布上线：**「版本管理与发布」→ 创建版本 → 申请发布 → 审核通过后把机器人拉进目标群。

### 启动

```bash
npm run build
npm start
```

看到 `Server running on port 3000` 就好了。

想让它后台常驻：

```bash
npm install -g pm2
pm2 start npm --name "claude-feishu" -- start
```

### 试一下

在飞书群里 @你的机器人：

```
@ClaudeBot 帮我写一个斐波那契数列的 Python 脚本
```

如果它回复了——确认收到、创建文件、返回代码、告诉你文件路径——那基础链路就通了。

---

## 下一次，我想聊聊 Bot 之间怎么协作

到这里，你应该已经有一个能在飞书里叫到的 Claude Bot 了——能改代码，能读写文件，基本够用。

但我真正想做的不止于此。

我希望代码写完之后，Deploy Bot 能自动把它构建、预览、发布上线。我希望 PM Bot 拆完需求后能直接 @Claude Bot 开干，不用我在中间传话。我想试试用飞书的交互卡片做一个任务进度面板，谁在干什么一目了然。

这些就是中篇要折腾的事了。

再往后的下篇，会把整条链路串起来：一句话提需求 → 任务拆解 → 写代码 → 自动部署，跑一个完整的闭环出来。

---

## 写在最后

如果你也想试试，建议先把这篇的基础链路跑通。飞书能叫到 Claude，能读写文件，这就已经成功一半了。

然后挑一个真实的小任务练手——「帮我写个爬虫」「重构一下这个函数」，从简单的开始。每个人的环境不一样，碰到的问题也不同，随手记下来，以后回头看会发现很值得。

有问题的话，群里聊。

下一篇见。

---

*Created with bwp on 2026-03-26*
