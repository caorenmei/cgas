
## 5. 类型与枚举定义

所有 LuaCATS 类型声明集中维护于 `lua_lib/mini_gas/types.lua`，枚举运行时值与 `@enum` 注解维护于 `lua_lib/mini_gas/enum.lua`。禁止在业务代码中使用魔术字符串。

> **ID 与策划 Alias**：属性、标签、技能、效果、事件等 ID 均对应策划配置的 `alias`，其值类型为 `string | integer`。`mini-gas` 框架仅预定义其运行所必须的最小核心常量；业务逻辑所需的 ID 应由策划配置并通过 `ConfigAdapter` 映射到项目级 `@enum`，不得在框架层硬编码。

### 5.1 枚举

枚举定义位于 `lua_lib/mini_gas/enum.lua`，并通过 `---@enum` 标注类型。业务代码通过 `mini_gas.EModifierOp`、`mini_gas.EDurationPolicy` 等访问运行时值。

```lua
local EModifierOp = mini_gas.EModifierOp
local EDurationPolicy = mini_gas.EDurationPolicy
local EStackingPolicy = mini_gas.EStackingPolicy
local EAbilityActivationPolicy = mini_gas.EAbilityActivationPolicy
```

### 5.2 ID 别名

```lua
---@alias mini_gas.TagId mini_gas.ETag | string | integer
---@alias mini_gas.AttributeId mini_gas.EAttribute | string | integer
---@alias mini_gas.AbilityId mini_gas.EAbilityId | string | integer
---@alias mini_gas.EffectId mini_gas.EEffectId | string | integer
---@alias mini_gas.GameplayEventId mini_gas.EGameplayEvent | string | integer
---@alias mini_gas.GrowthCurve fun(level: number, ...): number
```

### 5.3 核心类型

> 约定：除 `MiniASC` 这类无状态函数集合外，所有配置对象（Def / Spec / GrowthCurve）与运行时数据对象（Modifier / GameplayEffect / GameplayAbility / GameplayTagContainer / GameplayTask / EntityState / WorldState）的实例均为**无元表的普通 Lua 表**，便于外部配置桥接、序列化与持久化。对象操作统一通过对应模块的函数完成。运行时属性值直接以数字形式存储于 `EntityState.attributes` 中。

#### 5.3.1 标签容器

标签直接使用 `mini_gas.TagId` 字符串/整数值，不封装 `GameplayTag` 对象。

```lua
---@class mini_gas.GameplayTagContainer
---@field tags table<string, table<string, number>> 标签名 -> 来源 -> 引用计数
```

容器操作：

```lua
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source? string
function tag_mod.add(container, tag, source) end

---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source? string
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

标签匹配使用 `string.find` + `string.byte`，避免额外字符串分配：

```lua
---@param a string
---@param b string
---@return boolean
function tag_mod.matches(a, b) end
```

#### 5.3.2 成长曲线

成长曲线是任意公式函数，不强制 `base` / `params` 字段，也不限定仅按等级成长。

```lua
---@alias mini_gas.GrowthCurve fun(level: number, ...): number
```

#### 5.3.3 属性

`EntityState.attributes` 是普通 `table<AttributeId, number>`，不封装 `Attribute` 对象。

```lua
---@class mini_gas.AttributeDef
---@field name mini_gas.AttributeId
---@field alias? string|integer
---@field base? number
---@field min? number
---@field max? number
---@field growth? mini_gas.GrowthCurve
```

#### 5.3.4 修饰器

`ModifierDef.value` 仅支持 `number` 或 `fun(self: Modifier, v: number): number`（用于 `Compound`）。`Modifier` 实例不直接引用 `ModifierDef`，而是通过 `effect_id` + `mod_index` 在 `state._effect_defs[effect_id].modifiers[mod_index]` 中查找对应 Def。

```lua
---@class mini_gas.ModifierDef
---@field attribute mini_gas.AttributeId
---@field op mini_gas.EModifierOp
---@field value number | fun(self: mini_gas.Modifier, v: number): number
---@field priority? number
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]

---@class mini_gas.Modifier
---@field effect_id mini_gas.EffectId
---@field mod_index number
---@field level number
---@field source any
---@field stack? number
```

修饰器操作：

```lua
---@param state mini_gas.EntityState
---@param mod mini_gas.Modifier
---@return number|fun(self: mini_gas.Modifier, v: number): number
function modifier_mod.value(state, mod) end

---@param state mini_gas.EntityState
---@param mod mini_gas.Modifier
---@return boolean
function modifier_mod.is_active(state, mod) end
```

#### 5.3.5 效果

`GameplayEffect` 实例不直接引用 `EffectDef`，而是通过 `spec_id` 引用；`EffectDef` 由 `state._effect_defs[spec_id]` 持有。

```lua
---@class mini_gas.EffectDef
---@field id mini_gas.EffectId
---@field alias? string|integer
---@field duration_policy mini_gas.EDurationPolicy
---@field duration? number | mini_gas.GrowthCurve
---@field period? number | mini_gas.GrowthCurve
---@field modifiers mini_gas.ModifierDef[]
---@field stacking? mini_gas.EStackingPolicy
---@field max_stack? number
---@field granted_tags? mini_gas.TagId[]
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field source any

