--- GameplayAbility 运行时实例
--- 实例包含运行时生成的唯一 id 与 def_id，不直接持有 Def 引用。
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayAbility = {}

local next_instance_id = 1

---生成运行时实例唯一 ID
---@return integer
local function generate_instance_id()
    local id = next_instance_id
    next_instance_id = id + 1
    return id
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

---@param def mini_gas.GameplayAbilityDef
---@param stack number|nil
---@return mini_gas.GameplayAbility
function M.GameplayAbility.new(def, stack)
    ---运行时实例保留实例 id、def_id 与状态字段，不持有 Def 引用
    return {
        id = generate_instance_id(),
        def_id = def.id,
        stack = stack or def.stack or 1,
        is_active = false,
        cooldown_remaining = 0,
        listener = nil,
        spawned_effects = {},
    }
end

---检查当前是否可以激活
---@param state mini_gas.EntityState
---@param defs mini_gas.Defs
---@param ability mini_gas.GameplayAbility
---@param payload table|nil
---@return boolean
function M.can_activate(state, defs, ability, payload)
    if ability.is_active then
        return false
    end
    if ability.cooldown_remaining > 0 then
        return false
    end

    local def = defs.ability_defs[ability.def_id]
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
---@param defs mini_gas.Defs
function M.end_ability(ability, defs)
    ability.is_active = false
    local def = defs.ability_defs[ability.def_id]
    ability.cooldown_remaining = resolve_value(def and def.cooldown or 0, ability)
end

M.resolve_value = resolve_value

return M
