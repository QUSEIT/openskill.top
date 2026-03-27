---
title: 在OpenClaw容器中部署Claude Code（上）：从零开始搭建你的AI开发助手
date: 2026-03-26
version: v1.4
---

# 在OpenClaw容器中部署Claude Code（上）：从零开始搭建你的AI开发助手

## 我为什么要写这个系列

之前分享了安全部署 OpenClaw 的实践经验。今天进入更硬核的部分：把 Claude Code 装进 OpenClaw 容器，再用飞书做遥控器。

这不是炫技。我是真的需要一个随时待命的AI开发助手——在地铁上、在会议间隙、甚至躺在沙发上，打开手机就能让 Claude 帮我写代码、改 BUG、做重构。

而且我要让它在国内环境下稳定运行。这是我踩过坑之后找到的方案。

这个系列会分三篇：
- **上篇（本文）**：从零开始，把 Claude Code 装进 OpenClaw 容器，飞书能叫到它
- **中篇**：Deploy Bot 发布流程定制，以及飞书 Bot-to-Bot 的配置——让 AI 员工之间能相互协作
- **下篇**：完整的 AI Agent 协作团队，从需求提出到自动部署的闭环

---

## 我的场景：为什么非要这么折腾？

先交代一下我的实际需求，你判断一下适不适合你：

**场景一：碎片时间开发**
下午带娃在游乐场，产品经理在群里说「登录按钮样式要改」。我打开飞书，@Claude Bot：「把 `/root/projects/web/src/components/LoginButton.tsx` 的背景色改成品牌蓝，圆角加大」。两分钟后收到回复：「已修改，diff 如下...」

**场景二：复杂任务异步处理**
晚上8点，我扔给 Claude 一个任务：「重构用户模块，把耦合的业务逻辑拆成独立服务」。它默默干到凌晨，第二天早上我验收代码、提出修改意见，它继续迭代。

**场景三：多 Agent 协作**
我在飞书群里说：「@PM Bot 我要一个新功能」。PM Bot 拆解任务 → @Claude Bot 写代码 → 完成后 @Deploy Bot 自动部署 → 所有人收到通知。

**核心诉求：让 Claude Code 变成我团队的一员，而不是一个需要开电脑才能用的工具。**

---

## 方案选型：为什么 OpenClaw + Claude Code？

你可能问：直接用 Claude 的网页版或者 App 不就行了？

我试过，不行。原因：

| 方案 | 问题 |
|------|------|
| Claude 网页版 | 每次都要登录，代码片段复制粘贴很痛苦 |
| Claude App | 手机端不能操作服务器文件 |
| Cursor/Trae | 需要打开 IDE，碎片时间不方便 |
| Claude 官方 Discord Bot | 国内访问不稳定 |

**OpenClaw + Claude Code 的优势：**
1. **容器化**：Claude Code 跑在服务器里，24小时在线
2. **飞书接入**：国内团队都在用，消息即指令
3. **文件持久化**：代码写在 `/root/projects`，容器内外都能访问
4. **可扩展**：后续能接入 Deploy Bot、PM Bot，形成团队

这是我自己验证过的最优路径。

---

## 第一部分：在 OpenClaw 容器中安装 Claude Code

### 1.1 前置准备

假设你已经按照昨天的文章把 OpenClaw 跑起来了。检查容器状态：

```bash
docker ps | grep openclaw
```

进入容器，直接跳到工作目录 `/root`（这也是容器和宿主机共享数据的路径）：

```bash
docker exec -it -w /root openclaw /bin/bash
```

确认你在 `/root` 目录下。后续所有项目代码都会放在这里。

### 1.2 安装 Claude Code

OpenClaw 容器已经带了 Node.js，直接装：

```bash
npm install -g @anthropic-ai/claude-code
```

验证安装：

```bash
claude --version
```

看到版本号就是成功了。

### 1.3 配置 API Key

Claude Code 需要 `ANTHROPIC_API_KEY` 环境变量。配置方法和国内平替模型（Kimi、MiniMax、DeepSeek 等）一样：

1. 把 API Key 写进 `~/.bashrc` 或者 `/root/.env`
2. 如果用国产平替，设置 `OPENAI_API_KEY` 和 `OPENAI_BASE_URL` 指向对应端点
3. 确保 Claude Code 启动时能读到这些变量

测试一下：

```bash
claude
```

输入 `hello`，有回复就是 OK。按 `Ctrl+D` 退出。

---

## 第二部分：飞书桥接部署

### 2.1 架构设计

先搞清楚数据流：

```
我（飞书）
  ↓ @Claude Bot
Claude Bot（飞书 Bot，跑在容器里）
  ↓ 本地调用
Claude Code（同一容器内）
  ↓ 读写文件
/root/projects（持久化目录）
```

