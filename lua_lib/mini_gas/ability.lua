--- GameplayAbility 与 AbilitySpec
--- GameplayAbility 实例不直接引用 Def，而是通过 spec_id 引用。
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayAbility = {}

---@param spec_id mini_gas.AbilityId
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayAbility
function M.GameplayAbility.new(spec_id, level, stack)
    return {
        spec_id = spec_id,
        level = level or 1,
        stack = stack or 1,
        is_active = false,
        cooldown_remaining = 0,
    }
end

---通过 State 查找 AbilityDef
---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
---@return mini_gas.GameplayAbilityDef|nil
local function find_def(state, ability)
    return state._ability_defs and state._ability_defs[ability.spec_id]
end

---解析数值（常量或成长函数）
---@param value number | mini_gas.GrowthCurve
---@param level number
---@return number
local function resolve_value(value, level)
    if type(value) == "number" then
        return value
    end
    if type(value) == "function" then
        return value(level)
    end
    return 0
end

---检查当前是否可以激活
---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
---@return boolean
function M.can_activate(state, ability)
    if ability.is_active then
        return false
    end
    if ability.cooldown_remaining > 0 then
        return false
    end

    local def = find_def(state, ability)
    if not def then
        return false
    end

    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    if not tag_mod.has_all(container, req) or tag_mod.has_any(container, blocked) then
        return false
    end

    if def.cost then
        for attr_id, cost_value in pairs(def.cost) do
            local current = state.attributes[attr_id] or 0
            local need = resolve_value(cost_value, ability.level)
            if current < need then
                return false
            end
        end
    end

    if def.can_activate then
        local ok = def.can_activate(state, nil)
        if ok == false then
            return false
        end
    end

    return true
end

---激活技能
---@param ability mini_gas.GameplayAbility
function M.activate(ability)
    ability.is_active = true
end

---结束技能
---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
function M.end_ability(state, ability)
    local def = find_def(state, ability)
    ability.is_active = false
    ability.cooldown_remaining = resolve_value(def and def.cooldown or 0, ability.level)
end

M.resolve_value = resolve_value

return M
