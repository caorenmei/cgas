# AGENTS.md

## 项目概述

`cgas` 是一个基于 Lua 的 GAS（Gameplay Ability System）库，参考 Unreal Engine 的 GAS 系统设计。

## 目录结构

```
cgameplay/
├── docs/                    # 项目文档
│   ├── books/               # 第三方库中文文档
│   └── specs/               # 功能规格说明
├── lua_lib/                 # 核心库代码，按功能模块划分子目录
├── lua_metas/               # 预留：LuaCATS 类型定义
├── lua_tests/               # 测试代码，测试文件以 `*_spec.lua` 命名
├── lua_tools/               # Lua 工具脚本
├── AGENTS.md                # 项目开发规范
├── CLAUDE.md                # Claude 开发指令
├── *.rockspec               # LuaRocks 包配置
├── .luarc.json              # LuaLS 配置
├── lua                      # 便利脚本：Lua REPL
└── luarocks                 # 便利脚本：LuaRocks 本地管理
```

## 开发环境

- **Lua 5.4** — 解释执行，无需编译
- **LuaRocks** — 本地依赖管理（`lua_modules/`）
- **busted** — 单元测试框架
- **lua-lsp** — Lua 语言服务器（`.luarc.json`），提供代码补全、诊断、格式化、类型注释等功能，类型注释参考 @docs/books/LuaCATS-annotations.md
- **便利脚本**：`./lua`（带本地路径的 REPL）、`./luarocks`（本地依赖管理）

## 开发工作流

- **Git Worktree**：@git-worktree-manager 使用 `git worktree` 管理多分支并行开发，避免切换分支导致的环境重建。
  - 主工作区保持 `main` 分支。
  - 各 worktree 独立运行，互不干扰。
  - 详细流程见 skill。

- **TDD**：新功能、Bug 修复、重构均遵循红-绿-重构循环。先写失败的测试，再写最小实现使其通过，最后重构。
- **静态诊断**：提交前运行 `lua-language-server --check . --configpath .luarc.json`，确保无诊断问题。

## 测试环境

- **busted** — 测试框架，测试文件以 `*_spec.lua` 命名
- **目录**：`lua_tests/`，`lua_tests/support/env.lua` 负责环境初始化
- **运行**：`busted lua_tests/`

## 语言规范

- 用户交互、文档、注释：简体中文
- 代码、配置：英文（注释可用中文）
- 技术术语、缩写、约定俗成表达：可保留英文

## Agent 协同准则

- **主筹子执**：主 Agent 专职规划与终审，仅直回微小需求，其余具体执行一律外包。
- **动态规划**：拒绝前置过度拆分，必须依据子 Agent 阶段性反馈进行滚动派单。
- **结论至上**：子 Agent 仅返回**结构化结论 + 摘要**，主 Agent 上下文屏蔽原始日志。
- **容错防锁**：子 Agent 出错仅允许单次重试，持续失败则由主 Agent 降级介入改道。
