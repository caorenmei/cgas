--- GameplayEffect 运行时实例
--- 实例为自包含普通 Lua 表，不引用外部 Def。
local modifier_mod = require("mini_gas.modifier")
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayEffect = {}

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

---@param spec mini_gas.EffectDef
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayEffect
function M.GameplayEffect.new(spec, level, stack)
    level = level or 1
    stack = stack or 1
    local effect = {
        id = spec.id,
        alias = spec.alias,
        duration_policy = spec.duration_policy,
        duration = spec.duration,
        period = spec.period,
        stacking = spec.stacking,
        max_stack = spec.max_stack,
        granted_tags = copy_array(spec.granted_tags),
        require_tags = copy_array(spec.require_tags),
        blocked_tags = copy_array(spec.blocked_tags),
        source = spec.source,
        level = level,
        stack = stack,
        elapsed = 0,
        remaining = math.huge,
        last_trigger_count = 0,
        modifiers = {},
    }
    for i, mod_def in ipairs(spec.modifiers or {}) do
        effect.modifiers[i] = modifier_mod.Modifier.new(mod_def, level, effect, stack)
    end
    return effect
end

---计算周期间隔
---@param effect mini_gas.GameplayEffect
---@return number
function M.period_value(effect)
    local p = effect.period
    if type(p) == "number" then
        return p
    end
    if type(p) == "function" then
        return p(effect)
    end
    return 0
end

---判断效果是否满足标签约束
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return boolean
function M.is_active(state, effect)
    local container = state.tags
    local req = effect.require_tags or {}
    local blocked = effect.blocked_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, blocked)
end

---获取当前 Modifier 列表
---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function M.active_modifiers(effect)
    return effect.modifiers
end

return M
