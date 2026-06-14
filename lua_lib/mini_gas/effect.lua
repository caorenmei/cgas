--- GameplayEffect 运行时实例
--- 实例为自包含普通 Lua 表，不引用外部 Def。
local enum = require("mini_gas.enum")
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
    ---子类可在 def 中携带 level 等成长字段，基类不再自动注入 level
    local effect = shallow_copy(def)
    -- 数组字段深拷贝一层，避免运行时修改影响 Def
    effect.granted_tags = copy_array(def.granted_tags)
    effect.require_tags = copy_array(def.require_tags)
    effect.blocked_tags = copy_array(def.blocked_tags)
    -- 运行时状态字段
    stack = stack or def.stack or 1
    effect.stack = stack
    effect.elapsed = 0
    effect.remaining = initial_remaining(def.duration_policy)
    effect.last_trigger_count = 0
    effect.modifiers = {}
    for i, mod_def in ipairs(def.modifiers or {}) do
        effect.modifiers[i] = modifier_mod.Modifier.new(mod_def, effect, stack)
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

---判断效果是否满足标签约束（避免与能力 is_active 状态字段混淆）
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@return boolean
function M.meets_tag_requirements(state, effect)
    local container = state.tags
    local req = effect.require_tags or {}
    local blocked = effect.blocked_tags or {}
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
