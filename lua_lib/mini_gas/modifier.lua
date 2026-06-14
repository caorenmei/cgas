--- Modifier 与属性聚合逻辑
--- Modifier 实例为轻量运行时状态表，仅保留 def_id（所属 Effect 的 Def ID）、index 与 stack，配置通过 defs 查找。
local enum = require("mini_gas.enum")
local tag_mod = require("mini_gas.tag")
local log_mod = require("mini_gas.log")

local M = {}

M.Modifier = {}

---创建轻量 Modifier 实例
---@param def_id mini_gas.EffectId
---@param index integer
---@param stack number|nil
---@return mini_gas.Modifier
function M.Modifier.new(def_id, index, stack)
    ---运行时实例仅保留定位信息与 stack，不持有 Def 或其他对象引用
    return {
        def_id = def_id,
        index = index,
        stack = stack,
    }
end

---@param defs mini_gas.Defs
---@param mod mini_gas.Modifier
---@return mini_gas.ModifierDef|nil
local function mod_def(defs, mod)
    local effect_def = defs.effect_defs[mod.def_id]
    if not effect_def then
        return nil
    end
    return effect_def.modifiers[mod.index]
end

---获取 ModifierDef
---@param defs mini_gas.Defs
---@param mod mini_gas.Modifier
---@return mini_gas.ModifierDef|nil
function M.def(defs, mod)
    return mod_def(defs, mod)
end

---获取当前数值或复合函数
---@param defs mini_gas.Defs
---@param mod mini_gas.Modifier
---@return (number|fun(self: mini_gas.Modifier, v: number): number)|nil
function M.value(defs, mod)
    local def = mod_def(defs, mod)
    return def and def.value
end

---判断 Modifier 是否满足标签约束
---@param state mini_gas.EntityState
---@param defs mini_gas.Defs
---@param mod mini_gas.Modifier
---@return boolean
function M.is_active(state, defs, mod)
    local def = mod_def(defs, mod)
    if not def then
        return false
    end
    local container = state.tags
    local req = def.require_tags or {}
    local blocked = def.blocked_tags or {}
    return tag_mod.has_all(container, req) and not tag_mod.has_any(container, blocked)
end

---计算单个属性的 Current 值（无状态纯函数）
---@param base number
---@param state mini_gas.EntityState
---@param defs mini_gas.Defs
---@param modifiers mini_gas.Modifier[]
---@return number
function M.calc_attribute(base, state, defs, modifiers)
    local add_sum = 0
    local multiply_product = 1
    local overrides = {}
    local compounds = {}

    for _, mod in ipairs(modifiers or {}) do
        if not M.is_active(state, defs, mod) then
            goto continue
        end

        local def = mod_def(defs, mod)
        if not def then
            goto continue
        end

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
