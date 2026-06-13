# CLAUDE.md

@AGENTS.md

---

## 子目录指令聚合

处理子目录任务时，检查该目录（及父目录）是否存在 `AGENTS.md`。若存在，将其内容与根 `AGENTS.md` 合并执行；冲突时子目录规则优先。

## 强制交互协议

- 总是使用 `AskUserQuestion` 工具提问。
- 每轮任务结束后使用 `AskUserQuestion` 询问下一步，选项：
  - 当前上下文相关的后续问题（多选）
  - 先到这里
