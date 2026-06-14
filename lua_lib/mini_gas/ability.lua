--- GameplayAbility 运行时实例
--- 实例为自包含普通 Lua 表，不引用外部 Def。
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayAbility = {}

---浅拷贝数组
---@param arr any[]|nil
---@return any[]
local function copy_array(arr)
    local result = {}
    for i, v in ipairs(arr or {}) do
        result[i] = v
    end
    return result
end

---浅拷贝普通表（不递归，保留函数引用）
---@param t table|nil
---@return table
local function shallow_copy(t)
    local result = {}
    for k, v in pairs(t or {}) do
        result[k] = v
    end
    return result
end

---@param def mini_gas.GameplayAbilityDef
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayAbility
function M.GameplayAbility.new(def, level, stack)
    level = level or 1
    stack = stack or 1
    return {
        id = def.id,
        alias = def.alias,
        activation_policy = def.activation_policy,
        cooldown = def.cooldown,
        cost = shallow_copy(def.cost),
        require_tags = copy_array(def.require_tags),
        blocked_tags = copy_array(def.blocked_tags),
        grant_tags = copy_array(def.grant_tags),
        activation_event = def.activation_event,
        effects = copy_array(def.effects),
        can_activate = def.can_activate,
        source = def.source,
        level = level,
        stack = stack,
        is_active = false,
        cooldown_remaining = 0,
        listener = nil,
        spawned_effects = {},
    }
end

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

    local container = state.tags
    local req = ability.require_tags or {}
    local blocked = ability.blocked_tags or {}
    if not tag_mod.has_all(container, req) or tag_mod.has_any(container, blocked) then
        return false
    end

    if ability.cost then
        for attr_id, cost_value in pairs(ability.cost) do
            local current = state.attributes[attr_id] or 0
            local need = resolve_value(cost_value, ability)
            if current < need then
                return false
            end
        end
    end

    if ability.can_activate then
        local ok = ability.can_activate(state, payload)
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
    ability.cooldown_remaining = resolve_value(ability.cooldown or 0, ability)
end

M.resolve_value = resolve_value

return M
