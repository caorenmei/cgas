
## 5. 类型与枚举定义

以下所有类型与枚举均使用 LuaCATS 的 `---@class` 与 `---@enum` 语法定义，禁止在业务代码中使用魔术字符串。

> **ID 与策划 Alias**：属性、标签、技能、效果、事件等 ID 均对应策划配置的 `alias`，其值类型为 `string | integer`。`mini-gas` 框架仅预定义其运行所必须的最小核心常量；业务逻辑所需的 ID 应由策划配置并通过 `ConfigAdapter` 映射到项目级 `@enum`，不得在框架层硬编码。

### 5.1 基础枚举

#### 5.1.1 修饰器操作类型

```lua
---@enum mini_gas.EModifierOp
local EModifierOp = {
    Add = 1,            -- 加法，聚合为 sum
    Multiply = 2,       -- 乘法，聚合为 product
    Override = 3,       -- 覆盖，按优先级取最终值
    Compound = 4,       -- 复合公式，由自定义函数计算
}
```

#### 5.1.2 效果生命周期策略

```lua
---@enum mini_gas.EDurationPolicy
local EDurationPolicy = {
    Instant = 1,        -- 瞬时生效，立即修改 Current 后消失
    Infinite = 2,       -- 永久生效，直到被显式移除
    HasDuration = 3,    -- 持续一段时间后自动消失
}
```

#### 5.1.3 效果叠加策略

```lua
---@enum mini_gas.EStackingPolicy
local EStackingPolicy = {
    None = 1,           -- 不可叠加，重复应用时刷新或替换
    Add = 2,            -- Stack 数相加
    Replace = 3,        -- 新效果替换旧效果
    Refresh = 4,        -- 刷新持续时间与 Stack
}
```

#### 5.1.4 技能激活策略

```lua
---@enum mini_gas.EAbilityActivationPolicy
local EAbilityActivationPolicy = {
    Passive = 1,        -- 授予后自动持续生效
    Active = 2,         -- 需要业务方显式调用 TryActivate
    Reactive = 3,       -- 响应特定 GameplayEvent 自动尝试激活
}
```

#### 5.1.5 属性枚举

`mini-gas` 框架不预定义业务属性 ID；以下仅保留占位常量。业务属性 ID 及其 `alias`（`string | integer`）由策划配置，并通过项目级 `@enum` 维护。

```lua
---@enum mini_gas.EAttribute
local EAttribute = {
    None = "attr.none", -- 占位；业务 Attribute ID 由策划配置
}
```

#### 5.1.6 标签枚举

`mini-gas` 框架运行不依赖任何业务标签，因此仅保留占位常量。所有业务标签（如 `state.combat`、`buff.attack_aura`）应由策划配置，并在项目级 `@enum` 中维护，其 `alias` 类型为 `string | integer`。

```lua
---@enum mini_gas.ETag
local ETag = {
    None = "tag.none", -- 占位；业务 Tag 由策划配置
}
```

#### 5.1.7 技能 ID 枚举

`mini-gas` 框架不预定义业务技能 ID；以下仅保留占位常量。业务技能 ID 及其 `alias`（`string | integer`）由策划配置，并在项目级 `@enum` 中维护。

```lua
---@enum mini_gas.EAbilityId
local EAbilityId = {
    None = "ability.none", -- 占位；业务 Ability ID 由策划配置
}
```

#### 5.1.8 效果 ID 枚举

`mini-gas` 框架不预定义业务效果 ID；以下仅保留占位常量。业务效果 ID 及其 `alias`（`string | integer`）由策划配置，并在项目级 `@enum` 中维护。

```lua
---@enum mini_gas.EEffectId
local EEffectId = {
    None = "effect.none", -- 占位；业务 Effect ID 由策划配置
}
```

#### 5.1.9 游戏事件枚举

`mini-gas` 框架仅预定义其内部生命周期相关事件；业务事件（如 `event.damage.taken`）应由策划配置并在项目级 `@enum` 中维护，其 `alias` 类型为 `string | integer`。

