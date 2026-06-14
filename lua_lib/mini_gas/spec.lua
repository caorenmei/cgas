--- Spec 基础结构与成长曲线
local M = {}

---@alias mini_gas.GrowthFormula fun(level: number, base: number, params: table|nil): number

---@class mini_gas.GrowthCurve
---@field base number 基础值
---@field params table|nil 公式参数（如线性系数、指数底数等）
---@field formula mini_gas.GrowthFormula
local GrowthCurve = {}
GrowthCurve.__index = GrowthCurve

---根据等级与公式计算数值
---@param level number
---@return number
function GrowthCurve:value_at(level)
    level = level or 1
    return self.formula(level, self.base, self.params)
end

---@class mini_gas.AbilitySpec
---@field def mini_gas.GameplayAbilityDef
---@field level number
---@field stack number
local AbilitySpec = {}
AbilitySpec.__index = AbilitySpec

---@param def mini_gas.GameplayAbilityDef
---@param level number
---@param stack number
---@return mini_gas.AbilitySpec
function AbilitySpec.new(def, level, stack)
    return setmetatable({
        def = def,
        level = level or 1,
        stack = stack or 1,
    }, AbilitySpec)
end

---@class mini_gas.EffectSpec
---@field def mini_gas.EffectDef
---@field level number
---@field stack number
local EffectSpec = {}
EffectSpec.__index = EffectSpec

---@param def mini_gas.EffectDef
---@param level number
---@param stack number
---@return mini_gas.EffectSpec
function EffectSpec.new(def, level, stack)
    return setmetatable({
        def = def,
        level = level or 1,
        stack = stack or 1,
    }, EffectSpec)
end

---@class mini_gas.AttributeSpec
---@field def mini_gas.AttributeDef
---@field level number
local AttributeSpec = {}
AttributeSpec.__index = AttributeSpec

---@param def mini_gas.AttributeDef
---@param level number
---@return mini_gas.AttributeSpec
function AttributeSpec.new(def, level)
    return setmetatable({
        def = def,
        level = level or 1,
    }, AttributeSpec)
end

---创建成长曲线
---@param base number
---@param params table|nil 公式参数
---@param formula mini_gas.GrowthFormula|nil
---@return mini_gas.GrowthCurve
function M.make_growth_curve(base, params, formula)
    return setmetatable({
        base = base,
        params = params,
        formula = formula or function(_, b, _)
            return b
        end,
    }, GrowthCurve)
end

M.GrowthCurve = GrowthCurve
M.AbilitySpec = AbilitySpec
M.EffectSpec = EffectSpec
M.AttributeSpec = AttributeSpec

return M
