--- GameplayAbility 运行时实例
--- 实例为轻量运行时状态表，通过 `def` 字段引用外部 Def，不复制 Def 字段。
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayAbility = {}

---解析数值（常量或公式函数）
---@param value number | fun(self: mini_gas.GameplayAbility, ...): number
---@param self mini_gas.GameplayAbility
---@return number
local function resolve_value(value, self)
    if type(value) == "number" then
        return value
    end
    if type(value) == "function" then
        return value(self)
    end
    return 0
end

---@param def mini_gas.GameplayAbilityDef
---@param stack number|nil
---@return mini_gas.GameplayAbility
function M.GameplayAbility.new(def, stack)
    ---运行时实例仅保留状态字段，配置字段通过 def 引用读取
    return {
        def = def,
        stack = stack or def.stack or 1,
        is_active = false,
        cooldown_remaining = 0,
        listener = nil,
        spawned_effects = {},
    }
end

---检查当前是否可以激活
---@param state mini_gas.EntityState
---@param ability mini_gas.GameplayAbility
---@param payload table|nil
---@return boolean
function M.can_activate(state, ability, payload)
    if ability.is_active then
        return false
    end
    if ability.cooldown_remaining > 0 then
        return false
    end

    local def = ability.def
    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    if not tag_mod.has_all(container, req) or tag_mod.has_any(container, blocked) then
        return false
    end

    if def.cost then
        for attr_id, cost_value in pairs(def.cost) do
            local current = state.attributes[attr_id] or 0
            local need = resolve_value(cost_value, ability)
            if current < need then
                return false
            end
        end
    end

    if def.can_activate then
        local ok = def.can_activate(state, payload)
        if ok == false then
            return false
        end
    end

    return true
end

---激活技能
---@param ability mini_gas.GameplayAbility
---@return boolean ok
function M.activate(ability)
    if ability.is_active then
        return false
    end
    ability.is_active = true
    return true
end

---结束技能
---@param ability mini_gas.GameplayAbility
function M.end_ability(ability)
    ability.is_active = false
    ability.cooldown_remaining = resolve_value(ability.def.cooldown or 0, ability)
end

M.resolve_value = resolve_value

return M
