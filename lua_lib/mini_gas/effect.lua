--- GameplayEffect 运行时实例
--- 实例为轻量运行时状态表，通过 `def` 字段引用外部 Def，不复制 Def 字段。
local enum = require("mini_gas.enum")
local modifier_mod = require("mini_gas.modifier")
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayEffect = {}

---根据持续策略初始化剩余时间
---@param duration_policy mini_gas.EDurationPolicy
---@return number
local function initial_remaining(duration_policy)
    if duration_policy == enum.EDurationPolicy.Instant then
        return 0
    end
    return math.huge
end

---@param def mini_gas.EffectDef
---@param stack number|nil
---@return mini_gas.GameplayEffect
function M.GameplayEffect.new(def, stack)
    ---运行时实例仅保留状态字段，配置字段通过 def 引用读取
    stack = stack or def.stack or 1
    local effect = {
        def = def,
        stack = stack,
        elapsed = 0,
        remaining = initial_remaining(def.duration_policy),
        last_trigger_count = 0,
        modifiers = {},
    }
    for i, mod_def in ipairs(def.modifiers or {}) do
        effect.modifiers[i] = modifier_mod.Modifier.new(mod_def, effect, stack)
    end
    return effect
end

---计算周期间隔
---@param effect mini_gas.GameplayEffect
---@return number
function M.period_value(effect)
    local p = effect.def.period
    if type(p) == "number" then
        return p
    end
    if type(p) == "function" then
        return p(effect)
    end
    return 0
end

---判断效果是否满足标签约束（避免与能力 is_active 状态字段混淆）
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return boolean
function M.meets_tag_requirements(state, effect)
    local def = effect.def
    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, blocked)
end

---@deprecated 使用 meets_tag_requirements
M.is_active = M.meets_tag_requirements

---获取当前 Modifier 列表
---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function M.active_modifiers(effect)
    return effect.modifiers
end

return M
