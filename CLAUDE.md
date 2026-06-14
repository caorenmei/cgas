# CLAUDE.md

@AGENTS.md

---

## 子目录指令聚合

处理子目录任务时，检查该目录（及父目录）是否存在 `AGENTS.md`。若存在，将其内容与根 `AGENTS.md` 合并执行；冲突时子目录规则优先。

## 交互建议

- 在需求明确、路径清晰时可直接执行，无需强制提问。
- 当存在多种合理实现方案、需求缺失或用户偏好会影响结果时，使用 `AskUserQuestion` 进行澄清。
- 在 Auto Permission 模式下，避免使用 `AskUserQuestion` 询问 trivial 决策，直接选择合理方案继续。
