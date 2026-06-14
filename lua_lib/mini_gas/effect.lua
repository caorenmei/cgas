--- GameplayEffect 运行时实例
--- 实例为轻量运行时状态表，仅保留 id 与运行时字段，配置通过 defs 查找。
local enum = require("mini_gas.enum")
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
    ---运行时实例仅保留 id 与状态字段，不持有 Def 引用
    return {
        id = def.id,
        stack = stack or def.stack or 1,
        elapsed = 0,
        remaining = initial_remaining(def.duration_policy),
        last_trigger_count = 0,
    }
end

---计算周期间隔
---@param effect mini_gas.GameplayEffect
---@param defs mini_gas.Defs
---@return number
function M.period_value(effect, defs)
    local def = defs.effect_defs[effect.id]
    if not def then
        return 0
    end
    local p = def.period
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
---@param defs mini_gas.Defs
---@param effect mini_gas.GameplayEffect
---@return boolean
function M.meets_tag_requirements(state, defs, effect)
    local def = defs.effect_defs[effect.id]
    if not def then
        return false
    end
    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, blocked)
end

---@deprecated 使用 meets_tag_requirements
M.is_active = M.meets_tag_requirements

return M
