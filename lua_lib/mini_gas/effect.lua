--- GameplayEffect 与 EffectDef
--- 类型定义见 mini_gas.types
local enum = require("mini_gas.enum")
local modifier_mod = require("mini_gas.modifier")

local M = {}

local GameplayEffect = {}
GameplayEffect.__index = GameplayEffect

---@param spec mini_gas.EffectDef
---@param level number
---@param stack number|nil
---@return mini_gas.GameplayEffect
function GameplayEffect.new(spec, level, stack)
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
    return setmetatable({
        spec = spec,
        level = level,
        stack = stack,
        elapsed = 0,
        remaining = remaining,
        last_trigger_count = 0,
    }, GameplayEffect)
end

---判断效果是否满足标签约束
---@param container mini_gas.GameplayTagContainer|nil
---@return boolean
function GameplayEffect:is_active(container)
    if not container then
        return true
    end
    local req = self.spec.require_tags or {}
    local forbid = self.spec.forbid_tags or {}
    return container:has_all(req) and not container:has_any(forbid)
end

---获取当前等级与 Stack 下的实际 Modifier 列表
---@return mini_gas.Modifier[]
function GameplayEffect:active_modifiers()
    local result = {}
    for _, def in ipairs(self.spec.modifiers or {}) do
        table.insert(result, modifier_mod.Modifier.new(def, self.level, self, self.stack))
    end
    return result
end

---计算周期间隔
---@return number
function GameplayEffect:period_value()
    local p = self.spec.period
    if type(p) == "number" then
        return p
    end
    if type(p) == "table" and p.value_at then
        return p:value_at(self.level)
    end
    return 0
end

M.GameplayEffect = GameplayEffect

return M
