--- GameplayEffect 与 EffectDef
--- GameplayEffect 实例不直接引用 Def，而是通过 spec_id 引用。
local modifier_mod = require("mini_gas.modifier")
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayEffect = {}

---@param spec_id mini_gas.EffectId
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayEffect
function M.GameplayEffect.new(spec_id, level, stack)
    level = level or 1
    stack = stack or 1
    return {
        spec_id = spec_id,
        level = level,
        stack = stack,
        elapsed = 0,
        remaining = math.huge,
        last_trigger_count = 0,
    }
end

---通过 State 查找 EffectDef
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return mini_gas.EffectDef|nil
local function find_def(state, effect)
    return state._effect_defs and state._effect_defs[effect.spec_id]
end

---计算周期间隔
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return number
function M.period_value(state, effect)
    local def = find_def(state, effect)
    if not def then
        return 0
    end
    local p = def.period
    if type(p) == "number" then
        return p
    end
    if type(p) == "function" then
        return p(effect.level)
    end
    return 0
end

---判断效果是否满足标签约束
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return boolean
function M.is_active(state, effect)
    local def = find_def(state, effect)
    if not def then
        return false
    end
    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, blocked)
end

---获取当前 Modifier 列表
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function M.active_modifiers(state, effect)
    local result = {}
    local def = find_def(state, effect)
    if not def then
        return result
    end
    for i = 1, #(def.modifiers or {}) do
        result[#result + 1] = modifier_mod.Modifier.new(effect.spec_id, i, effect.level, effect, effect.stack)
    end
    return result
end

return M
