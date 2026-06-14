--- Modifier 与属性聚合逻辑
--- 类型定义见 mini_gas.types
local enum = require("mini_gas.enum")

local M = {}

local Modifier = {}
Modifier.__index = Modifier

---@param def mini_gas.ModifierDef
---@param level number
---@param source any
---@param stack number|nil
---@return mini_gas.Modifier
function Modifier.new(def, level, source, stack)
    return setmetatable({
        def = def,
        level = level or 1,
        source = source,
        stack = stack,
    }, Modifier)
end

---获取当前等级下的实际数值或复合函数
---@return number|fun(v: number): number
function Modifier:value()
    local v = self.def.value
    if type(v) == "number" then
        return v
    end
    if type(v) == "function" then
        return v
    end
    if type(v) == "table" and v.value_at then
        return v:value_at(self.level)
    end
    M.warn("非法 Modifier 数值类型: " .. tostring(v))
    return 0
end

---判断 Modifier 是否满足标签约束
---@param container mini_gas.GameplayTagContainer|nil
---@return boolean
function Modifier:is_active(container)
    if not container then
        return true
    end
    local req = self.def.require_tags or {}
    local forbid = self.def.forbid_tags or {}
    return container:has_all(req) and not container:has_any(forbid)
end

---记录警告
---@param msg string
function M.warn(msg)
    io.stderr:write("[mini_gas.warn] " .. msg .. "\n")
end

---计算单个属性的 Current 值（无状态纯函数）
---@param base number
---@param modifiers mini_gas.Modifier[]
---@param container mini_gas.GameplayTagContainer|nil
---@return number
function M.calc_attribute(base, modifiers, container)
    local add_sum = 0
    local multiply_product = 1
    local overrides = {}
    local compounds = {}

    for _, mod in ipairs(modifiers or {}) do
        if mod.def.attribute == nil then
            M.warn("Modifier 缺少目标 attribute")
            goto continue
        end

        if not mod:is_active(container) then
            goto continue
        end

        local op = mod.def.op
        if op == enum.EModifierOp.Compound then
            table.insert(compounds, { fn = mod.def.value, priority = mod.def.priority or 0 })
        else
            local val = mod:value()
            ---@cast val number
            if mod.stack and op == enum.EModifierOp.Add then
                val = val * mod.stack
            end

            if op == enum.EModifierOp.Add then
                add_sum = add_sum + val
            elseif op == enum.EModifierOp.Multiply then
                multiply_product = multiply_product * val
            elseif op == enum.EModifierOp.Override then
                table.insert(overrides, { value = val, priority = mod.def.priority or 0 })
            else
                M.warn("未知 Modifier 操作类型: " .. tostring(op))
            end
        end

        ::continue::
    end

    local result = base
    result = result + add_sum
    result = result * multiply_product

    if #overrides > 0 then
        table.sort(overrides, function(a, b)
            return a.priority > b.priority
        end)
        result = overrides[1].value
    end

    if #compounds > 0 then
        table.sort(compounds, function(a, b)
            return a.priority > b.priority
        end)
        for _, c in ipairs(compounds) do
            if type(c.fn) == "function" then
                result = c.fn(result)
            else
                M.warn("Compound Modifier 的 value 必须是函数")
            end
        end
    end

    return result
end

M.Modifier = Modifier

return M
