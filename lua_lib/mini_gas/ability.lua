--- GameplayAbility 与 AbilitySpec
--- 类型定义见 mini_gas.types
--- GameplayAbility 实例为无元表的纯数据表，操作通过模块级函数完成。
local attribute_mod = require("mini_gas.attribute")
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayAbility = {}

---@param spec mini_gas.GameplayAbilityDef
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayAbility
function M.GameplayAbility.new(spec, level, stack)
    return {
        spec = spec,
        level = level or 1,
        stack = stack or 1,
        is_active = false,
        cooldown_remaining = 0,
    }
end

---解析数值（可能是常量或成长曲线）
---@param value number|mini_gas.GrowthCurve
---@param level number
---@return number
local function resolve_value(value, level)
    if type(value) == "number" then
        return value
    end
    if type(value) == "table" and value.value_at then
        return value:value_at(level)
    end
    return 0
end

---检查当前是否可以激活
---@param ability mini_gas.GameplayAbility
---@param state mini_gas.EntityState
---@return boolean
function M.can_activate(ability, state)
    if ability.is_active then
        return false
    end
    if ability.cooldown_remaining > 0 then
        return false
    end

    local container = state.tags
    local req = ability.spec.require_tags or {}
    local forbid = ability.spec.forbid_tags or {}
    if not tag_mod.has_all(container, req) or tag_mod.has_any(container, forbid) then
        return false
    end

    -- 消耗检查
    if ability.spec.cost then
        for attr_id, cost_value in pairs(ability.spec.cost) do
            local attr = state.attributes[attr_id]
            if not attr then
                return false
            end
            local need = resolve_value(cost_value, ability.level)
            if attribute_mod.get_current(attr) < need then
                return false
            end
        end
    end

    if ability.spec.can_activate then
        local ok = ability.spec.can_activate(state, nil)
        if ok == false then
            return false
        end
    end

    return true
end

---激活技能
---@param ability mini_gas.GameplayAbility
---@param _state mini_gas.EntityState
---@param _payload table|nil
function M.activate(ability, _state, _payload)
    _ = _state
    _ = _payload
    ability.is_active = true
end

---结束技能
---@param ability mini_gas.GameplayAbility
---@param _state mini_gas.EntityState
function M.end_ability(ability, _state)
    _ = _state
    ability.is_active = false
    ability.cooldown_remaining = resolve_value(ability.spec.cooldown, ability.level)
end

M.resolve_value = resolve_value

return M
