---
name: github-proxy
description: 所有 GitHub 交互（push/pull/fetch/PR 等）一律通过本地代理 http://127.0.0.1:1080 执行
---

# GitHub 代理规范

## 适用范围

所有与 GitHub 的交互操作，包括但不限于：

- `git push` / `git pull` / `git fetch`
- `git clone` / `git remote` 相关操作
- `gh` CLI 操作（创建 PR、查看 issue、合并等）
- 其他访问 GitHub API 或仓库的网络请求

## 代理配置

代理地址固定为：`http://127.0.0.1:1080`

### 方式一：配置 Git 代理（推荐）

执行 GitHub 相关操作前，确保项目已配置：

```bash
git config http.proxy http://127.0.0.1:1080
git config https.proxy http://127.0.0.1:1080
```

### 方式二：命令行前置环境变量

对于 `gh` 或其他不支持 git config 代理的工具，使用环境变量：

```bash
HTTP_PROXY=http://127.0.0.1:1080 HTTPS_PROXY=http://127.0.0.1:1080 gh pr create
```

## 检查与提示

- 执行 GitHub 操作前，优先检查代理是否可用（例如 `curl -I --proxy http://127.0.0.1:1080 https://github.com`）。
- 如果代理不可用，必须先提示用户启动代理服务，再执行后续操作。
- 不要绕过代理直接连接 GitHub。
