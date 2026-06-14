--- mini-gas v2.0 模块入口
--- 类型定义集中管理于 mini_gas.types
local enum = require("mini_gas.enum")
local tag = require("mini_gas.tag")
local modifier = require("mini_gas.modifier")
local effect = require("mini_gas.effect")
local ability = require("mini_gas.ability")
local task = require("mini_gas.task")
local state = require("mini_gas.state")
local asc = require("mini_gas.asc")
local log_mod = require("mini_gas.log")

local M = {}

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

-- 类型构造器
M.GameplayTagContainer = tag.GameplayTagContainer
M.Modifier = modifier.Modifier
M.GameplayEffect = effect.GameplayEffect
M.GameplayAbility = ability.GameplayAbility
M.GameplayTask = task.GameplayTask
M.EntityState = state.EntityState
M.WorldState = state.WorldState
M.Defs = state.Defs
M.register_entity = state.register_entity
M.MiniASC = asc

---注入日志句柄
---@param logger { warn: fun(msg: string) }|nil
function M.set_logger(logger)
    log_mod.set_logger(logger)
end

---将原始配置批量转换为 EffectDef
---@param raw_configs any[]
---@param adapter mini_gas.ConfigAdapter
---@return mini_gas.EffectDef[]
function M.adapt_effects(raw_configs, adapter)
    local result = {}
    for _, raw in ipairs(raw_configs or {}) do
        result[#result + 1] = adapter(raw)
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
        result[#result + 1] = adapter(raw)
    end
    return result
end

---计算单个属性的 Current 值（无状态纯函数）
---@param base number
---@param entity_state mini_gas.EntityState
---@param modifiers mini_gas.Modifier[]
---@return number
function M.calc_attribute(base, entity_state, modifiers)
    return modifier.calc_attribute(base, entity_state, modifiers)
end

return M
