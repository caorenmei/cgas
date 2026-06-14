--- Attribute 与 AttributeSet
--- 类型定义见 mini_gas.types
--- Attribute 实例为无元表的纯数据表，操作通过模块级函数完成。
local M = {}

M.Attribute = {}
M.AttributeSet = {}

---@param name mini_gas.AttributeId
---@param base number
---@param min number|nil
---@param max number|nil
---@return mini_gas.Attribute
function M.Attribute.new(name, base, min, max)
    return {
        name = name,
        base = base or 0,
        current = base or 0,
        min = min,
        max = max,
    }
end

---设置 Base 值
---@param attr mini_gas.Attribute
---@param value number
function M.set_base(attr, value)
    attr.base = value
    attr.current = value
end

---获取 Base 值
---@param attr mini_gas.Attribute
---@return number
function M.get_base(attr)
    return attr.base
end

---获取 Current 值
---@param attr mini_gas.Attribute
---@return number
function M.get_current(attr)
    return attr.current
end

---创建空属性集（纯 Lua 表）
---@return mini_gas.AttributeSet
function M.AttributeSet.new()
    return {
        attributes = {},
        register = M.AttributeSet.register,
    }
end

---注册属性定义
---@param self mini_gas.AttributeSet
---@param def mini_gas.AttributeDef
---@return mini_gas.Attribute
function M.AttributeSet.register(self, def)
    local base = def.base or 0
    if def.growth then
        base = def.growth:value_at(1)
    end
    local attr = M.Attribute.new(def.name, base, def.min, def.max)
    self.attributes[def.name] = attr
    return attr
end

---@param attr mini_gas.Attribute
---@param value number
---@return number
local function clamp(attr, value)
    local result = value
    if attr.min ~= nil and result < attr.min then
        result = attr.min
    end
    if attr.max ~= nil and result > attr.max then
        result = attr.max
    end
    ---@cast result number
    return result
end

---应用成长等级，重算 Base 值
---@param attr mini_gas.Attribute
---@param growth mini_gas.GrowthCurve
---@param level number
function M.apply_growth(attr, growth, level)
    M.set_base(attr, growth:value_at(level))
end

M.clamp = clamp

return M