**关键点：**
- Claude Bot 和 Claude Code 在同一个 OpenClaw 容器里
- 通过本地进程调用，不走网络
- 代码存在 `/root/projects`，容器重启不丢

### 2.2 安装 claude-client

回到容器里：

```bash
docker exec -it -w /root openclaw /bin/bash

git clone https://github.com/Hanson/claude-client.git claude-feishu
cd claude-feishu
npm install
```

创建 `.env`：

```bash
FEISHU_APP_ID=cli_xxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FEISHU_ENCRYPT_KEY=your_encrypt_key
FEISHU_VERIFICATION_TOKEN=your_verification_token
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CLAUDE_MODEL=claude-3-7-sonnet-20250219
PORT=3000
```

这些值从飞书开发者平台获取，下一节详细说。

### 2.3 飞书应用配置（关键步骤）

这部分我踩过坑，按我的步骤来：

**Step 1：创建应用**
- 打开 [飞书开发者平台](https://open.feishu.cn/)
- 创建「企业自建应用」
- 记录 App ID 和 App Secret

**Step 2：开启机器人能力**
- 左侧菜单「凭证与基础信息」→ 拿到 App ID 和 App Secret
- 「事件订阅」→ 拿到 Encrypt Key 和 Verification Token

**Step 3：申请权限**
进入「权限管理」，添加这三个：
- `im:chat:readonly` —— 获取群组信息
- `im:message.group_msg` —— 接收群消息
- `im:message:send_as_bot` —— 以机器人身份发消息

**Step 4：事件订阅（重要）**
- 进入「事件与回调」→「事件订阅」
- 添加事件：`im.message.receive_v1`
- **不用填请求地址 URL**，claude-client 用长连接接收

**Step 5：card.action.trigger 配置（容易漏）**
- 「事件与回调」→「回调设置」Tab
- 点击「回调」
- 选中 `card.action.trigger` 并保存

**Step 6：发布**
- 「版本管理与发布」→ 创建版本
- 申请发布，通过审核
- 把机器人拉进目标群

### 2.4 启动服务

```bash
npm run build
npm start
```

看到 `Server running on port 3000` 就成功了。

**后台运行：**

```bash
npm install -g pm2
pm2 start npm --name "claude-feishu" -- start
```

### 2.5 验证：我的第一次交互

在飞书群里 @你的机器人：

```
@ClaudeBot 在 /root/projects/test 目录下创建一个 Python 脚本，实现斐波那契数列
```

期待回复：
1. 确认收到任务
2. 创建目录和文件
3. 返回代码内容
4. 告诉你文件路径

如果看到这步，恭喜你，基础链路通了。

---

## 我踩过的坑（省你两小时）

### 坑1：Claude Code 需要 TTY

错误表现：调用 Claude Code 时卡住或报错 `stdin is not a tty`

解决：用 `script` 命令包装，或者确保调用环境有伪终端。

### 坑2：飞书消息长度限制

Claude 回复太长会被截断。解决方案是中篇要讲的——分段发送 + 关键信息摘要。

### 坑3：会话状态丢失

每次@机器人都是新会话，Claude 记不住之前说过什么。下篇会讲怎么用 session 文件保持上下文。

### 坑4：文件权限问题

容器内写的文件，宿主机可能读不了。确保 `/root/projects` 的权限设置正确。

---

## 本篇完成度 & 下篇预告

**本文你已完成：**
- ✅ OpenClaw 容器内安装 Claude Code
- ✅ 飞书 Bot 桥接部署
- ✅ 基础交互验证

**中篇预告（Deploy Bot + Bot-to-Bot）：**
- Deploy Bot 的实现：代码写完后自动构建、预览、发布
- 飞书 Bot-to-Bot 配置：让 PM Bot、Claude Bot、Deploy Bot 能相互@协作
- 消息卡片进阶：用飞书的交互卡片做任务进度展示

**下篇预告（完整闭环）：**
- 从一句话需求到自动部署的全流程
- 会话状态管理：多轮对话保持上下文
- 实际业务场景的实战案例

---

## 我的建议

如果你也想搭这套系统，我的建议是：

1. **先跑通本文的基础链路** —— 飞书能叫到 Claude，能写文件，就成功了一半
2. **选一个真实小任务练手** —— 比如「帮我写个爬虫」或「重构这个函数」，别一上来就搞复杂需求
3. **记录你的配置和坑** —— 每个人的环境不一样，踩过的坑最有价值
4. **关注 openskill.top** —— 我会持续更新这个系列的实战经验

有问题欢迎到群里讨论。

**下一篇见。**

---

*Created with bwp on 2026-03-26*