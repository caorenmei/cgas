--- MiniGas V2 Ability 激活条件与收集

local tag = require("mini_gas.tag")
local pool = require("mini_gas.pool")
local debug_helper = require("mini_gas.debug")

local M = {}

--- 统计世界中满足激活条件的实体数量
---@param context mini_gas.IContext
---@param condition mini_gas.AbilityActivateCondition
---@param owner_id mini_gas.ID
---@return integer
local function count_matching_entities(context, condition, owner_id)
    local world_module = context.world_module
    local include_self = condition.include_self ~= false
    local count = 0
    for entity_id, entity, entity_module in world_module.entities(context) do
        local considered = include_self or entity_id ~= owner_id
        if considered and tag.match_tags(entity, entity_module, condition.allof_tags, condition.anyof_tags, condition.noneof_tags) then
            count = count + 1
        end
    end
    return count
end

--- 评估 Ability 激活条件，返回是否激活以及 modifier_args
--- modifier_args 需要调用方负责回收（当 need_release 为 true 时）
---@param context mini_gas.IContext
---@param owner_entity mini_gas.IEntityState
---@param ability_def mini_gas.AbilityDef
---@param evaluate_args table
---@return boolean activated
---@return table modifier_args
---@return boolean need_release
function M.check_can_activate(context, owner_entity, ability_def, evaluate_args)
    local can_activate = ability_def.can_activate

    -- 为空时默认激活，modifier_args 直接使用 evaluate_args
    if can_activate == nil then
        return true, evaluate_args, false
    end

    -- 对象形式：统计匹配实体数并打包 { count, ... }
    if type(can_activate) == "table" then
        local count = count_matching_entities(context, can_activate, ability_def.id)
        local active = count >= (can_activate.requires_count or 1)
        local modifier_args = pool.acquire_array()
        modifier_args[1] = count
        for i = 1, evaluate_args.n do
            modifier_args[i + 1] = evaluate_args[i]
        end
        modifier_args.n = evaluate_args.n + 1
        return active, modifier_args, true
    end

    -- 函数形式：返回 boolean, ...，打包 ... 作为 modifier_args
    if type(can_activate) == "function" then
        local packed = table.pack(can_activate(context, owner_entity, ability_def, table.unpack(evaluate_args, 1, evaluate_args.n)))
        local active = packed[1] == true
        local results = pool.acquire_array()
        for i = 2, packed.n do
            results[i - 1] = packed[i]
        end
        results.n = packed.n - 1
        pool.release_array(packed)
        return active, results, true
    end

    return false, evaluate_args, false
end

--- 阶段一：收集激活的能力
--- active_abilities 为一维数组，每 3 个元素一组：owner_id, ability_id, modifier_args
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param evaluate_args table
---@return table
function M.collect_active_abilities(context, debug, evaluate_args)
    local active_abilities = pool.acquire_array()
    local defs = context.defs
    local world_module = context.world_module

    debug_helper.call_step(debug, context, "evaluate_start")

    local idx = 0
    for owner_id, owner_entity, owner_module in world_module.entities(context) do
        for ability_id, _ in owner_module.static_abilities(owner_entity) do
            local ability_def = defs.ability_defs[ability_id]
            if not ability_def then
                goto continue_ability
            end

            debug_helper.call_debug(
                debug,
                "begin_ability",
                context,
                owner_id,
                owner_entity,
                owner_module,
                ability_id,
                table.unpack(evaluate_args, 1, evaluate_args.n)
            )

            local active, modifier_args, need_release = M.check_can_activate(context, owner_entity, ability_def, evaluate_args)

            if active then
                idx = idx + 1
                active_abilities[idx] = owner_id
                idx = idx + 1
                active_abilities[idx] = ability_id
                idx = idx + 1
                active_abilities[idx] = modifier_args
            elseif need_release then
                pool.release_array(modifier_args)
            end

            debug_helper.call_debug(
                debug,
                "end_ability",
                context,
                owner_id,
                owner_entity,
                owner_module,
                ability_id,
                table.unpack(evaluate_args, 1, evaluate_args.n)
            )

            ::continue_ability::
        end
    end
    active_abilities.n = idx

    return active_abilities
end

--- 阶段三：回收 active_abilities 及其 modifier_args
---@param active_abilities table
function M.release_active_abilities(active_abilities)
    for i = 3, active_abilities.n, 3 do
        pool.release_array(active_abilities[i])
    end
    pool.release_array(active_abilities)
end

return M
