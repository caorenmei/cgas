--- Attribute 与 AttributeSet
local M = {}

---@class mini_gas.AttributeDef
---@field name mini_gas.AttributeId
---@field alias string|integer|nil 策划配置原始 ID；nil 时使用 name 的枚举值
---@field base number
---@field min number|nil
---@field max number|nil
---@field growth mini_gas.GrowthCurve|nil

---@class mini_gas.Attribute
---@field name mini_gas.AttributeId
---@field base number 基础值（受成长曲线影响）
---@field current number 当前值
---@field min number|nil
---@field max number|nil
local Attribute = {}
Attribute.__index = Attribute

---@param name mini_gas.AttributeId
---@param base number
---@param min number|nil
---@param max number|nil
---@return mini_gas.Attribute
function Attribute.new(name, base, min, max)
    return setmetatable({
        name = name,
        base = base or 0,
        current = base or 0,
        min = min,
        max = max,
    }, Attribute)
end

---设置 Base 值
---@param value number
function Attribute:set_base(value)
    self.base = value
    self.current = value
end

---获取 Base 值
---@return number
function Attribute:get_base()
    return self.base
end

---获取 Current 值
---@return number
function Attribute:get_current()
    return self.current
end

---@class mini_gas.AttributeSet
---@field attributes table<mini_gas.AttributeId, mini_gas.Attribute>
local AttributeSet = {}
AttributeSet.__index = AttributeSet

---创建空属性集
---@return mini_gas.AttributeSet
function AttributeSet.new()
    return setmetatable({
        attributes = {},
    }, AttributeSet)
end

---注册属性定义
---@param def mini_gas.AttributeDef
---@return mini_gas.Attribute
function AttributeSet:register(def)
    local base = def.base or 0
    if def.growth then
        base = def.growth:value_at(1)
    end
    local attr = Attribute.new(def.name, base, def.min, def.max)
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
    attr:set_base(growth:value_at(level))
end

M.Attribute = Attribute
M.AttributeSet = AttributeSet
M.clamp = clamp

return M
