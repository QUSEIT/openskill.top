# OpenSkill.Top

OpenClaw 实践博客，使用 MkDocs 构建，支持中英文双语。

## 域名

https://openskill.top

## 栏目结构

### 中文内容 (zh/)
- **安装配置** - OpenClaw 环境搭建、安装和基础配置
- **技能实践** - 使用 OpenClaw 完成工作任务，定制开发技能
- **技能分享** - 第三方技能分享与发现
- **应用案例** - 多技能整合实现自动化工作流

### English Content (en/)
- **Installation** - OpenClaw environment setup and configuration
- **Skill Practice** - Using OpenClaw for work and customizing skills
- **Skill Sharing** - Third-party skill discovery and sharing
- **Use Cases** - Integrating multiple skills for automated workflows

## 本地开发

```bash
# 安装依赖
pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin

# 启动开发服务器
mkdocs serve

# 构建静态站点
mkdocs build
```

## 项目结构

```
openskill.top/
├── mkdocs.yml          # MkDocs 配置文件
├── docs/
│   ├── zh/            # 中文内容
│   │   ├── index.md
│   │   ├── 安装配置/
│   │   ├── 技能实践/
│   │   ├── 技能分享/
│   │   └── 应用案例/
│   └── en/            # 英文内容
│       ├── index.md
│       ├── installation/
│       ├── skill-practice/
│       ├── skill-sharing/
│       └── use-cases/
└── README.md
```

## 部署

部署到 GitHub Pages：
```bash
mkdocs gh-deploy
```

或使用其他静态站点托管服务（如 Netlify、Vercel）直接部署 `site/` 目录。