```lua
---@enum mini_gas.EGameplayEvent
local EGameplayEvent = {
    AbilityActivated = "event.ability.activated",
    AbilityEnded = "event.ability.ended",
    EffectApplied = "event.effect.applied",
    EffectRemoved = "event.effect.removed",
    AttributeChanged = "event.attribute.changed",
    TagAdded = "event.tag.added",
    TagRemoved = "event.tag.removed",
}
```

### 5.2 核心类型

> 约定：除 `MiniASC` 这类无状态函数集合外，所有配置对象（Def / Spec / GrowthCurve）与运行时数据对象（Attribute / Modifier / GameplayEffect / GameplayAbility / GameplayTag / GameplayTagContainer / GameplayTask / EntityState / WorldState）的实例均为**无元表的普通 Lua 表**，便于外部配置桥接、序列化与持久化。对象操作统一通过对应模块的函数完成，所有 LuaCATS 类型定义集中维护于 `lua_lib/mini_gas/types.lua`。

#### 5.2.1 游戏标签

```lua
---@class mini_gas.GameplayTag
---@field name string 标签完整名称
```

标签构造与匹配：

```lua
---@param tag mini_gas.TagId
---@return mini_gas.GameplayTag
function tag_mod.GameplayTag.new(tag) end

---判断标签是否匹配（精确或父级）
---@param tag mini_gas.GameplayTag
---@param other mini_gas.GameplayTag
---@return boolean
function tag_mod.matches(tag, other) end
```

#### 5.2.2 标签容器

```lua
---@class mini_gas.GameplayTagContainer
---@field tags table<string, mini_gas.GameplayTag>
---@field counts table<string, table<string, number>> 按来源引用计数
```

容器操作：

```lua
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source string|nil
function tag_mod.add(container, tag, source) end

---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source string|nil
function tag_mod.remove(container, tag, source) end

---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@return boolean
function tag_mod.has(container, tag) end

---@param container mini_gas.GameplayTagContainer
---@param tags mini_gas.TagId[]
---@return boolean
function tag_mod.has_any(container, tags) end

---@param container mini_gas.GameplayTagContainer
---@param tags mini_gas.TagId[]
---@return boolean
function tag_mod.has_all(container, tags) end
```

#### 5.2.3 成长曲线

成长曲线**必须通过公式计算**，禁止内置等级查表。公式接收当前等级 `level`、基础值 `base` 与参数表 `params`，返回当前数值。

```lua
---@alias mini_gas.GrowthFormula fun(level: number, base: number, params: table|nil): number

---@class mini_gas.GrowthCurve
---@field base number 基础值
---@field params table|nil 公式参数
---@field formula mini_gas.GrowthFormula
---@field value_at fun(self: mini_gas.GrowthCurve, level: number): number
```

`value_at` 作为普通函数字段存储于 plain table 中。

#### 5.2.4 属性定义

```lua
---@class mini_gas.AttributeDef
---@field name mini_gas.AttributeId
---@field alias string|integer|nil 策划配置原始 ID；nil 时使用 name 的枚举值
---@field base number
---@field min number|nil
---@field max number|nil
---@field growth mini_gas.GrowthCurve|nil
```

#### 5.2.5 属性实例

```lua
---@class mini_gas.Attribute
---@field name mini_gas.AttributeId
---@field base number 基础值
---@field current number 当前已提交值
---@field min number|nil
---@field max number|nil
```

属性操作：

```lua
---@param attr mini_gas.Attribute
---@param value number
function attribute_mod.set_base(attr, value) end

---@param attr mini_gas.Attribute
---@return number
function attribute_mod.get_base(attr) end

---@param attr mini_gas.Attribute
---@return number
function attribute_mod.get_current(attr) end
```

`AttributeSet` 是对 `Attribute` 实例的批量管理工具（`attribute_mod.AttributeSet`），业务方可按需使用；`MiniASC` 直接操作 `state.attributes`，不依赖 `AttributeSet`。

#### 5.2.6 修饰器定义

```lua
---@class mini_gas.ModifierDef
---@field attribute mini_gas.AttributeId
---@field op mini_gas.EModifierOp
---@field value number|mini_gas.GrowthCurve|fun(v: number): number
---@field priority number|nil 仅 Override/Compound 时使用
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil
```

