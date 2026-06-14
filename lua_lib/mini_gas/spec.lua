--- Spec 基础结构与成长曲线
--- 配置类对象均为无元表的普通 Lua 表，便于序列化与外部配置桥接。
local M = {}

M.AbilitySpec = {}
M.EffectSpec = {}
M.AttributeSpec = {}

---创建成长曲线（纯 Lua 表）
---@param base number
---@param params table|nil 公式参数
---@param formula mini_gas.GrowthFormula|nil
---@return mini_gas.GrowthCurve
function M.make_growth_curve(base, params, formula)
    return {
        base = base,
        params = params,
        formula = formula or function(_, b, _)
            return b
        end,
        value_at = function(self, level)
            level = level or 1
            return self.formula(level, self.base, self.params)
        end,
    }
end

---创建 AbilitySpec（纯 Lua 表）
---@param def mini_gas.GameplayAbilityDef
---@param level number
---@param stack number
---@return mini_gas.AbilitySpec
function M.AbilitySpec.new(def, level, stack)
    return {
        def = def,
        level = level or 1,
        stack = stack or 1,
    }
end

---创建 EffectSpec（纯 Lua 表）
---@param def mini_gas.EffectDef
---@param level number
---@param stack number
---@return mini_gas.EffectSpec
function M.EffectSpec.new(def, level, stack)
    return {
        def = def,
        level = level or 1,
        stack = stack or 1,
    }
end

---创建 AttributeSpec（纯 Lua 表）
---@param def mini_gas.AttributeDef
---@param level number
---@return mini_gas.AttributeSpec
function M.AttributeSpec.new(def, level)
    return {
        def = def,
        level = level or 1,
    }
end

return M
