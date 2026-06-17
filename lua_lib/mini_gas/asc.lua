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
        t.__in_pool = nil
        for k, _ in pairs(t) do
            t[k] = nil
        end
    else
        t = {}
    end
    return t
end

--- 将表清空并归还对象池
--- 带有重复释放保护，避免同一张表在池中出现多次
---@param t table
local function release_table(t)
    if not t or t.__in_pool then
        return
    end
    for k, _ in pairs(t) do
        t[k] = nil
    end
    t.__in_pool = true
    table.insert(table_pool, t)
end

--- 调用可选调试钩子
---@param debug? mini_gas.IDebug
---@param name string
---@param ... unknown
local function call_debug(debug, name, ...)
    if not debug then
        return
    end
    local fn = debug[name]
    if fn then
        fn(...)
    end
end

--- 调用通用步骤调试钩子
---@param debug? mini_gas.IDebug
---@param context mini_gas.IContext
---@param phase string
---@param ... unknown
local function call_step(debug, context, phase, ...)
    if debug and debug.step then
        debug.step(context, phase, ...)
    end
end

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
        if considered and ASC.match_tags(entity, entity_module, condition.allof_tags, condition.anyof_tags, condition.noneof_tags) then
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
local function check_can_activate(context, owner_entity, ability_def, evaluate_args)
    local can_activate = ability_def.can_activate

    -- 为空时默认激活，modifier_args 直接使用 evaluate_args
    if can_activate == nil then
        return true, evaluate_args, false
    end

    -- 对象形式：统计匹配实体数并打包 { count, ... }
    if type(can_activate) == "table" then
        local count = count_matching_entities(context, can_activate, ability_def.id)
        local active = count >= (can_activate.requires_count or 1)
        local modifier_args = acquire_table()
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
        local results = acquire_table()
        for i = 2, packed.n do
            results[i - 1] = packed[i]
        end
        results.n = packed.n - 1
        release_table(packed)
        return active, results, true
    end

    return false, evaluate_args, false
end

