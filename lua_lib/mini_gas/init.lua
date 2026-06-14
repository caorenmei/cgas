--- mini-gas v2.0 模块入口
local enum = require("mini_gas.enum")
local spec = require("mini_gas.spec")
local tag = require("mini_gas.tag")
local attribute = require("mini_gas.attribute")
local modifier = require("mini_gas.modifier")
local effect = require("mini_gas.effect")
local ability = require("mini_gas.ability")
local task = require("mini_gas.task")
local state = require("mini_gas.state")
local asc = require("mini_gas.asc")

---@class mini_gas
local M = {}

---@alias mini_gas.ConfigAdapter fun(raw_config: any): mini_gas.GameplayAbilityDef|mini_gas.EffectDef|mini_gas.AttributeDef

-- 枚举
M.EModifierOp = enum.EModifierOp
M.EDurationPolicy = enum.EDurationPolicy
M.EStackingPolicy = enum.EStackingPolicy
M.EAbilityActivationPolicy = enum.EAbilityActivationPolicy
M.EAttribute = enum.EAttribute
M.ETag = enum.ETag
M.EAbilityId = enum.EAbilityId
M.EEffectId = enum.EEffectId
M.EGameplayEvent = enum.EGameplayEvent

-- 类型
M.GrowthCurve = spec.GrowthCurve
M.AbilitySpec = spec.AbilitySpec
M.EffectSpec = spec.EffectSpec
M.AttributeSpec = spec.AttributeSpec
M.GameplayTag = tag.GameplayTag
M.GameplayTagContainer = tag.GameplayTagContainer
M.Attribute = attribute.Attribute
M.AttributeSet = attribute.AttributeSet
M.Modifier = modifier.Modifier
M.GameplayEffect = effect.GameplayEffect
M.GameplayAbility = ability.GameplayAbility
M.GameplayTask = task.GameplayTask
M.EntityState = state.EntityState
M.WorldState = state.WorldState
M.MiniASC = asc

---将原始配置批量转换为 EffectDef
---@param raw_configs any[]
---@param adapter mini_gas.ConfigAdapter
---@return mini_gas.EffectDef[]
function M.adapt_effects(raw_configs, adapter)
    local result = {}
    for _, raw in ipairs(raw_configs or {}) do
        table.insert(result, adapter(raw))
    end
    return result
end

---将原始配置批量转换为 AbilityDef
---@param raw_configs any[]
---@param adapter mini_gas.ConfigAdapter
---@return mini_gas.GameplayAbilityDef[]
function M.adapt_abilities(raw_configs, adapter)
    local result = {}
    for _, raw in ipairs(raw_configs or {}) do
        table.insert(result, adapter(raw))
    end
    return result
end

---计算单个属性的 Current 值（无状态纯函数）
---@param base number
---@param modifiers mini_gas.Modifier[]
---@param container mini_gas.GameplayTagContainer|nil
---@return number
function M.calc_attribute(base, modifiers, container)
    return modifier.calc_attribute(base, modifiers, container)
end

---创建成长曲线
---@param base number
---@param params table|nil
---@param formula mini_gas.GrowthFormula|nil
---@return mini_gas.GrowthCurve
function M.make_growth_curve(base, params, formula)
    return spec.make_growth_curve(base, params, formula)
end

return M