#### 5.2.7 修饰器实例

```lua
---@class mini_gas.Modifier
---@field def mini_gas.ModifierDef
---@field level number
---@field source any
---@field stack number|nil
```

修饰器操作：

```lua
---@param mod mini_gas.Modifier
---@return number|fun(v: number): number
function modifier_mod.value(mod) end

---@param mod mini_gas.Modifier
---@param container mini_gas.GameplayTagContainer|nil
---@return boolean
function modifier_mod.is_active(mod, container) end
```

#### 5.2.8 效果定义

```lua
---@class mini_gas.EffectDef
---@field id mini_gas.EffectId
---@field alias string|integer|nil
---@field duration_policy mini_gas.EDurationPolicy
---@field duration number|mini_gas.GrowthCurve|nil 单位：秒
---@field period number|mini_gas.GrowthCurve|nil 单位：秒
---@field modifiers mini_gas.ModifierDef[]
---@field stacking mini_gas.EStackingPolicy|nil
---@field max_stack number|nil
---@field granted_tags mini_gas.TagId[]|nil
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil
---@field source any
```

#### 5.2.9 效果实例

```lua
---@class mini_gas.GameplayEffect
---@field spec mini_gas.EffectDef
---@field level number
---@field stack number
---@field elapsed number
---@field remaining number
---@field last_trigger_count number
```

效果操作：

```lua
---@param effect mini_gas.GameplayEffect
---@param container mini_gas.GameplayTagContainer|nil
---@return boolean
function effect_mod.is_active(effect, container) end

---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function effect_mod.active_modifiers(effect) end

---@param effect mini_gas.GameplayEffect
---@return number
function effect_mod.period_value(effect) end
```

#### 5.2.10 技能定义

```lua
---@class mini_gas.GameplayAbilityDef
---@field id mini_gas.AbilityId
---@field alias string|integer|nil
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field cooldown number|mini_gas.GrowthCurve|nil
---@field cost table<mini_gas.AttributeId, number|mini_gas.GrowthCurve>|nil
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil
---@field grant_tags mini_gas.TagId[]|nil
---@field activation_event mini_gas.GameplayEventId|nil Reactive 时使用
---@field effects mini_gas.EffectDef[]|nil 激活时自动应用的效果
---@field source any
---@field can_activate? fun(state: mini_gas.EntityState, payload: table|nil): boolean|nil
```

#### 5.2.11 技能实例

```lua
---@class mini_gas.GameplayAbility
---@field spec mini_gas.GameplayAbilityDef
---@field level number
---@field stack number
---@field is_active boolean
---@field cooldown_remaining number
```

技能操作：

```lua
---@param ability mini_gas.GameplayAbility
---@param state mini_gas.EntityState
---@return boolean
function ability_mod.can_activate(ability, state) end

---@param ability mini_gas.GameplayAbility
---@param state mini_gas.EntityState
---@param payload table|nil
function ability_mod.activate(ability, state, payload) end

---@param ability mini_gas.GameplayAbility
---@param state mini_gas.EntityState
function ability_mod.end_ability(ability, state) end
```

#### 5.2.12 实体状态

`EntityState` 是无元表的纯 Lua 表，由业务方创建并持有，便于序列化与持久化。`mini-gas` 库本身不维护任何状态，所有状态均通过 `EntityState` 参数传递。

```lua
---@class mini_gas.EntityState
---@field attributes table<mini_gas.AttributeId, mini_gas.Attribute>
---@field abilities table<string, mini_gas.GameplayAbility>
---@field effects table<string, mini_gas.GameplayEffect>
---@field tags mini_gas.GameplayTagContainer
---@field event_listeners table<mini_gas.GameplayEventId, fun(payload:table|nil)[]>
---@field tasks mini_gas.GameplayTask[]
---@field _reactive_listeners table<string, fun(payload:table|nil)>
---@field source any
```

#### 5.2.13 世界状态

`WorldState` 是无元表的 `table<EntityId, EntityState>`，由业务方创建并持有，用于管理多个实体状态，便于批量更新与统一序列化。`mini-gas` 不通过 `WorldState` 维护跨实体链接，实体间的相互影响仍通过 **Tag** 与共享的 `EntityState` 实现。

