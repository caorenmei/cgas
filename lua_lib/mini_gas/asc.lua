--- MiniGas V2 核心求值模块
--- 快照式、被动-only、标签驱动、接口解耦、内部对象池
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

--- 模块级表对象池，用于复用 evaluate 内部的临时表
local table_pool = {}

--- 从对象池获取一张已清空的表
---@return table
local function acquire_table()
    local t = table.remove(table_pool)
    if t then
        for k, _ in pairs(t) do
            t[k] = nil
        end
    else
        t = {}
    end
    return t
end

--- 将表清空并归还对象池
---@param t table
local function release_table(t)
    for k, _ in pairs(t) do
        t[k] = nil
    end
    table.insert(table_pool, t)
end

--- 释放数组中存放的表条目，并清空数组本身
---@param arr table
local function release_array_entries(arr)
    for i = 1, #arr do
        release_table(arr[i])
        arr[i] = nil
    end
end

--- 若函数存在则调用
---@param fn function?
local function call_if_present(fn, ...)
    if fn then
        fn(...)
    end
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
--- 返回的数组与其中条目均来自对象池，调用方负责回收
---@param context mini_gas.IContext
---@param world mini_gas.IWorldState
---@param world_module mini_gas.IWorldModule
---@param entity mini_gas.IEntityState
---@param entity_module mini_gas.IEntityModule
---@param modifier_def mini_gas.ModifierDef
---@param extra unknown[]
---@return table
local function resolve_modifier_attribute(context, world, world_module, entity, entity_module, modifier_def, extra)
    local result = acquire_table()
    local attr = modifier_def.attribute
    if type(attr) == "table" then
        local id, value = attr[1], attr[2]
        if id ~= nil and value ~= nil then
            local entry = acquire_table()
            entry[1], entry[2] = id, value
            result[#result + 1] = entry
        end
    elseif type(attr) == "function" then
        local next_eval = attr
        while type(next_eval) == "function" do
            local id, value, nxt = next_eval(context, world, world_module, entity, entity_module, modifier_def, nil, nil, table.unpack(extra))
            if id ~= nil and value ~= nil then
                local entry = acquire_table()
                entry[1], entry[2] = id, value
                result[#result + 1] = entry
            end
            next_eval = nxt
        end
    end
    return result
end

--- 世界快照求值入口
--- 遍历所有实体的被动能力，按标签约束筛选目标，聚合属性修改后通过 IEvaluation.apply 应用
--- 内部使用对象池复用临时表；apply 回调返回后，tags 与 attr_changes 会被立即回收，
--- 业务方如需保留应在 apply 内部复制
---@param context mini_gas.IContext
---@param world mini_gas.IWorldState
---@param world_module mini_gas.IWorldModule
---@param defs mini_gas.Defs
---@param evaluation mini_gas.IEvaluation
---@param ... unknown
function ASC.evaluate(context, world, world_module, defs, evaluation, ...)
    local evaluate_args = { ... }

    for owner_id, owner_entity, owner_module in world_module.entities(context, world) do
        -- 当前 owner 产生的所有授予标签与属性修改
        -- tags 为 table<mini_gas.Tag, boolean>，仅表示该 owner 授予了哪些标签
        local owner_tags = acquire_table()
        ---@type table<any, { entity: mini_gas.IEntityState, module: mini_gas.IEntityModule, attrs: table<any, { add: number, multiply: number, override: number? }> }>
        local owner_mods = acquire_table()

        for ability_def_id in owner_module.static_abilities(owner_entity) do
            local ability_def = defs.ability_defs[ability_def_id]
            if not ability_def then
                goto continue_ability
            end

            -- 评估激活条件，构造 ModifierAttributeEval 末尾可变参数
            local active
            local modifier_extra ---@type unknown[]
            local need_release_modifier_extra = false
            local can_activate = ability_def.can_activate
            if can_activate == nil then
                active = true
                modifier_extra = evaluate_args
            elseif type(can_activate) == "table" then
                local count = count_matching_entities(context, world, world_module, can_activate, owner_id)
                active = count >= (can_activate.requires_count or 1)
                modifier_extra = acquire_table()
                modifier_extra[1] = count
                for i = 1, #evaluate_args do
                    modifier_extra[i + 1] = evaluate_args[i]
                end
                need_release_modifier_extra = true
            elseif type(can_activate) == "function" then
                local results = { can_activate(context, defs, world, world_module, owner_entity, owner_module, ability_def, ...) }
                active = results[1] == true
                table.remove(results, 1)
                modifier_extra = results
            else
                active = false
            end

            if not active then
                if need_release_modifier_extra then
                    release_table(modifier_extra)
                end
                goto continue_ability
            end

            call_if_present(evaluation.begin_ability, context, world, world_module, defs, owner_id, owner_entity, owner_module, ability_def_id, ...)

            for _, effect_def_id in ipairs(ability_def.effects or {}) do
                local effect_def = defs.effect_defs[effect_def_id]
                if not effect_def then
                    goto continue_effect
                end

                call_if_present(evaluation.begin_effect, context, world, world_module, defs, owner_id, owner_entity, owner_module, ability_def_id, effect_def_id, ...)

                -- 根据 target 确定目标实体集合，并同时用效果自身标签约束筛选
                local targets = acquire_table()
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
                    if include and ASC.match_tags(entity, entity_module, effect_def.allof_tags, effect_def.anyof_tags, effect_def.noneof_tags) then
                        local entry = acquire_table()
                        entry.id = entity_id
                        entry.entity = entity
                        entry.module = entity_module
                        targets[#targets + 1] = entry
                    end
                end

                -- 累积要授予的标签
                if effect_def.grant_tags and #effect_def.grant_tags > 0 then
                    for _, tag in ipairs(effect_def.grant_tags) do
                        owner_tags[tag] = true
                    end
                end

                -- 累积 modifier 结果到 owner 级别
                for _, modifier_def in ipairs(effect_def.modifiers or {}) do
                    for _, target in ipairs(targets) do
                        if ASC.match_tags(target.entity, target.module, modifier_def.allof_tags, modifier_def.anyof_tags, modifier_def.noneof_tags) then
                            call_if_present(evaluation.begin_modifier, context, world, world_module, defs, owner_id, owner_entity, owner_module, ability_def_id, effect_def_id, modifier_def, target.entity, target.module, ...)

                            local pairs = resolve_modifier_attribute(context, world, world_module, target.entity, target.module, modifier_def, modifier_extra)
                            for _, pair in ipairs(pairs) do
                                local attr_id, value = pair[1], pair[2]
                                local target_entry = owner_mods[target.id]
                                if not target_entry then
                                    target_entry = acquire_table()
                                    target_entry.entity = target.entity
                                    target_entry.module = target.module
                                    target_entry.attrs = acquire_table()
                                    owner_mods[target.id] = target_entry
                                end
                                local attr_entry = target_entry.attrs[attr_id]
                                if not attr_entry then
                                    attr_entry = acquire_table()
                                    attr_entry.add = 0
                                    attr_entry.multiply = 1
                                    attr_entry.override = nil
                                    target_entry.attrs[attr_id] = attr_entry
                                end
                                if modifier_def.op == enum.EModifierOp.Add then
                                    attr_entry.add = attr_entry.add + value
                                elseif modifier_def.op == enum.EModifierOp.Multiply then
                                    attr_entry.multiply = attr_entry.multiply * value
                                elseif modifier_def.op == enum.EModifierOp.Override then
                                    attr_entry.override = value
                                end
                            end
                            release_array_entries(pairs)
                            release_table(pairs)

                            call_if_present(evaluation.end_modifier, context, world, world_module, defs, owner_id, owner_entity, owner_module, ability_def_id, effect_def_id, modifier_def, target.entity, target.module, ...)
                        end
                    end
                end

                -- 回收 targets
                for i = 1, #targets do
                    release_table(targets[i])
                end
                release_table(targets)

                call_if_present(evaluation.end_effect, context, world, world_module, defs, owner_id, owner_entity, owner_module, ability_def_id, effect_def_id, ...)

                ::continue_effect::
            end

            call_if_present(evaluation.end_ability, context, world, world_module, defs, owner_id, owner_entity, owner_module, ability_def_id, ...)

            if need_release_modifier_extra then
                release_table(modifier_extra)
            end

            ::continue_ability::
        end

        -- 生成属性变化列表（已按 target 聚合并截断）
        local attr_changes = acquire_table()
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
                if delta ~= 0 or attr_entry.override ~= nil then
                    local entry = acquire_table()
                    entry.entity = target_entry.entity
                    entry.module = target_entry.module
                    entry.attr_id = attr_id
                    entry.value = delta
                    attr_changes[#attr_changes + 1] = entry
                end
            end
        end

        -- 应用当前 owner 的所有结果
        evaluation.apply(context, world, world_module, defs, owner_id, owner_entity, owner_module, owner_tags, attr_changes, ...)

        -- 回收 apply 使用的表（apply 返回后业务方不应再持有）
        release_table(owner_tags)
        release_array_entries(attr_changes)
        release_table(attr_changes)

        -- 释放 owner_mods 占用的内部表
        for _, target_entry in pairs(owner_mods) do
            for _, attr_entry in pairs(target_entry.attrs) do
                release_table(attr_entry)
            end
            release_table(target_entry.attrs)
            release_table(target_entry)
        end
        release_table(owner_mods)
    end
end

return ASC
