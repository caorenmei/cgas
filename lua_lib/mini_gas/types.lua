--- mini-gas v2.0 类型定义集中文件
--- 本文件仅用于 LuaCATS 类型声明，不执行运行时逻辑。

---@meta

---@enum mini_gas.EModifierOp
local EModifierOp = {
    Add = 1,
    Multiply = 2,
    Override = 3,
    Compound = 4,
}

---@enum mini_gas.EDurationPolicy
local EDurationPolicy = {
    Instant = 1,
    Infinite = 2,
    HasDuration = 3,
}

---@enum mini_gas.EStackingPolicy
local EStackingPolicy = {
    None = 1,
    Add = 2,
    Replace = 3,
    Refresh = 4,
}

---@enum mini_gas.EAbilityActivationPolicy
local EAbilityActivationPolicy = {
    Passive = 1,
    Active = 2,
    Reactive = 3,
}

---@enum mini_gas.EAttribute
local EAttribute = {
    None = "attr.none",
}

---@enum mini_gas.ETag
local ETag = {
    None = "tag.none",
}

---@enum mini_gas.EAbilityId
local EAbilityId = {
    None = "ability.none",
}

---@enum mini_gas.EEffectId
local EEffectId = {
    None = "effect.none",
}

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

---业务 ID 兼容别名，alias 类型为 string | integer
---@alias mini_gas.TagId mini_gas.ETag | string | integer
---@alias mini_gas.AttributeId mini_gas.EAttribute | string | integer
---@alias mini_gas.AbilityId mini_gas.EAbilityId | string | integer
---@alias mini_gas.EffectId mini_gas.EEffectId | string | integer
---@alias mini_gas.GameplayEventId mini_gas.EGameplayEvent | string | integer

---@class mini_gas.GameplayTag
---@field name string

---@class mini_gas.GameplayTagContainer
---@field tags table<string, mini_gas.GameplayTag>
---@field counts table<string, table<string, number>>

---@alias mini_gas.GrowthFormula fun(level: number, base: number, params: table|nil): number

---@class mini_gas.GrowthCurve
---@field base number
---@field params table|nil
---@field formula mini_gas.GrowthFormula
---@field value_at fun(self: mini_gas.GrowthCurve, level: number): number

---@class mini_gas.AttributeDef
---@field name mini_gas.AttributeId
---@field alias string|integer|nil
---@field base number
---@field min number|nil
---@field max number|nil
---@field growth mini_gas.GrowthCurve|nil

---@class mini_gas.Attribute
---@field name mini_gas.AttributeId
---@field base number
---@field current number
---@field min number|nil
---@field max number|nil

---@class mini_gas.AttributeSet
---@field attributes table<mini_gas.AttributeId, mini_gas.Attribute>

---@class mini_gas.ModifierDef
---@field attribute mini_gas.AttributeId
---@field op mini_gas.EModifierOp
---@field value number|mini_gas.GrowthCurve|fun(v: number): number
---@field priority number|nil
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil

---@class mini_gas.Modifier
---@field def mini_gas.ModifierDef
---@field level number
---@field source any
---@field stack number|nil

---@class mini_gas.EffectDef
---@field id mini_gas.EffectId
---@field alias string|integer|nil
---@field duration_policy mini_gas.EDurationPolicy
---@field duration number|mini_gas.GrowthCurve|nil
---@field period number|mini_gas.GrowthCurve|nil
---@field modifiers mini_gas.ModifierDef[]
---@field stacking mini_gas.EStackingPolicy|nil
---@field max_stack number|nil
---@field granted_tags mini_gas.TagId[]|nil
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil
---@field source any

---@class mini_gas.GameplayEffect
---@field spec mini_gas.EffectDef
---@field level number
---@field stack number
---@field elapsed number
---@field remaining number
---@field last_trigger_count number

---@class mini_gas.GameplayAbilityDef
---@field id mini_gas.AbilityId
---@field alias string|integer|nil
---@field activation_policy mini_gas.EAbilityActivationPolicy
---@field cooldown number|mini_gas.GrowthCurve|nil
---@field cost table<mini_gas.AttributeId, number|mini_gas.GrowthCurve>|nil
---@field require_tags mini_gas.TagId[]|nil
---@field forbid_tags mini_gas.TagId[]|nil
---@field grant_tags mini_gas.TagId[]|nil
---@field activation_event mini_gas.GameplayEventId|nil
---@field effects mini_gas.EffectDef[]|nil
---@field source any
---@field can_activate? fun(state: mini_gas.EntityState, payload: table|nil): boolean|nil

---@class mini_gas.GameplayAbility
---@field spec mini_gas.GameplayAbilityDef
---@field level number
---@field stack number
---@field is_active boolean
---@field cooldown_remaining number

---@class mini_gas.GameplayTask
---@field kind "delay"|"periodic"|"wait_event"
---@field remaining number
---@field interval number
---@field event mini_gas.GameplayEventId|nil
---@field callback fun(payload:table|nil)|fun(dt:number)|nil
---@field repeat_count number|nil
---@field completed boolean
---@field _listener fun(payload:table|nil)|nil

---@class mini_gas.EntityState
---@field attributes table<mini_gas.AttributeId, mini_gas.Attribute>
---@field abilities table<string, mini_gas.GameplayAbility>
---@field effects table<string, mini_gas.GameplayEffect>
---@field tags mini_gas.GameplayTagContainer
---@field event_listeners table<mini_gas.GameplayEventId, fun(payload:table|nil)[]>
---@field tasks mini_gas.GameplayTask[]
---@field _reactive_listeners table<string, fun(payload:table|nil)>
---@field source any

---@class mini_gas.WorldState
---@field entities table<string, mini_gas.EntityState>

---@class mini_gas.AbilitySpec
---@field def mini_gas.GameplayAbilityDef
---@field level number
---@field stack number

---@class mini_gas.EffectSpec
---@field def mini_gas.EffectDef
---@field level number
---@field stack number

---@class mini_gas.AttributeSpec
---@field def mini_gas.AttributeDef
---@field level number

---@alias mini_gas.ConfigAdapter fun(raw_config: any): mini_gas.GameplayAbilityDef|mini_gas.EffectDef|mini_gas.AttributeDef

-- 占位返回，避免空模块在某些环境下被优化掉
return {
    EModifierOp = EModifierOp,
    EDurationPolicy = EDurationPolicy,
    EStackingPolicy = EStackingPolicy,
    EAbilityActivationPolicy = EAbilityActivationPolicy,
    EAttribute = EAttribute,
    ETag = ETag,
    EAbilityId = EAbilityId,
    EEffectId = EEffectId,
    EGameplayEvent = EGameplayEvent,
}
