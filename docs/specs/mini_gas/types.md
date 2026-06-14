
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
```

### 5.3 核心类型

> **状态自包含约定**：`EntityState` / `WorldState` / `Modifier` / `GameplayEffect` / `GameplayAbility` / `GameplayTask` 的实例均为**无元表的普通 Lua 表**，且**不得引用任何外部对象**（包括配置 Def、其他运行时实例、下划线隐藏的查找表等）。所有运行时数据在创建时即自包含完整副本，可直接序列化、持久化与网络同步。对象操作统一通过对应模块的函数完成。

#### 5.3.1 配置定义表 `Defs`

`Defs` 由调用方持有，包含所有静态配置定义。需要读取配置或注册新 Def 的 API 会接收 `defs` 参数。

```lua
---@class mini_gas.Defs
---@field attribute_defs table<mini_gas.AttributeId, mini_gas.AttributeDef>
---@field ability_defs table<mini_gas.AbilityId, mini_gas.GameplayAbilityDef>
---@field effect_defs table<mini_gas.EffectId, mini_gas.EffectDef>
```

创建：

```lua
local defs = mini_gas.Defs.new()
```

#### 5.3.2 标签容器

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

#### 5.3.3 属性

`EntityState.attributes` 是普通 `table<AttributeId, number>`，不封装 `Attribute` 对象。

`AttributeDef` 不再定义成长公式，属性成长由外部系统负责（例如通过 `set_current` 或直接修改 `state.attributes`）。

```lua
---@class mini_gas.AttributeDef
---@field name mini_gas.AttributeId
---@field alias? string|integer
---@field base? number
---@field min? number
---@field max? number
```

#### 5.3.4 修饰器

`ModifierDef.value` 仅支持 `number` 或 `fun(self: Modifier, v: number): number`（用于 `Compound`）。

`Modifier` 实例是**自包含**的运行时数据，保存完整的 Modifier 配置与运行时字段，不引用外部 Def。

```lua
---@class mini_gas.ModifierDef
---@field attribute mini_gas.AttributeId
---@field op mini_gas.EModifierOp
---@field value number | fun(self: mini_gas.Modifier, v: number): number
---@field priority? number
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]

---@class mini_gas.Modifier
---@field attribute mini_gas.AttributeId
---@field op mini_gas.EModifierOp
---@field value number | fun(self: mini_gas.Modifier, v: number): number
---@field priority? number
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field level number
---@field source any
---@field stack? number
```

修饰器操作：

```lua
---@param mod mini_gas.Modifier
---@return number|fun(self: mini_gas.Modifier, v: number): number|nil
function modifier_mod.value(mod) end

---@param state mini_gas.EntityState
---@param mod mini_gas.Modifier
---@return boolean
function modifier_mod.is_active(state, mod) end
```

#### 5.3.5 效果

`EffectDef` 是静态配置；`GameplayEffect` 实例是**自包含**的运行时数据，保存完整的 Effect 配置与运行时字段，并在创建时把 `ModifierDef[]` 转换为 `Modifier[]`。

`duration` / `period` 支持常量或公式函数 `fun(self: GameplayEffect, ...): number`。

```lua
---@class mini_gas.EffectDef
---@field id mini_gas.EffectId
---@field alias? string|integer
---@field duration_policy mini_gas.EDurationPolicy
---@field duration? number | fun(self: mini_gas.GameplayEffect, ...): number
---@field period? number | fun(self: mini_gas.GameplayEffect, ...): number
---@field modifiers mini_gas.ModifierDef[]
---@field stacking? mini_gas.EStackingPolicy
---@field max_stack? number
---@field granted_tags? mini_gas.TagId[]
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field source any

---@class mini_gas.GameplayEffect
---@field id mini_gas.EffectId
---@field alias? string|integer
---@field duration_policy mini_gas.EDurationPolicy
---@field duration? number | fun(self: mini_gas.GameplayEffect, ...): number
---@field period? number | fun(self: mini_gas.GameplayEffect, ...): number
---@field modifiers mini_gas.Modifier[]
---@field stacking? mini_gas.EStackingPolicy
---@field max_stack? number
---@field granted_tags? mini_gas.TagId[]
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field source any
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

