--- Spec 基础结构与成长曲线
--- 配置类对象均为无元表的普通 Lua 表。
local M = {}

M.AbilitySpec = {}
M.EffectSpec = {}
M.AttributeSpec = {}

---创建成长曲线（返回公式函数本身）
---@param formula mini_gas.GrowthCurve
---@return mini_gas.GrowthCurve
function M.make_growth_curve(formula)
    return formula
end

---创建 AbilitySpec
---@param def_id mini_gas.AbilityId
---@param level number
---@param stack number
---@return mini_gas.AbilitySpec
function M.AbilitySpec.new(def_id, level, stack)
    return {
        def_id = def_id,
        level = level or 1,
        stack = stack or 1,
    }
end

---创建 EffectSpec
---@param def_id mini_gas.EffectId
---@param level number
---@param stack number
---@return mini_gas.EffectSpec
function M.EffectSpec.new(def_id, level, stack)
    return {
        def_id = def_id,
        level = level or 1,
        stack = stack or 1,
    }
end

---创建 AttributeSpec
---@param def_id mini_gas.AttributeId
---@param level number
---@return mini_gas.AttributeSpec
function M.AttributeSpec.new(def_id, level)
    return {
        def_id = def_id,
        level = level or 1,
    }
end

return M
