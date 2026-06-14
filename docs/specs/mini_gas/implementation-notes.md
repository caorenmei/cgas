
## 11. 实现要点

1. **纯 Lua 表**：不依赖任何外部库，除 Lua 标准库外无依赖。
2. **无状态库**：`mini-gas` 不维护任何运行时状态，所有状态由调用方通过 `EntityState` 或 `WorldState` 传入并持有，便于序列化、持久化与网络同步。
3. **代码自包含**：`lua_lib/mini_gas` 下所有文件不得引用任何外部 GAS 库。
4. **状态完全自包含**：`Modifier` / `GameplayEffect` / `GameplayAbility` / `GameplayTask` / `EntityState` / `WorldState` 的实例不得引用任何外部对象（包括配置 Def、下划线查找表、其他运行时实例）。运行时数据在创建时复制完整的 Def 信息。
5. **Defs 分离**：配置定义集中存放在 `mini_gas.Defs` 中，由调用方持有，并在需要的 API 调用中传入。
6. **数值稳定**：Modifier 聚合顺序固定，避免浮点误差导致结果不稳定。
7. **效果去重与 Stack**：同一 `effect_id` 重复应用时，按 `EStackingPolicy` 处理，避免重复实例堆积。
8. **惰性计算**：`get_current` 每次读取时重新聚合 Modifier，保证标签变化能即时反映。
9. **错误隔离**：非法 Modifier（目标属性不存在、未知 op）记录警告并不中断其他计算。
10. **事件解耦**：技能、效果、属性、标签的变化均通过事件通知，避免模块间直接耦合。
11. **等级与 Stack 动态更新**：支持运行时通过 `set_ability_level` / `set_ability_stack` / `set_effect_level` / `set_effect_stack` 改变 Ability / Effect 的等级与层数，并即时重算数值。
12. **冷却与消耗原子性**：技能激活时，冷却与消耗应作为一个原子操作，避免扣除消耗后激活失败导致状态不一致。
13. **策划 Alias 映射**：所有业务 ID（属性、标签、技能、效果、事件）的 `alias` 类型为 `string | integer`，由策划配置并通过 `ConfigAdapter` 映射到项目级 `@enum`；框架层不硬编码业务常量。
14. **按类型公式函数**：不定义通用 `GrowthCurve`。`AbilityDef.cooldown/cost`、`EffectDef.duration/period`、`ModifierDef.value`（Compound）分别使用 `fun(self: GameplayAbility, ...)`、`fun(self: GameplayEffect, ...)`、`fun(self: Modifier, v: number)` 签名。
15. **属性成长外置**：`AttributeDef` 不定义公式，属性 Base 值与成长由外部系统负责。
16. **标签驱动加成**：优先通过 `Granted Tag` 与 `Require / Block Tag` 实现效果的赋予与条件生效，避免引入额外的跨实体链接机制。
17. **配置与状态无元表**：所有配置对象（Def）、运行时状态（EntityState / WorldState）以及运行时数据对象（Modifier / GameplayEffect / GameplayAbility / GameplayTagContainer / GameplayTask）的实例均使用无元表的普通 Lua 表。`GameplayAbility` / `GameplayEffect` 的运行时实例保留运行时生成的 `id`（实例 ID）与 `def_id`（配置 ID），通过 `def_id` 从 `Defs` 表查找配置；`Modifier` 实例包含于 `GameplayEffect` 中，仅保留 `def_id`、`index` 与 `stack`。运行时属性值仅存储为 `EntityState.attributes` 中的普通数字，不再使用 Attribute 对象。
18. **类型与枚举分离**：LuaCATS 类型定义集中于 `types.lua`；枚举定义使用 `---@enum` 注解，集中定义于 `enum.lua`。业务与框架模块通过引用这些类型获得静态检查。

---

## 13. 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-06-14 | 初始版本，仅包含 Attribute / Modifier / Effect / Context |
| v2.0 | 2026-06-14 | 重构为独立 GAS 核心；新增 Ability / Tag；目录调整为 `lua_lib/mini_gas`；业务 ID 由策划 alias（`string \| integer`）配置；`MiniASC` 改为无状态函数集合，状态由 `EntityState` / `WorldState` 外置；运行时实例保留实例 `id` 与 `def_id`，通过 `Defs` 查找配置；`Modifier` 包含于 `GameplayEffect` 中；配置定义由 `Defs` 持有并传入；效果通过 Granted / Require / Block Tag 驱动 |

---

> [返回 Mini-GAS 设计文档总览](./README.md)