```lua
---@class mini_gas.WorldState
---@field entities table<string, mini_gas.EntityState>
---@field register_entity fun(self: mini_gas.WorldState, id: string, state: mini_gas.EntityState)
```

`register_entity` 作为普通函数字段内嵌于 plain table 中。

#### 5.2.14 能力系统组件

`MiniASC` 是**无状态**的函数集合，所有操作均接收 `EntityState` 或 `WorldState` 作为第一个参数，执行计算后返回结果或修改传入的状态。

```lua
---@class mini_gas.MiniASC
local MiniASC = {}

---注册属性定义
---@param state mini_gas.EntityState
---@param defs mini_gas.AttributeDef[]
function MiniASC.register_attributes(state, defs) end

---授予技能
---@param state mini_gas.EntityState
---@param spec mini_gas.GameplayAbilityDef
---@param level number
---@param stack number|nil
function MiniASC.give_ability(state, spec, level, stack) end

---移除技能
---@param state mini_gas.EntityState
---@param ability_id mini_gas.EAbilityId
function MiniASC.remove_ability(state, ability_id) end

---设置技能等级
---@param state mini_gas.EntityState
---@param ability_id mini_gas.EAbilityId
---@param level number
function MiniASC.set_ability_level(state, ability_id, level) end

---设置技能 Stack
---@param state mini_gas.EntityState
---@param ability_id mini_gas.EAbilityId
---@param stack number
function MiniASC.set_ability_stack(state, ability_id, stack) end

---尝试激活技能
---@param state mini_gas.EntityState
---@param ability_id mini_gas.EAbilityId
---@param payload table|nil
---@return boolean
function MiniASC.try_activate_ability(state, ability_id, payload) end

---应用效果
---@param state mini_gas.EntityState
---@param spec mini_gas.EffectDef
---@param level number
---@param stack number|nil
function MiniASC.apply_effect(state, spec, level, stack) end

---移除效果
---@param state mini_gas.EntityState
---@param effect_id mini_gas.EEffectId
function MiniASC.remove_effect(state, effect_id) end

---设置效果等级
---@param state mini_gas.EntityState
---@param effect_id mini_gas.EEffectId
---@param level number
function MiniASC.set_effect_level(state, effect_id, level) end

---设置效果 Stack
---@param state mini_gas.EntityState
---@param effect_id mini_gas.EEffectId
---@param stack number
function MiniASC.set_effect_stack(state, effect_id, stack) end

---添加标签
---@param state mini_gas.EntityState
---@param tag mini_gas.ETag
function MiniASC.add_tag(state, tag) end

---移除标签
---@param state mini_gas.EntityState
---@param tag mini_gas.ETag
function MiniASC.remove_tag(state, tag) end

---判断标签容器是否包含某标签
---@param state mini_gas.EntityState
---@param tag mini_gas.ETag
---@return boolean
function MiniASC.has_tag(state, tag) end

---派发事件
---@param state mini_gas.EntityState
---@param event mini_gas.EGameplayEvent
---@param payload table|nil
function MiniASC.dispatch_event(state, event, payload) end

---监听事件
---@param state mini_gas.EntityState
---@param event mini_gas.EGameplayEvent
---@param listener fun(payload:table|nil)
function MiniASC.listen_event(state, event, listener) end

---更新状态
---@param state mini_gas.EntityState
---@param dt number 秒
function MiniASC.update(state, dt) end

---批量更新世界状态
---@param world mini_gas.WorldState
---@param dt number 秒
function MiniASC.update_world(world, dt) end

---获取属性 Base 值
---@param state mini_gas.EntityState
---@param attr mini_gas.EAttribute
---@return number
function MiniASC.get_base(state, attr) end

---获取属性 Current 值
---@param state mini_gas.EntityState
---@param attr mini_gas.EAttribute
---@return number
function MiniASC.get_current(state, attr) end

---设置属性 Current 值
---@param state mini_gas.EntityState
---@param attr mini_gas.EAttribute
---@param value number
function MiniASC.set_current(state, attr, value) end
```

---

---

> [返回 Mini-GAS 设计文档总览](./README.md)
