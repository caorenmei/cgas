--- MiniGas V2 核心求值模块
--- 快照式、被动-only、标签驱动、接口解耦
--- 本模块仅负责公共 API 聚合与主控求值流程，具体逻辑拆分到 tag / ability / effect / modifier / pool 子模块

local tag = require("mini_gas.tag")
local ability = require("mini_gas.ability")
local effect = require("mini_gas.effect")
local pool = require("mini_gas.pool")
local debug_helper = require("mini_gas.debug")

local ASC = {}

-- 公共 API：标签匹配
ASC.match_tag = tag.match_tag
ASC.entity_match_tag = tag.entity_match_tag
ASC.match_tags = tag.match_tags

--- 数值截断
---@param value number
---@param min? number
---@param max? number
---@return number
local function clamp(value, min, max)
    if min and value < min then
        return min
    end
    if max and value > max then
        return max
    end
    return value
end

--- 阶段二：逐实体应用
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param apply mini_gas.ApplyFun
---@param active_abilities table
---@param evaluate_args table
local function apply_to_targets(context, debug, apply, active_abilities, evaluate_args)
    local defs = context.defs
    local world_module = context.world_module

    for target_id, target_entity, target_module in world_module.entities(context) do
        local tags = pool.acquire_table()
        local attributes = pool.acquire_table()

        for i = 1, active_abilities.n, 3 do
            local owner_id = active_abilities[i]
            local ability_id = active_abilities[i + 1]
            local modifier_args = active_abilities[i + 2]
            local ability_def = defs.ability_defs[ability_id]

            if not ability_def then
                goto continue_ability
            end

            local owner_entity, owner_module = world_module.get_entity(context, owner_id)

            for _, effect_id in ipairs(ability_def.effects or {}) do
                local effect_def = defs.effect_defs[effect_id]
                if not effect_def then
                    debug_helper.call_step(debug, context, "missing_effect", owner_id, ability_id, effect_id)
                    goto continue_effect
                end

                effect.evaluate_effect(
                    context,
                    debug,
                    owner_id,
                    owner_entity,
                    owner_module,
                    ability_id,
                    effect_id,
                    effect_def,
                    target_id,
                    target_entity,
                    target_module,
                    modifier_args,
                    tags,
                    attributes,
                    evaluate_args
                )

                ::continue_effect::
            end

            ::continue_ability::
        end

        -- 将聚合结果转换为 add 语义差值
        -- attr_entry 使用数组结构：[1] override, [2] add, [3] multiply
        local deltas = pool.acquire_table()
        for attr_id, attr_entry in pairs(attributes) do
            local base = target_module.get_attribute(target_entity, attr_id)
            local final = attr_entry[1] ~= nil and attr_entry[1] or (base + attr_entry[2]) * attr_entry[3]
            local attr_def = defs.attribute_defs[attr_id]
            if attr_def then
                final = clamp(final, attr_def.min, attr_def.max)
            end
            local delta = final - base
            if delta ~= 0 or attr_entry[1] ~= nil then
                deltas[attr_id] = delta
            end
            pool.release_table(attr_entry)
        end
        pool.release_table(attributes)

        apply(context, target_entity, tags, deltas, table.unpack(evaluate_args, 1, evaluate_args.n))

        pool.release_table(tags)
        pool.release_table(deltas)
    end
end

--- 世界快照求值入口
--- IDebug 从 context.debug 获取
---@param context mini_gas.IContext
---@param apply mini_gas.ApplyFun
---@param ... unknown
function ASC.evaluate(context, apply, ...)
    local debug = context.debug
    local evaluate_args = pool.acquire_short_array()
    local n = select("#", ...)
    for i = 1, n do
        evaluate_args[i] = select(i, ...)
    end
    evaluate_args.n = n

    local active_abilities = ability.collect_active_abilities(context, debug, evaluate_args)
    apply_to_targets(context, debug, apply, active_abilities, evaluate_args)
    ability.release_active_abilities(active_abilities)

    debug_helper.call_step(debug, context, "evaluate_end")

    pool.release_short_array(evaluate_args)
end

return ASC
