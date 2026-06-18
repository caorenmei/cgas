--- MiniGas V2 Ability 激活条件与收集

local tag = require("mini_gas.tag")
local pool = require("mini_gas.pool")
local enum = require("mini_gas.enum")

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

--- 将可变参数打包到短数组池的表中，替代 table.pack 以避免临时表分配
---@param ... unknown
---@return table
local function pack_results(...)
    local t = pool.acquire_short_array()
    local n = select("#", ...)
    for i = 1, n do
        t[i] = select(i, ...)
    end
    t.n = n
    return t
end

--- 评估 Ability 激活条件，返回是否激活以及 modifier_args
--- 三种 can_activate 形式的 modifier_args 格式统一为 { count, ... }：
--- - 对象形式：count 为满足标签约束的实体数量
--- - 函数形式：count 为函数返回的第二个 number，省略则视为 0
--- - 为空时：count 为 0
--- 未激活时 modifier_args 为 nil；激活时由调用方负责回收
---@param context mini_gas.IContext
---@param owner_id mini_gas.ID
---@param owner_entity mini_gas.IEntityState
---@param ability_def mini_gas.AbilityDef
---@param evaluate_args table
---@return boolean activated
---@return table|nil modifier_args
function M.check_can_activate(context, owner_id, owner_entity, ability_def, evaluate_args)
    local can_activate = ability_def.can_activate

    -- 对象形式：统计匹配实体数并打包 { count, ... }
    if type(can_activate) == "table" then
        local count = count_matching_entities(context, can_activate, owner_id)
        local active = count >= (can_activate.requires_count or 1)
        if not active then
            return false, nil
        end
        local modifier_args = pool.acquire_short_array()
        modifier_args[1] = count
        for i = 1, evaluate_args.n do
            modifier_args[i + 1] = evaluate_args[i]
        end
        modifier_args.n = evaluate_args.n + 1
        return true, modifier_args
    end

    -- 函数形式：返回 boolean, any, ...，打包 { count, ... } 作为 modifier_args
    if type(can_activate) == "function" then
        local packed = pack_results(can_activate(context, owner_entity, ability_def, table.unpack(evaluate_args, 1, evaluate_args.n)))
        local active = packed[1] == true
        if not active then
            pool.release_short_array(packed)
            return false, nil
        end
        local count = packed[2] or 0
        local modifier_args = pool.acquire_short_array()
        local idx = 1
        modifier_args[1] = count
        for i = 3, packed.n do
            idx = idx + 1
            modifier_args[idx] = packed[i]
        end
        for i = 1, evaluate_args.n do
            idx = idx + 1
            modifier_args[idx] = evaluate_args[i]
        end
        modifier_args.n = idx
        pool.release_short_array(packed)
        return true, modifier_args
    end

    -- 为空时默认激活，modifier_args 为 { 0, ... }
    if can_activate == nil then
        local modifier_args = pool.acquire_short_array()
        modifier_args[1] = 0
        for i = 1, evaluate_args.n do
            modifier_args[i + 1] = evaluate_args[i]
        end
        modifier_args.n = evaluate_args.n + 1
        return true, modifier_args
    end

    -- 不支持的形式：不激活
    return false, nil
end

--- 阶段一：收集激活的能力
--- active_abilities 为一维数组，每 3 个元素一组：owner_id, ability_id, modifier_args
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param evaluate_args table
---@return table
function M.collect_active_abilities(context, debug, evaluate_args)
    local active_abilities = pool.acquire_long_array()
    local defs = context.defs
    local world_module = context.world_module

    if debug and debug.step then
        debug.step(context, "evaluate_start")
    end

    local idx = 0
    for owner_id, owner_entity, owner_module in world_module.entities(context) do
        for ability_id, _ in owner_module.static_abilities(owner_entity) do
            local ability_def = defs.ability_defs[ability_id]
            if not ability_def then
                goto continue_ability
            end
            if ability_def.activation_policy ~= enum.EAbilityActivationPolicy.Passive then
                goto continue_ability
            end

            if debug and debug.begin_ability then
                debug.begin_ability(
                    context,
                    owner_id,
                    owner_entity,
                    owner_module,
                    ability_id,
                    table.unpack(evaluate_args, 1, evaluate_args.n)
                )
            end

            local active, modifier_args = M.check_can_activate(context, owner_id, owner_entity, ability_def, evaluate_args)

            if active then
                idx = idx + 1
                active_abilities[idx] = owner_id
                idx = idx + 1
                active_abilities[idx] = ability_id
                idx = idx + 1
                active_abilities[idx] = modifier_args
            end

            if debug and debug.end_ability then
                debug.end_ability(
                    context,
                    owner_id,
                    owner_entity,
                    owner_module,
                    ability_id,
                    table.unpack(evaluate_args, 1, evaluate_args.n)
                )
            end

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
        pool.release_short_array(active_abilities[i])
    end
    pool.release_long_array(active_abilities)
end

return M
