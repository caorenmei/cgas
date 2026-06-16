--- MiniGas V2 核心求值模块
--- 快照式、被动-only、标签驱动、接口解耦
local enum = require("mini_gas.enum")

local ASC = {}

--- 层级标签匹配：精确匹配，或 a 是 b 的子级（如 state.dead 匹配 state）
---@param a mini_gas.Tag
---@param b mini_gas.Tag
---@return boolean
function ASC.match_tag(a, b)
    if a == b then
        return true
    end
    if b == "" then
        return false
    end
    return a:find(b, 1, true) == 1 and a:byte(#b + 1) == 46
end

--- 判断实体是否拥有与给定标签模式匹配的标签
---@param entity mini_gas.IEntityState
---@param module mini_gas.IEntityModule
---@param pattern mini_gas.Tag
---@return boolean
function ASC.entity_match_tag(entity, module, pattern)
    if module.has_static_tag(entity, pattern) then
        return true
    end
    for tag in module.static_tags(entity) do
        if ASC.match_tag(tag, pattern) then
            return true
        end
    end
    return false
end

--- 判断实体是否满足 allof / anyof / noneof 标签约束
---@param entity mini_gas.IEntityState
---@param module mini_gas.IEntityModule
---@param allof_tags? mini_gas.Tag[]
---@param anyof_tags? mini_gas.Tag[]
---@param noneof_tags? mini_gas.Tag[]
---@return boolean
function ASC.match_tags(entity, module, allof_tags, anyof_tags, noneof_tags)
    if allof_tags and #allof_tags > 0 then
        for _, pattern in ipairs(allof_tags) do
            if not ASC.entity_match_tag(entity, module, pattern) then
                return false
            end
        end
    end
    if anyof_tags and #anyof_tags > 0 then
        local any_match = false
        for _, pattern in ipairs(anyof_tags) do
            if ASC.entity_match_tag(entity, module, pattern) then
                any_match = true
                break
            end
        end
        if not any_match then
            return false
        end
    end
    if noneof_tags and #noneof_tags > 0 then
        for _, pattern in ipairs(noneof_tags) do
            if ASC.entity_match_tag(entity, module, pattern) then
                return false
            end
        end
    end
    return true
end

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

--- 统计世界中满足激活条件的实体数量
---@param context mini_gas.IContext
---@param world mini_gas.IWorldState
---@param world_module mini_gas.IWorldModule
---@param condition mini_gas.AbilityActivateCondition
---@param owner_id mini_gas.ID
---@return integer
local function count_matching_entities(context, world, world_module, condition, owner_id)
    local count = 0
    local include_self = condition.include_self ~= false
    for entity_id, entity, entity_module in world_module.entities(context, world) do
        local considered = include_self or entity_id ~= owner_id
        if considered and ASC.match_tags(entity, entity_module, condition.allof_tags, condition.anyof_tags, condition.noneof_tags) then
            count = count + 1
        end
    end
    return count
end

--- 解析 ModifierDef.attribute，递归收集所有 (id, value) 对
---@param context mini_gas.IContext
---@param world mini_gas.IWorldState
---@param entity mini_gas.IEntityState
---@param modifier_def mini_gas.ModifierDef
---@param extra unknown[]
---@return [mini_gas.ID, number][]
local function resolve_modifier_attribute(context, world, entity, modifier_def, extra)
    local result = {}
    local attr = modifier_def.attribute
    if type(attr) == "table" then
        local id, value = attr[1], attr[2]
        if id ~= nil and value ~= nil then
            result[#result + 1] = { id, value }
        end
    elseif type(attr) == "function" then
        local next_eval = attr
        while type(next_eval) == "function" do
            local id, value, nxt = next_eval(context, world, entity, modifier_def, nil, nil, table.unpack(extra))
            if id ~= nil and value ~= nil then
                result[#result + 1] = { id, value }
            end
            next_eval = nxt
        end
    end
    return result
end

--- 世界快照求值入口
--- 遍历所有实体的被动能力，按标签约束筛选目标，聚合属性修改后通过 IEvaluation 应用
---@param context mini_gas.IContext
---@param world mini_gas.IWorldState
---@param world_module mini_gas.IWorldModule
---@param defs mini_gas.Defs
---@param evaluation mini_gas.IEvaluation
---@param ... unknown
function ASC.evaluate(context, world, world_module, defs, evaluation, ...)
    local evaluate_args = { ... }
    for owner_id, owner_entity, owner_module in world_module.entities(context, world) do

        -- 按 (target_id, attr_id) 聚合当前 owner 产生的所有修改
        ---@type table<any, { entity: mini_gas.IEntityState, module: mini_gas.IEntityModule, attrs: table<any, { add: number, multiply: number, override: number?, ability_id: mini_gas.ID?, effect_id: mini_gas.ID? }> }>
        local owner_mods = {}

        for ability_def_id in owner_module.static_abilities(owner_entity) do
            local ability_def = defs.ability_defs[ability_def_id]
            if not ability_def then
                goto continue_ability
            end

            -- 评估激活条件，构造 ModifierAttributeEval 末尾可变参数
            local active
            local modifier_extra ---@type unknown[]
            local can_activate = ability_def.can_activate
            if can_activate == nil then
                active = true
                modifier_extra = evaluate_args
            elseif type(can_activate) == "table" then
                local count = count_matching_entities(context, world, world_module, can_activate, owner_id)
                active = count >= (can_activate.requires_count or 1)
                modifier_extra = { count, table.unpack(evaluate_args) }
            elseif type(can_activate) == "function" then
                local results = { can_activate(context, defs, world, owner_entity, ability_def, ...) }
                active = results[1] == true
                table.remove(results, 1)
                modifier_extra = results
            else
                active = false
            end

            if not active then
                goto continue_ability
            end

            for _, effect_def_id in ipairs(ability_def.effects or {}) do
                local effect_def = defs.effect_defs[effect_def_id]
                if not effect_def then
                    goto continue_effect
                end

                -- 根据 target 确定候选目标集合
                local candidates = {}
                local target_type = effect_def.target or enum.EEffectTarget.Self
                for entity_id, entity, entity_module in world_module.entities(context, world) do
                    local include = false
                    if target_type == enum.EEffectTarget.Other then
                        include = entity_id ~= owner_id
                    elseif target_type == enum.EEffectTarget.All then
                        include = true
                    else
                        include = entity_id == owner_id
                    end
                    if include then
                        candidates[#candidates + 1] = { id = entity_id, entity = entity, module = entity_module }
                    end
                end

                -- 按效果自身标签约束筛选目标
                local targets = {}
                for _, candidate in ipairs(candidates) do
                    if ASC.match_tags(candidate.entity, candidate.module, effect_def.allof_tags, effect_def.anyof_tags, effect_def.noneof_tags) then
                        targets[#targets + 1] = candidate
                    end
                end

                -- 对目标授予标签
                if effect_def.grant_tags and #effect_def.grant_tags > 0 then
                    for _, target in ipairs(targets) do
                        evaluation.grant_tags(context, world, defs, target.entity, owner_id, ability_def_id, effect_def_id, effect_def.grant_tags, table.unpack(evaluate_args))
                    end
                end

                -- 收集生效的 modifier 并聚合到 owner_mods
                for _, modifier_def in ipairs(effect_def.modifiers or {}) do
                    for _, target in ipairs(targets) do
                        if ASC.match_tags(target.entity, target.module, modifier_def.allof_tags, modifier_def.anyof_tags, modifier_def.noneof_tags) then
                            local pairs = resolve_modifier_attribute(context, world, target.entity, modifier_def, modifier_extra)
                            for _, pair in ipairs(pairs) do
                                local attr_id, value = pair[1], pair[2]
                                local target_entry = owner_mods[target.id]
                                if not target_entry then
                                    target_entry = { entity = target.entity, module = target.module, attrs = {} }
                                    owner_mods[target.id] = target_entry
                                end
                                local attr_entry = target_entry.attrs[attr_id]
                                if not attr_entry then
                                    attr_entry = { add = 0, multiply = 1, override = nil, ability_id = ability_def_id, effect_id = effect_def_id }
                                    target_entry.attrs[attr_id] = attr_entry
                                end
                                if modifier_def.op == enum.EModifierOp.Add then
                                    attr_entry.add = attr_entry.add + value
                                    attr_entry.ability_id = ability_def_id
                                    attr_entry.effect_id = effect_def_id
                                elseif modifier_def.op == enum.EModifierOp.Multiply then
                                    attr_entry.multiply = attr_entry.multiply * value
                                    attr_entry.ability_id = ability_def_id
                                    attr_entry.effect_id = effect_def_id
                                elseif modifier_def.op == enum.EModifierOp.Override then
                                    attr_entry.override = value
                                    attr_entry.ability_id = ability_def_id
                                    attr_entry.effect_id = effect_def_id
                                end
                            end
                        end
                    end
                end

                ::continue_effect::
            end

            ::continue_ability::
        end

        -- 应用当前 owner 聚合后的属性变化
        for _, target_entry in pairs(owner_mods) do
            for attr_id, attr_entry in pairs(target_entry.attrs) do
                local base = target_entry.module.get_attribute(target_entry.entity, attr_id)
                local final = attr_entry.override ~= nil
                    and attr_entry.override
                    or (base + attr_entry.add) * attr_entry.multiply
                local attr_def = defs.attribute_defs[attr_id]
                if attr_def then
                    final = clamp(final, attr_def.min, attr_def.max)
                end
                local delta = final - base
                evaluation.apply_attribute(context, world, defs, target_entry.entity, owner_id, attr_entry.ability_id, attr_entry.effect_id, attr_id, delta, table.unpack(evaluate_args))
            end
        end
    end
end

return ASC
