--- mini-gas v2.0 类型定义集中文件
--- 本文件仅用于 LuaCATS 类型声明，不执行运行时逻辑。
--- 枚举类型定义于 enum.lua，本文件仅引用。

---@meta

---业务 ID 兼容别名
---@alias mini_gas.TagId mini_gas.ETag | string | integer
---@alias mini_gas.AttributeId mini_gas.EAttribute | string | integer
---@alias mini_gas.AbilityId mini_gas.EAbilityId | string | integer
---@alias mini_gas.EffectId mini_gas.EEffectId | string | integer
---@alias mini_gas.GameplayEventId mini_gas.EGameplayEvent | string | integer

---@class mini_gas.Defs
---@field attribute_defs table<mini_gas.AttributeId, mini_gas.AttributeDef>
---@field ability_defs table<mini_gas.AbilityId, mini_gas.GameplayAbilityDef>
---@field effect_defs table<mini_gas.EffectId, mini_gas.EffectDef>

---@class mini_gas.AttributeDef
---@field name mini_gas.AttributeId
---@field alias? string|integer
---@field base? number
---@field min? number
---@field max? number

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
---@field level number
---@field stack number
---@field elapsed number
---@field remaining number
---@field last_trigger_count number

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
---@field level number
---@field stack number
---@field is_active boolean
---@field cooldown_remaining number
---@field listener? fun(payload:table?)

---@class mini_gas.GameplayTask
---@field kind "delay"|"periodic"|"wait_event"
---@field remaining number
---@field interval number
---@field event? mini_gas.GameplayEventId
---@field callback fun(payload:table?)|fun(dt:number)|nil
---@field repeat_count? number
---@field completed boolean
---@field listener? fun(payload:table?)

---@class mini_gas.EntityState
---@field attributes table<mini_gas.AttributeId, number>
---@field abilities table<string, mini_gas.GameplayAbility>
---@field effects table<string, mini_gas.GameplayEffect>
---@field tags mini_gas.GameplayTagContainer
---@field event_listeners table<mini_gas.GameplayEventId, fun(payload: table?)[]>
---@field tasks mini_gas.GameplayTask[]
---@field source any

---@class mini_gas.GameplayTagContainer
---@field tags table<string, table<string, number>>

---@class mini_gas.WorldState
---@field entities table<string, mini_gas.EntityState>

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

---@alias mini_gas.ConfigAdapter fun(raw_config: any): mini_gas.GameplayAbilityDef|mini_gas.EffectDef|mini_gas.AttributeDef

-- 占位返回
return {}
