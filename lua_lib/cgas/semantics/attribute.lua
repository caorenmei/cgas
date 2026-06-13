--- Attribute 系统 — 属性与修饰器聚合

local M = {}

---@alias cgas.semantics.ModifierOp "add"|"multiply"|"divide"|"override"

---@class cgas.semantics.Modifier
---@field attribute_name string
---@field op cgas.semantics.ModifierOp
---@field magnitude number
---@field source_handle integer?

---@class cgas.semantics.Attribute
---@field name string
---@field base_value number
---@field current_value number
---@field min_value number?
---@field max_value number?
---@field is_meta boolean
---@field on_base_changed fun(oldv: number, newv: number)?
---@field on_current_changed fun(oldv: number, newv: number)?
local Attribute = {}
Attribute.__index = Attribute
M.Attribute = Attribute

---创建新属性
---@param name string
---@param base_value number
---@param opts table?
---@return cgas.semantics.Attribute
function Attribute.new(name, base_value, opts)
    opts = opts or {}
    local self = setmetatable({}, Attribute)
    self.name = name
    self.base_value = base_value
    self.current_value = base_value
    self.min_value = opts.min_value
    self.max_value = opts.max_value
    self.is_meta = opts.is_meta or false
    self.on_base_changed = nil
    self.on_current_changed = nil
    return self
end

---设置基础值并触发回调
---@param value number
function Attribute:set_base(value)
    local old = self.base_value
    self.base_value = value
    if self.on_base_changed then
        self.on_base_changed(old, value)
    end
end

---重新计算当前值：base → add → multiply → divide → override → clamp
---@param modifiers cgas.semantics.Modifier[]
function Attribute:recalculate(modifiers)
    local value = self.base_value
    local override = nil

    for _, mod in ipairs(modifiers) do
        if mod.attribute_name == self.name then
            if mod.op == "add" then
                value = value + mod.magnitude
            elseif mod.op == "multiply" then
                value = value * mod.magnitude
            elseif mod.op == "divide" then
                value = value / mod.magnitude
            elseif mod.op == "override" then
                override = mod.magnitude
            end
        end
    end

    if override ~= nil then
        value = override
    end

    -- clamp
    if self.min_value ~= nil and value < self.min_value then
        value = self.min_value --[[@as number]]
    end
    if self.max_value ~= nil and value > self.max_value then
        value = self.max_value --[[@as number]]
    end

    local old = self.current_value
    self.current_value = value
    if self.on_current_changed then
        self.on_current_changed(old, value)
    end
end

---@class cgas.semantics.AttributeSet
---@field name string
---@field attributes table<string, cgas.semantics.Attribute>
local AttributeSet = {}
AttributeSet.__index = AttributeSet
M.AttributeSet = AttributeSet

---创建属性集
---@param name string
---@return cgas.semantics.AttributeSet
function AttributeSet.new(name)
    local self = setmetatable({}, AttributeSet)
    self.name = name
    self.attributes = {}
    return self
end

---注册属性
---@param name string
---@param base_value number
---@param opts table?
function AttributeSet:register_attribute(name, base_value, opts)
    self.attributes[name] = Attribute.new(name, base_value, opts)
end

---获取属性
---@param name string
---@return cgas.semantics.Attribute?
function AttributeSet:get(name)
    return self.attributes[name]
end

---遍历属性
---@return fun(): string, cgas.semantics.Attribute
function AttributeSet:iter()
    local iter_fn = pairs(self.attributes)
    return iter_fn
end

return M
