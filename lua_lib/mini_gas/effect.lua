--- GameplayEffect 与 EffectDef
--- 类型定义见 mini_gas.types
--- GameplayEffect 实例为无元表的纯数据表，操作通过模块级函数完成。
local enum = require("mini_gas.enum")
local modifier_mod = require("mini_gas.modifier")
local tag_mod = require("mini_gas.tag")

local M = {}

M.GameplayEffect = {}

---@param spec mini_gas.EffectDef
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayEffect
function M.GameplayEffect.new(spec, level, stack)
    level = level or 1
    stack = stack or 1
    local remaining = math.huge
    if spec.duration_policy == enum.EDurationPolicy.HasDuration then
        local d = spec.duration or 0
        if type(d) == "number" then
            remaining = d
        elseif type(d) == "table" and d.value_at then
            remaining = d:value_at(level)
        end
    end
    return {
        spec = spec,
        level = level,
        stack = stack,
        elapsed = 0,
        remaining = remaining,
        last_trigger_count = 0,
    }
end

---判断效果是否满足标签约束
---@param effect mini_gas.GameplayEffect
---@param container mini_gas.GameplayTagContainer|nil
---@return boolean
function M.is_active(effect, container)
    if not container then
        return true
    end
    local req = effect.spec.require_tags or {}
    local forbid = effect.spec.forbid_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, forbid)
end

---获取当前等级与 Stack 下的实际 Modifier 列表
---@param effect mini_gas.GameplayEffect
---@return mini_gas.Modifier[]
function M.active_modifiers(effect)
    local result = {}
    for _, def in ipairs(effect.spec.modifiers or {}) do
        table.insert(result, modifier_mod.Modifier.new(def, effect.level, effect, effect.stack))
    end
    return result
end

---计算周期间隔
---@param effect mini_gas.GameplayEffect
---@return number
function M.period_value(effect)
    local p = effect.spec.period
    if type(p) == "number" then
        return p
    end
    if type(p) == "table" and p.value_at then
        return p:value_at(effect.level)
    end
    return 0
end

return M