--- 解析 ModifierDef.attribute，递归收集所有 (id, value) 对
--- 返回的数组中每个元素为 { [1] = id, [2] = value }，均来自对象池
---@param context mini_gas.IContext
---@param entity mini_gas.IEntityState
---@param modifier_def mini_gas.ModifierDef
---@param modifier_args table
---@return table
local function resolve_modifier_attribute(context, entity, modifier_def, modifier_args)
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
        local id, value = nil, nil
        local next_eval = attr
        while type(next_eval) == "function" do
            id, value, next_eval = next_eval(context, entity, modifier_def, id, value, table.unpack(modifier_args, 1, modifier_args.n))
            if id ~= nil and value ~= nil then
                local entry = acquire_table()
                entry[1], entry[2] = id, value
                result[#result + 1] = entry
            end
        end
    else
        result.invalid = true
    end

    return result
end

--- 对单个 Modifier 进行求值并聚合到 attributes
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param owner_id mini_gas.ID
---@param owner_entity mini_gas.IEntityState
---@param owner_module mini_gas.IEntityModule
---@param ability_def_id mini_gas.ID
---@param effect_def_id mini_gas.ID
---@param modifier_def mini_gas.ModifierDef
---@param target_id mini_gas.ID
---@param target_entity mini_gas.IEntityState
---@param target_module mini_gas.IEntityModule
---@param modifier_args table
---@param attributes table
---@param evaluate_args table
local function evaluate_modifier(
    context,
    debug,
    owner_id,
    owner_entity,
    owner_module,
    ability_def_id,
    effect_def_id,
    modifier_def,
    target_id,
    target_entity,
    target_module,
    modifier_args,
    attributes,
    evaluate_args
)
    if not ASC.match_tags(target_entity, target_module, modifier_def.allof_tags, modifier_def.anyof_tags, modifier_def.noneof_tags) then
        return
    end

    call_debug(
        debug,
        "begin_modifier",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_def_id,
        effect_def_id,
        modifier_def,
        target_entity,
        target_module,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )

    local pairs_list = resolve_modifier_attribute(context, target_entity, modifier_def, modifier_args)
    if pairs_list.invalid then
        call_step(debug, context, "invalid_modifier_attribute", owner_id, ability_def_id, effect_def_id, modifier_def, target_id)
    end

    for _, pair in ipairs(pairs_list) do
        local attr_id, value = pair[1], pair[2]
        local attr_entry = attributes[attr_id]
        if not attr_entry then
            attr_entry = acquire_table()
            attr_entry.add = 0
            attr_entry.multiply = 1
            attr_entry.override = nil
            attributes[attr_id] = attr_entry
        end

        if modifier_def.op == enum.EModifierOp.Add then
            attr_entry.add = attr_entry.add + value
        elseif modifier_def.op == enum.EModifierOp.Multiply then
            attr_entry.multiply = attr_entry.multiply * value
        elseif modifier_def.op == enum.EModifierOp.Override then
            attr_entry.override = value
        end
    end

    for i = 1, #pairs_list do
        release_table(pairs_list[i])
    end
    pairs_list.invalid = nil
    release_table(pairs_list)

    call_debug(
        debug,
        "end_modifier",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_def_id,
        effect_def_id,
        modifier_def,
        target_entity,
        target_module,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )
end

--- 判断 EffectDef 是否可作用于目标实体
---@param owner_id mini_gas.ID
---@param target_id mini_gas.ID
---@param target_entity mini_gas.IEntityState
---@param target_module mini_gas.IEntityModule
---@param effect_def mini_gas.EffectDef
---@return boolean
local function match_effect_target(owner_id, target_id, target_entity, target_module, effect_def)
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
    return ASC.match_tags(target_entity, target_module, effect_def.allof_tags, effect_def.anyof_tags, effect_def.noneof_tags)
end

--- 对单个 Effect 进行求值
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param owner_id mini_gas.ID
---@param owner_entity mini_gas.IEntityState
---@param owner_module mini_gas.IEntityModule
---@param ability_def_id mini_gas.ID
---@param effect_def_id mini_gas.ID
---@param effect_def mini_gas.EffectDef
---@param target_id mini_gas.ID
---@param target_entity mini_gas.IEntityState
---@param target_module mini_gas.IEntityModule
---@param modifier_args table
---@param tags table<mini_gas.Tag, boolean>
---@param attributes table
---@param evaluate_args table
local function evaluate_effect(
    context,
    debug,
    owner_id,
    owner_entity,
    owner_module,
    ability_def_id,
    effect_def_id,
    effect_def,
    target_id,
    target_entity,
    target_module,
    modifier_args,
    tags,
    attributes,
    evaluate_args
)
    if not match_effect_target(owner_id, target_id, target_entity, target_module, effect_def) then
        return
    end

    call_debug(
        debug,
        "begin_effect",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_def_id,
        effect_def_id,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )

    -- 授予标签
    if effect_def.grant_tags then
        for _, tag in ipairs(effect_def.grant_tags) do
            tags[tag] = true
        end
    end

    -- 应用 Modifier
    if effect_def.modifiers then
        for _, modifier_def in ipairs(effect_def.modifiers) do
            evaluate_modifier(
                context,
                debug,
                owner_id,
                owner_entity,
                owner_module,
                ability_def_id,
                effect_def_id,
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

    call_debug(
        debug,
        "end_effect",
        context,
        owner_id,
        owner_entity,
        owner_module,
        ability_def_id,
        effect_def_id,
        table.unpack(evaluate_args, 1, evaluate_args.n)
    )
end

--- 阶段一：收集激活的能力
--- active_abilities 为一维数组，每 3 个元素一组：owner_id, ability_id, modifier_args
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param evaluate_args table
---@return table
local function collect_active_abilities(context, debug, evaluate_args)
    local active_abilities = acquire_table()
    local defs = context.defs
    local world_module = context.world_module

    call_step(debug, context, "evaluate_start")

    for owner_id, owner_entity, owner_module in world_module.entities(context) do
        for ability_id, _ in owner_module.static_abilities(owner_entity) do
            local ability_def = defs.ability_defs[ability_id]
            if not ability_def then
                goto continue_ability
            end

            call_debug(
                debug,
                "begin_ability",
                context,
                owner_id,
                owner_entity,
                owner_module,
                ability_id,
                table.unpack(evaluate_args, 1, evaluate_args.n)
            )

            local active, modifier_args, need_release = check_can_activate(context, owner_entity, ability_def, evaluate_args)

            if active then
                active_abilities[#active_abilities + 1] = owner_id
                active_abilities[#active_abilities + 1] = ability_id
                active_abilities[#active_abilities + 1] = modifier_args
            elseif need_release then
                release_table(modifier_args)
            end

            call_debug(
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

    return active_abilities
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
        local tags = acquire_table()
        local attributes = acquire_table()

        for i = 1, #active_abilities, 3 do
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
                    call_step(debug, context, "missing_effect", owner_id, ability_id, effect_id)
                    goto continue_effect
                end

                evaluate_effect(
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
        local deltas = acquire_table()
        for attr_id, attr_entry in pairs(attributes) do
            local base = target_module.get_attribute(target_entity, attr_id)
            local final = attr_entry.override ~= nil and attr_entry.override or (base + attr_entry.add) * attr_entry.multiply
            local attr_def = defs.attribute_defs[attr_id]
            if attr_def then
                final = clamp(final, attr_def.min, attr_def.max)
            end
            local delta = final - base
            if delta ~= 0 or attr_entry.override ~= nil then
                deltas[attr_id] = delta
            end
            release_table(attr_entry)
        end
        release_table(attributes)

        apply(context, target_entity, tags, deltas, table.unpack(evaluate_args, 1, evaluate_args.n))

        release_table(tags)
        release_table(deltas)
    end
end

--- 阶段三：回收对象池
---@param active_abilities table
local function release_active_abilities(active_abilities)
    for i = 3, #active_abilities, 3 do
        release_table(active_abilities[i])
    end
    release_table(active_abilities)
end

--- 世界快照求值入口
--- 遍历所有实体的被动能力，按标签约束筛选目标，聚合属性修改后通过 ApplyFun 应用
---@param context mini_gas.IContext
---@param debug? mini_gas.IDebug
---@param apply mini_gas.ApplyFun
---@param ... unknown
function ASC.evaluate(context, debug, apply, ...)
    local evaluate_args = acquire_table()
    local n = select("#", ...)
    for i = 1, n do
        evaluate_args[i] = select(i, ...)
    end
    evaluate_args.n = n

    local active_abilities = collect_active_abilities(context, debug, evaluate_args)
    apply_to_targets(context, debug, apply, active_abilities, evaluate_args)
    release_active_abilities(active_abilities)

    call_step(debug, context, "evaluate_end")

    release_table(evaluate_args)
end

return ASC
