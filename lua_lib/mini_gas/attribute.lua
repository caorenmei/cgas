--- Attribute 工具函数
--- attributes 为 plain table: state.attributes[attr_id] = number
local M = {}

---根据定义对数值做 Clamp
---@param def mini_gas.AttributeDef
---@param value number
---@return number
function M.clamp(def, value)
    if def.min and value < def.min then
        return def.min
    end
    if def.max and value > def.max then
        return def.max
    end
    return value
end

---计算初始 Base 值
---@param def mini_gas.AttributeDef
---@param level number
---@return number
function M.calc_base(def, level)
    if def.growth then
        return def.growth(level)
    end
    return def.base or 0
end

return M
