
## 11. 实现要点

1. **纯 Lua 表**：不依赖任何外部库，除 Lua 标准库外无依赖。
2. **无状态库**：MiniGas V2 不维护任何运行时状态，所有状态由调用方通过 `IEntityState` / `IWorldState` 传入并持有。
3. **接口化解耦**：通过 `IEntityModule`、`IWorldModule`、`IContext`（含可选 `IDebug`）、`ApplyFun` 与业务状态解耦，便于集成到现有系统。
4. **模块拆分**：`asc.lua` 仅保留公共 API 聚合与主控求值流程，具体逻辑按职责拆分到 `tag.lua`、`ability.lua`、`effect.lua`、`modifier.lua`、`pool.lua`、`debug.lua`，保持核心文件轻量。
5. **迭代器陷阱**：`IEntityModule` 与 `IWorldModule` 的迭代器均返回 `(iterator, state)` 二元组；库内部使用 `for ... in iterator, state` 避免 `local k, v = next(t, k)` 导致的局部变量遮蔽死循环。
6. **ModifierAttributeEval 参数**：首次调用时固定传入 `id = nil, value = nil`，随后才是当前 Ability 产生的 `modifier_args`。`modifier_args` 来源：对象形式为 `{ count, ... }`；函数形式为函数返回的 `...`；为空时直接采用 `ASC.evaluate` 调用者传入的上下文参数。
7. **数值稳定**：Modifier 聚合顺序固定：先累加 Add，再连乘 Multiply，最后判断 Override；最终值按 `AttributeDef.min/max` 截断。
8. **单一 ApplyFun 与 target 级应用**：每个 `target` 实体在全部求值完成后，只调用一次 `ApplyFun`，传递聚合后的标签集合 `tags`（`table<mini_gas.Tag, boolean>`）与 `attributes` 映射（`table<mini_gas.ID, number>`）。Add 语义下 `attributes[id] = new_value - base`，业务方通过“旧值 + 差值”得到最终值。
9. **对象池与所有权**：`pool.lua` 提供分类对象池：`tags_pool`、`attrs_pool`、`evaluate_args_pool`、`active_abilities_pool`，其余小型临时表复用通用 `table_pool`，降低 GC 压力。
   - `ApplyFun` 收到的 `tags` 与 `attributes` 归库所有，`apply` 返回后会被立即回收。
   - 所有对象池均带有重复释放保护，避免同一张表在池中出现多次。
   - 业务方如需在 `apply` 返回后继续保留数据，必须在回调内部完成复制。
10. **错误隔离**：非法配置（不存在的 AbilityDef / EffectDef）静默跳过，不中断其他计算。

---

## 13. 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-06-14 | 初始版本，包含 Attribute / Modifier / Effect / Context |
| v2.0 | 2026-06-14 | 完全重构为快照式、被动-only、接口化解耦的轻量 GAS 核心；目录保持 `lua_lib/mini_gas`；移除主动技能、冷却、消耗、事件、任务等机制 |
| v2.1 | 2026-06-16 | 统一 Module 参数透传；IEvaluation 回调合并为单一 `apply`；引入模块内部对象池减少 GC |
| v2.2 | 2026-06-17 | 按 `docs/specs/mini_gas_v2/` 完全重写接口：`IContext` 聚合 `world`/`world_module`/`defs`；`IDebug` / `ApplyFun` 替代 `IEvaluation`；两阶段求值流程；简化 `ModifierAttributeEval` 与 `AbilityActivateConditionFunc` 签名 |
| v2.3 | 2026-06-17 | 拆分 `asc.lua` 为 `tag`/`ability`/`effect`/`modifier`/`pool`/`debug` 子模块；`IDebug` 改为 `IContext.debug`；对象池分类为 `tags_pool`/`attrs_pool`/`evaluate_args_pool`/`active_abilities_pool`；`ability_def_id`/`effect_def_id` 重命名为 `ability_id`/`effect_id` |

---

> [返回 Mini-GAS 设计文档总览](./README.md)
