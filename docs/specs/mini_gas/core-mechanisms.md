
## 6. 核心机制

### 6.1 层级标签

标签采用点分层级结构，例如 `state.dead`、`effect.burning`。父级标签匹配所有子级标签：`state` 匹配 `state.dead`，`state.dead` 不匹配 `state.stunned`。

匹配规则由库提供的 `match_tag`、`entity_match_tag`、`match_tags` 实现。

### 6.2 属性初始值与边界约束

- 属性的旧值由 `IEntityModule.get_attribute(entity, id)` 决定，`AttributeDef` 本身不定义初始值。
- 不在 `Defs.attribute_defs` 中定义的属性，仍按 `IEntityModule.get_attribute` 的返回值作为旧值，且不检查最大值和最小值约束。
- 库在聚合所有生效的 Modifier 后，会按 `Defs.attribute_defs[id]` 中的 `min` 与 `max` 对最终值做截断；未定义 `min` 或 `max` 时，对应方向不限制。最终传给 `ApplyFun` 的 `attributes[id]` 已经是截断后的 `new_value - old_value`。
- `ApplyFun` 的 `tags` 参数为本次求值授予该实体的所有标签集合，类型为 `table<mini_gas.Tag, boolean>`，键为标签，值为 `true`。
- `tags` 与 `attributes` 由库持有所有权，`apply` 返回后会被立即回收；业务方如需跨回调保留，必须在 `apply` 内部复制。

### 6.3 Modifier 聚合

对同一目标实体的同一属性，按 `EModifierOp` 聚合所有生效修改：

- `Add`：累加所有 Add 修改量。
- `Multiply`：连乘所有 Multiply 修改量；若不存在任何 Multiply modifier，则视为乘以 1。
- `Override`：按生效顺序，后者覆盖前者。

计算顺序：

```
base = IEntityModule.get_attribute(entity, id)
if override ~= nil then final = override
else final = (base + add_sum) * multiply_product end
final = clamp(final, min, max)
attributes[id] = final - base
```

### 6.4 Ability 激活条件

- 若 `can_activate` 为空，Ability 默认激活。
- 若为 `AbilityActivateCondition` 对象形式，在世界中统计满足该条件标签约束的实体数量；`include_self` 为 true（默认）时包含当前能力实体自身。当数量大于等于 `requires_count` 时激活。该匹配数量会作为 `ModifierAttributeEval` 末尾可变参数的第一个参数。
- 若为 `AbilityActivateConditionFunc` 函数形式，调用该函数；返回值的 `...` 部分会作为 `ModifierAttributeEval` 末尾可变参数。

### 6.5 Effect 目标范围

- `Self`：候选集合仅包含当前能力实体自身。
- `Other`：候选集合为世界中的所有其他实体。
- `All`：候选集合为世界中的所有实体（包含当前能力实体自身）。

候选集合还会受 EffectDef 自身的 `allof_tags / anyof_tags / noneof_tags` 进一步筛选。

### 6.6 求值流程

`ASC.evaluate(context, apply, ...)` 采用两阶段流程，`IDebug` 通过 `context.debug` 传入：

1. **收集阶段**：遍历世界所有实体作为 `owner`，再遍历每个 Ability；激活的能力以 `[owner_id, ability_id, modifier_args]` 三元组形式存入 `active_abilities`。
2. **应用阶段**：再次遍历世界每个 `target` 实体，遍历 `active_abilities`，将可作用的 `grant_tags` 与 Modifier 结果聚合到该实体的 `tags` / `attributes` 中，最后调用一次 `ApplyFun`。

本次求值中所有标签约束（AbilityActivateCondition、EffectDef、ModifierDef）均只依据实体通过 `IEntityModule` 提供的静态标签进行判断；`grant_tags` 仅作为输出写入 `tags` 集合，不影响同一次 `ASC.evaluate` 内的其它判定。

每个 `target` 实体的 `tags` 与 `attributes` 从对象池取出，应用完毕后清空放回，避免频繁创建临时表。

---

> [返回 Mini-GAS 设计文档总览](./README.md)