---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function effect_mod.active_modifiers(effect) end

---@param effect mini_gas.GameplayEffect
---@return number
function effect_mod.period_value(effect) end
```

#### 5.3.6 技能

`GameplayAbilityDef` 是静态配置；`GameplayAbility` 实例是**自包含**的运行时数据，保存完整的 Ability 配置与运行时字段。

`cooldown` / `cost[attr]` 支持常量或公式函数 `fun(self: GameplayAbility, ...): number`。

```lua
---@class mini_gas.GameplayAbilityDef
---@field id mini_gas.AbilityId
---@field alias? string|integer
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field cooldown? number | fun(self: mini_gas.GameplayAbility, ...): number
---@field cost? table<mini_gas.AttributeId, number | fun(self: mini_gas.GameplayAbility, ...): number>
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field grant_tags? mini_gas.TagId[]
---@field activation_event? mini_gas.GameplayEventId
---@field effects? mini_gas.EffectDef[]
---@field can_activate? fun(state: mini_gas.EntityState, payload: table?): boolean?
---@field source any

---@class mini_gas.GameplayAbility
---@field id mini_gas.AbilityId
---@field alias? string|integer
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field cooldown? number | fun(self: mini_gas.GameplayAbility, ...): number
---@field cost? table<mini_gas.AttributeId, number | fun(self: mini_gas.GameplayAbility, ...): number>
---@field require_tags? mini_gas.TagId[]
---@field blocked_tags? mini_gas.TagId[]
---@field grant_tags? mini_gas.TagId[]
---@field activation_event? mini_gas.GameplayEventId
---@field effects? mini_gas.EffectDef[]
---@field can_activate? fun(state: mini_gas.EntityState, payload: table?): boolean?
---@field source any
---@field stack number
---@field is_active boolean
---@field cooldown_remaining number
---@field listener? fun(payload:table?)
```

技能操作：

```lua
---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
---@return boolean
function ability_mod.can_activate(state, ability) end

---@param ability mini_gas.GameplayAbility
function ability_mod.activate(ability) end

---@param ability mini_gas.GameplayAbility
function ability_mod.end_ability(ability) end
```

#### 5.3.7 实体状态

`EntityState` 不持有任何配置定义或下划线查找表。

```lua
---@class mini_gas.EntityState
---@field attributes table<mini_gas.AttributeId, number>
---@field abilities table<string, mini_gas.GameplayAbility>
---@field effects table<string, mini_gas.GameplayEffect>
---@field tags mini_gas.GameplayTagContainer
---@field event_listeners table<mini_gas.GameplayEventId, fun(payload: table?)[]>
---@field tasks mini_gas.GameplayTask[]
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

#### 5.3.9 能力系统组件

`MiniASC` 是**无状态**的函数集合。需要读取或注册 Def 的操作接收 `defs` 作为第二个参数；其余操作保持简洁签名。

```lua
---@class mini_gas.MiniASC
local MiniASC = {}

function MiniASC.register_attributes(state, defs, attr_defs) end
function MiniASC.give_ability(state, defs, ability_def, stack?) end
function MiniASC.remove_ability(state, ability_id) end
function MiniASC.set_ability_stack(state, ability_id, stack) end
function MiniASC.try_activate_ability(state, defs, ability_id, payload?) end
function MiniASC.apply_effect(state, defs, effect_def, stack?) end
function MiniASC.remove_effect(state, effect_id) end
function MiniASC.set_effect_stack(state, effect_id, stack) end
function MiniASC.add_tag(state, tag) end
function MiniASC.remove_tag(state, tag) end
function MiniASC.has_tag(state, tag) end
function MiniASC.dispatch_event(state, event, payload?) end
function MiniASC.listen_event(state, event, listener) end
function MiniASC.update(state, defs, dt) end
function MiniASC.update_world(world, defs, dt) end
function MiniASC.get_base(state, attr) end
function MiniASC.get_current(state, defs, attr) end
function MiniASC.set_current(state, defs, attr, value) end
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
