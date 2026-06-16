
## 6. 核心机制

### 6.1 层级标签

标签采用点分层级结构，例如 `state.dead`、`effect.burning`。父级标签匹配所有子级标签：`state` 匹配 `state.dead`，`state.dead` 不匹配 `state.stunned`。

匹配规则由库提供的 `match_tag`、`entity_match_tag`、`match_tags` 实现。

### 6.2 属性初始值与边界约束

- 在 `Defs.attribute_defs` 中定义的属性，若 `AttributeDef.default` 存在，则初始值为 `default`；若省略，则初始值为 0。
- 不在 `Defs.attribute_defs` 中定义的属性，默认初始值为 0，且不检查最大值和最小值约束。
- 库在聚合所有生效的 Modifier 后，会按 `Defs.attribute_defs[id]` 中的 `min` 与 `max` 对最终值做截断；未定义 `min` 或 `max` 时，对应方向不限制。
- 最终传给 `IEvaluation.apply` 的 `attr_changes` 中每个条目的 `value` 已经是截断后的 `new_value - old_value`（add 语义），按 owner 级别聚合。
- `IEvaluation.apply` 的 `tags` 参数为当前 owner 授予的所有标签集合，类型为 `table<mini_gas.Tag, boolean>`，键为标签，值为 `true`。
- `tags` 与 `attr_changes` 由库持有所有权，`apply` 返回后会被立即回收；业务方如需跨回调保留，必须在 `apply` 内部复制。

### 6.3 Modifier 聚合

对同一目标实体的同一属性，按 `EModifierOp` 聚合所有生效修改：

- `Add`：累加所有 Add 修改量。
- `Multiply`：连乘所有 Multiply 修改量。
- `Override`：按生效顺序，后者覆盖前者。

计算顺序：

```
final = (base + add_sum) * multiply_product
if override ~= nil then final = override end
final = clamp(final, min, max)
value = final - base
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

`ASC.evaluate(context, world, world_module, defs, evaluation, ...)` 的执行流程：

1. 遍历世界中的每个实体，作为当前能力实体（owner）。
2. 在 owner 级别累积所有 Ability / Effect / Modifier 产生的授予标签与属性修改。
3. 对每个能力实体，遍历其静态 Ability；评估激活条件时会同时传入 `world_module` 与 `entity_module`。
4. 如果 Ability 激活，则遍历其引用的 EffectDef。
5. 根据 `EffectDef.target` 确定候选目标实体集合，并用 EffectDef 的标签约束筛选。
6. 对目标实体累积要授予的标签。
7. 对目标实体按 Modifier 标签约束解析属性修改，并在 owner 级别按 `EModifierOp` 聚合。
8. owner 的所有 Ability 处理完毕后，调用 `IEvaluation.apply`，传递聚合后的标签集合 `tags` 与属性变化数组 `attr_changes`。

可选的 `begin_ability / end_ability / begin_effect / end_effect / begin_modifier / end_modifier` 回调会在对应阶段触发，用于日志或副作用。

---

> [返回 Mini-GAS 设计文档总览](./README.md)
