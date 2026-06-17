--- MiniGas V2 Effect 目标匹配与应用

local enum = require("mini_gas.enum")
local tag = require("mini_gas.tag")
local modifier = require("mini_gas.modifier")
local debug_helper = require("mini_gas.debug")

local M = {}

--- 判断 EffectDef 是否可作用于目标实体
---@param owner_id mini_gas.ID
---@param target_id mini_gas.ID
---@param target_entity mini_gas.IEntityState
---@param target_module mini_gas.IEntityModule
---@param effect_def mini_gas.EffectDef
---@return boolean
function M.match_effect_target(owner_id, target_id, target_entity, target_module, effect_def)
    local target_type = effect_def.target or enum.EEffectTarget.Self
    if target_type == enum.EEffectTarget.Other then
        if target_id == owner_id then
            return false
        end
    elseif target_type == enum.EEffectTarget.Self then
        if target_id ~= owner_id then
            return false
        end
    end
    -- All 无需过滤 owner_id
    return tag.match_tags(target_entity, target_module, effect_def.allof_tags, effect_def.anyof_tags, effect_def.noneof_tags)
end

--- 对单个 Effect 进行求值
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param owner_id mini_gas.ID
---@param owner_entity mini_gas.IEntityState
---@param owner_module mini_gas.IEntityModule
---@param ability_id mini_gas.ID
---@param effect_id mini_gas.ID
---@param effect_def mini_gas.EffectDef
---@param target_id mini_gas.ID
---@param target_entity mini_gas.IEntityState
---@param target_module mini_gas.IEntityModule
---@param modifier_args table
---@param tags table<mini_gas.Tag, boolean>
---@param attributes table
---@param evaluate_args table
function M.evaluate_effect(
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
    if not M.match_effect_target(owner_id, target_id, target_entity, target_module, effect_def) then
        return
    end

    debug_helper.call_debug(
        debug,
        "begin_effect",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_id,
        effect_id,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )

    -- 授予标签
    if effect_def.grant_tags then
        for _, tag_value in ipairs(effect_def.grant_tags) do
            tags[tag_value] = true
        end
    end

    -- 应用 Modifier
    if effect_def.modifiers then
        for _, modifier_def in ipairs(effect_def.modifiers) do
            modifier.evaluate_modifier(
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
        end
    end

    debug_helper.call_debug(
        debug,
        "end_effect",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_id,
        effect_id,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )
end

return M
