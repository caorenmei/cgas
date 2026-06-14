--- Modifier 与属性聚合逻辑
--- Modifier 实例为轻量运行时状态表，通过 `def` 字段引用外部 ModifierDef，不复制 Def 字段。
local enum = require("mini_gas.enum")
local tag_mod = require("mini_gas.tag")
local log_mod = require("mini_gas.log")

local M = {}

M.Modifier = {}

---创建轻量 Modifier 实例
---@param mod_def mini_gas.ModifierDef
---@param source any
---@param stack number|nil
---@return mini_gas.Modifier
function M.Modifier.new(mod_def, source, stack)
    ---运行时实例仅保留状态字段，配置字段通过 def 引用读取
    return {
        def = mod_def,
        source = source,
        stack = stack,
    }
end

---获取当前数值或复合函数
---@param mod mini_gas.Modifier
---@return number|fun(self: mini_gas.Modifier, v: number): number|nil
function M.value(mod)
    return mod.def.value
end

---判断 Modifier 是否满足标签约束
---@param state mini_gas.EntityState
---@param mod mini_gas.Modifier
---@return boolean
function M.is_active(state, mod)
    local def = mod.def
    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, blocked)
end

---计算单个属性的 Current 值（无状态纯函数）
---@param base number
---@param state mini_gas.EntityState
---@param modifiers mini_gas.Modifier[]
---@return number
function M.calc_attribute(base, state, modifiers)
    local add_sum = 0
    local multiply_product = 1
    local overrides = {}
    local compounds = {}

    for _, mod in ipairs(modifiers or {}) do
        if not M.is_active(state, mod) then
            goto continue
        end

        local def = mod.def
        local op = def.op
        if op == enum.EModifierOp.Compound then
            compounds[#compounds + 1] = { fn = def.value, priority = def.priority or 0, mod = mod }
        else
            local val = def.value
            if type(val) == "function" then
                log_mod.warn("非 Compound Modifier 的 value 不能是函数")
                goto continue
            end
            ---@cast val number
            if mod.stack and op == enum.EModifierOp.Add then
                val = val * mod.stack
            end

            if op == enum.EModifierOp.Add then
                add_sum = add_sum + val
            elseif op == enum.EModifierOp.Multiply then
                multiply_product = multiply_product * val
            elseif op == enum.EModifierOp.Override then
                overrides[#overrides + 1] = { value = val, priority = def.priority or 0 }
            else
                log_mod.warn("未知 Modifier 操作类型: " .. tostring(op))
            end
        end

        ::continue::
    end

    local result = base
    result = result + add_sum
    result = result * multiply_product

    if #overrides > 0 then
        -- 按优先级降序
        for i = 1, #overrides - 1 do
            for j = i + 1, #overrides do
                if overrides[i].priority < overrides[j].priority then
                    overrides[i], overrides[j] = overrides[j], overrides[i]
                end
            end
        end
        result = overrides[1].value
    end

    if #compounds > 0 then
        for i = 1, #compounds - 1 do
            for j = i + 1, #compounds do
                if compounds[i].priority < compounds[j].priority then
                    compounds[i], compounds[j] = compounds[j], compounds[i]
                end
            end
        end
        for _, c in ipairs(compounds) do
            if type(c.fn) == "function" then
                result = c.fn(c.mod, result)
            else
                log_mod.warn("Compound Modifier 的 value 必须是函数")
            end
        end
    end

    return result
end

return M