---@class mini_gas.GameplayEffect
---@field spec_id mini_gas.EffectId
---@field level number
---@field stack number
---@field elapsed number
---@field remaining number
---@field last_trigger_count number
```

效果操作：

```lua
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return boolean
function effect_mod.is_active(state, effect) end

---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function effect_mod.active_modifiers(state, effect) end

---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return number
function effect_mod.period_value(state, effect) end
```

#### 5.3.6 技能

`GameplayAbility` 实例不直接引用 `GameplayAbilityDef`，而是通过 `spec_id` 引用；`GameplayAbilityDef` 由 `state._ability_defs[spec_id]` 持有。

```lua
---@class mini_gas.GameplayAbilityDef
---@field id mini_gas.AbilityId
---@field alias? string|integer
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field cooldown? number | mini_gas.GrowthCurve
---@field cost? table<mini_gas.AttributeId, number | mini_gas.GrowthCurve>
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field grant_tags? mini_gas.TagId[]
---@field activation_event? mini_gas.GameplayEventId
---@field effects? mini_gas.EffectDef[]
---@field source any
---@field can_activate? fun(state: mini_gas.EntityState, payload: table?): boolean?

---@class mini_gas.GameplayAbility
---@field spec_id mini_gas.AbilityId
---@field level number
---@field stack number
---@field is_active boolean
---@field cooldown_remaining number
```

技能操作：

```lua
---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
---@return boolean
function ability_mod.can_activate(state, ability) end

---@param ability mini_gas.GameplayAbility
function ability_mod.activate(ability) end

---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
function ability_mod.end_ability(state, ability) end
```

#### 5.3.7 实体状态

```lua
---@class mini_gas.EntityState
---@field attributes table<mini_gas.AttributeId, number>
---@field _attribute_defs table<mini_gas.AttributeId, mini_gas.AttributeDef>
---@field abilities table<string, mini_gas.GameplayAbility>
---@field _ability_defs table<string, mini_gas.GameplayAbilityDef>
---@field effects table<string, mini_gas.GameplayEffect>
---@field _effect_defs table<string, mini_gas.EffectDef>
---@field tags mini_gas.GameplayTagContainer
---@field event_listeners table<mini_gas.GameplayEventId, fun(payload: table?)[]>
---@field tasks mini_gas.GameplayTask[]
---@field _reactive_listeners table<string, fun(payload: table?)>
---@field source any
```

#### 5.3.8 世界状态

```lua
---@class mini_gas.WorldState
---@field entities table<string, mini_gas.EntityState>
```

注册实体为工具函数：

```lua
---@param world mini_gas.WorldState
---@param id string
---@param state mini_gas.EntityState
function mini_gas.register_entity(world, id, state) end
```

#### 5.3.9 Spec 封装

```lua
---@class mini_gas.AbilitySpec
---@field def_id mini_gas.AbilityId
---@field level number
---@field stack number

---@class mini_gas.EffectSpec
---@field def_id mini_gas.EffectId
---@field level number
---@field stack number

---@class mini_gas.AttributeSpec
---@field def_id mini_gas.AttributeId
---@field level number
```

#### 5.3.10 能力系统组件

`MiniASC` 是**无状态**的函数集合，所有操作均接收 `EntityState` 或 `WorldState` 作为第一个参数。

```lua
---@class mini_gas.MiniASC
local MiniASC = {}

function MiniASC.register_attributes(state, defs) end
function MiniASC.give_ability(state, spec, level, stack?) end
function MiniASC.remove_ability(state, ability_id) end
function MiniASC.set_ability_level(state, ability_id, level) end
function MiniASC.set_ability_stack(state, ability_id, stack) end
function MiniASC.try_activate_ability(state, ability_id, payload?) end
function MiniASC.apply_effect(state, spec, level, stack?) end
function MiniASC.remove_effect(state, effect_id) end
function MiniASC.set_effect_level(state, effect_id, level) end
function MiniASC.set_effect_stack(state, effect_id, stack) end
function MiniASC.add_tag(state, tag) end
function MiniASC.remove_tag(state, tag) end
function MiniASC.has_tag(state, tag) end
function MiniASC.dispatch_event(state, event, payload?) end
function MiniASC.listen_event(state, event, listener) end
function MiniASC.update(state, dt) end
function MiniASC.update_world(world, dt) end
function MiniASC.get_base(state, attr) end
function MiniASC.get_current(state, attr) end
function MiniASC.set_current(state, attr, value) end
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
