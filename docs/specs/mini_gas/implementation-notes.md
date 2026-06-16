
## 11. 实现要点

1. **纯 Lua 表**：不依赖任何外部库，除 Lua 标准库外无依赖。
2. **无状态库**：MiniGas V2 不维护任何运行时状态，所有状态由调用方通过 `IEntityState` / `IWorldState` 传入并持有。
3. **接口化解耦**：通过 `IEntityModule`、`IWorldModule`、`IEvaluation` 与业务状态解耦，便于集成到现有系统。所有需要访问状态的地方都同时传入对应的 Module 接口。
4. **迭代器陷阱**：`IEntityModule` 与 `IWorldModule` 的迭代器均返回 `(iterator, state)` 二元组；库内部使用 `for ... in iterator, state` 避免 `local k, v = next(t, k)` 导致的局部变量遮蔽死循环。
5. **ModifierAttributeEval 参数**：首次调用时固定传入 `id = nil, value = nil`，随后才是 `can_activate` 产生的上下文或调用者传入的上下文。函数签名同时接收 `world_module` 与 `entity_module`。
6. **数值稳定**：Modifier 聚合顺序固定：先累加 Add，再连乘 Multiply，最后判断 Override；最终值按 `AttributeDef.min/max` 截断。
7. **单一 apply 与 owner 级聚合**：每个 owner 处理完毕后，只调用一次 `IEvaluation.apply`，传递聚合后的标签集合 `tags`（`table<mini_gas.Tag, boolean>`）与 `attr_changes` 数组（`AttrChangeEntry[]`）。Add 语义下 `value = new_value - base`，业务方通过“旧值 + 差值”得到最终值。
8. **对象池**：`asc.lua` 内部使用模块级对象池复用求值过程中产生的临时表（tags、attr_changes 与 owner_mods 等），降低 GC 压力。回调返回后这些表会被立即回收，业务方如需保留必须在 `apply` 内复制。
9. **错误隔离**：非法配置（不存在的 AbilityDef / EffectDef）静默跳过，不中断其他计算。

---

## 13. 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-06-14 | 初始版本，包含 Attribute / Modifier / Effect / Context |
| v2.0 | 2026-06-14 | 完全重构为快照式、被动-only、接口化解耦的轻量 GAS 核心；目录保持 `lua_lib/mini_gas`；移除主动技能、冷却、消耗、事件、任务等机制 |
| v2.1 | 2026-06-16 | 统一 Module 参数透传；IEvaluation 回调合并为单一 `apply`；引入模块内部对象池减少 GC |

---

> [返回 Mini-GAS 设计文档总览](./README.md)
