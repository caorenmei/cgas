--- MiniGas V2 Modifier 解析与聚合

local enum = require("mini_gas.enum")
local tag = require("mini_gas.tag")
local pool = require("mini_gas.pool")
local debug_helper = require("mini_gas.debug")

local M = {}

--- 解析 ModifierDef.attribute，递归收集所有 (id, value) 对
--- 返回的数组中按 [i * 2 - 1] = id, [i * 2] = value 紧凑存储，均来自通用对象池
---@param context mini_gas.IContext
---@param entity mini_gas.IEntityState
---@param modifier_def mini_gas.ModifierDef
---@param modifier_args table
---@return table
function M.resolve_modifier_attribute(context, entity, modifier_def, modifier_args)
    local result = pool.acquire_short_array()
    local attr = modifier_def.attribute
    local count = 0

    if type(attr) == "table" then
        local id, value = attr[1], attr[2]
        if id ~= nil and value ~= nil then
            count = count + 1
            result[count * 2 - 1] = id
            result[count * 2] = value
        end
    elseif type(attr) == "function" then
        local id, value = nil, nil
        local next_eval = attr
        while type(next_eval) == "function" do
            id, value, next_eval = next_eval(context, entity, modifier_def, id, value, table.unpack(modifier_args, 1, modifier_args.n))
            if id ~= nil and value ~= nil then
                count = count + 1
                result[count * 2 - 1] = id
                result[count * 2] = value
            end
        end
    else
        result.invalid = true
    end

    result.n = count * 2
    return result
end

--- 对单个 Modifier 进行求值并聚合到 attributes
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param owner_id mini_gas.ID
---@param owner_entity mini_gas.IEntityState
---@param owner_module mini_gas.IEntityModule
---@param ability_id mini_gas.ID
---@param effect_id mini_gas.ID
---@param modifier_def mini_gas.ModifierDef
---@param target_id mini_gas.ID
---@param target_entity mini_gas.IEntityState
---@param target_module mini_gas.IEntityModule
---@param modifier_args table
---@param attributes table
---@param evaluate_args table
function M.evaluate_modifier(
    context,
    debug,
    owner_id,
    owner_entity,
    owner_module,
    ability_id,
    effect_id,
    modifier_def,
    target_id,
    target_entity,
    target_module,
    modifier_args,
    attributes,
    evaluate_args
)
    if not tag.match_tags(target_entity, target_module, modifier_def.allof_tags, modifier_def.anyof_tags, modifier_def.noneof_tags) then
        return
    end

    debug_helper.call_debug(
        debug,
        "begin_modifier",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_id,
        effect_id,
        modifier_def,
        target_entity,
        target_module,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )

    local pairs_list = M.resolve_modifier_attribute(context, target_entity, modifier_def, modifier_args)
    if pairs_list.invalid then
        debug_helper.call_step(debug, context, "invalid_modifier_attribute", owner_id, ability_id, effect_id, modifier_def, target_id)
    end

    for i = 1, pairs_list.n, 2 do
        local attr_id, value = pairs_list[i], pairs_list[i + 1]
        local attr_entry = attributes[attr_id]
        if not attr_entry then
            attr_entry = pool.acquire_table()
            -- attr_entry 使用数组结构：[1] override, [2] add, [3] multiply
            attr_entry[1] = nil
            attr_entry[2] = 0
            attr_entry[3] = 1
            attributes[attr_id] = attr_entry
        end

        if modifier_def.op == enum.EModifierOp.Add then
            attr_entry[2] = attr_entry[2] + value
        elseif modifier_def.op == enum.EModifierOp.Multiply then
            attr_entry[3] = attr_entry[3] * value
        elseif modifier_def.op == enum.EModifierOp.Override then
            attr_entry[1] = value
        end
    end

    pairs_list.invalid = nil
    pool.release_short_array(pairs_list)

    debug_helper.call_debug(
        debug,
        "end_modifier",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_id,
        effect_id,
        modifier_def,
        target_entity,
        target_module,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )
end

return M
