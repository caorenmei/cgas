--- MiniASC 无状态函数集合
local enum = require("mini_gas.enum")
local attribute_mod = require("mini_gas.attribute")
local modifier_mod = require("mini_gas.modifier")
local effect_mod = require("mini_gas.effect")
local ability_mod = require("mini_gas.ability")
local event_mod = require("mini_gas.event")
local task_mod = require("mini_gas.task")
local tag_mod = require("mini_gas.tag")

local M = {}

---@param attr mini_gas.Attribute
---@param value number
---@return number
local function clamp_attr(attr, value)
    return attribute_mod.clamp(attr, value)
end

---获取效果在状态中的键
---@param id mini_gas.EffectId
---@return string
local function effect_key(id)
    return tostring(id)
end

---获取技能在状态中的键
---@param id mini_gas.AbilityId
---@return string
local function ability_key(id)
    return tostring(id)
end

---解析常量或成长曲线
---@param value number|mini_gas.GrowthCurve
---@param level number
---@return number
local function resolve(value, level)
    return ability_mod.resolve_value(value, level)
end

---派发属性变化事件
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@param old_base number
---@param new_base number
local function notify_attr_changed(state, attr_id, old_base, new_base)
    event_mod.dispatch_event(state, enum.EGameplayEvent.AttributeChanged, {
        attribute = attr_id,
        old_base = old_base,
        new_base = new_base,
    })
end

---注册属性定义
---@param state mini_gas.EntityState
---@param defs mini_gas.AttributeDef[]
function M.register_attributes(state, defs)
    for _, def in ipairs(defs or {}) do
        local base = def.base or 0
        if def.growth then
            base = def.growth:value_at(1)
        end
        state.attributes[def.name] = attribute_mod.Attribute.new(def.name, base, def.min, def.max)
    end
end

---获取属性 Base 值
---@param state mini_gas.EntityState
---@param attr mini_gas.AttributeId
---@return number
function M.get_base(state, attr)
    local a = state.attributes[attr]
    return a and attribute_mod.get_base(a) or 0
end

---设置属性 Current 值
---@param state mini_gas.EntityState
---@param attr mini_gas.AttributeId
---@param value number
function M.set_current(state, attr, value)
    local a = state.attributes[attr]
    if not a then
        modifier_mod.warn("set_current: attribute not found: " .. tostring(attr))
        return
    end
    local old = a.current
    a.current = clamp_attr(a, value)
    if old ~= a.current then
        notify_attr_changed(state, attr, old, a.current)
    end
end

---收集某属性的所有生效 Modifier（周期性效果不参与持续聚合）
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@return mini_gas.Modifier[]
local function collect_modifiers(state, attr_id)
    local mods = {}
    for _, effect in pairs(state.effects) do
        if effect_mod.is_active(effect, state.tags) and effect_mod.period_value(effect) <= 0 then
            for _, mod in ipairs(effect_mod.active_modifiers(effect)) do
                if mod.def.attribute == attr_id then
                    table.insert(mods, mod)
                end
            end
        end
    end
    return mods
end

---获取属性 Current 值
---@param state mini_gas.EntityState
---@param attr mini_gas.AttributeId
---@return number
function M.get_current(state, attr)
    local a = state.attributes[attr]
    if not a then
        return 0
    end
    local base = a.current
    local mods = collect_modifiers(state, attr)
    local value = modifier_mod.calc_attribute(base, mods, state.tags)
    return clamp_attr(a, value)
end

---添加标签
---@param state mini_gas.EntityState
---@param tag mini_gas.TagId
function M.add_tag(state, tag)
    if not tag_mod.has(state.tags, tag) then
        tag_mod.add(state.tags, tag, "_explicit")
        event_mod.dispatch_event(state, enum.EGameplayEvent.TagAdded, { tag = tag })
    else
        tag_mod.add(state.tags, tag, "_explicit")
    end
end

---移除标签
---@param state mini_gas.EntityState
---@param tag mini_gas.TagId
function M.remove_tag(state, tag)
    if tag_mod.has(state.tags, tag) then
        tag_mod.remove(state.tags, tag, "_explicit")
        if not tag_mod.has(state.tags, tag) then
            event_mod.dispatch_event(state, enum.EGameplayEvent.TagRemoved, { tag = tag })
        end
    end
end

---判断是否包含某标签
---@param state mini_gas.EntityState
---@param tag mini_gas.TagId
---@return boolean
function M.has_tag(state, tag)
    return tag_mod.has(state.tags, tag)
end

---派发事件
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param payload table|nil
function M.dispatch_event(state, event, payload)
    event_mod.dispatch_event(state, event, payload)
end

---监听事件
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param listener fun(payload:table|nil)
function M.listen_event(state, event, listener)
    event_mod.listen_event(state, event, listener)
end

---对标签容器添加 Granted 标签（带来源引用计数）
---@param state mini_gas.EntityState
---@param tag mini_gas.TagId
---@param source string
local function add_granted_tag(state, tag, source)
    local had = tag_mod.has(state.tags, tag)
    tag_mod.add(state.tags, tag, source)
    if not had then
        event_mod.dispatch_event(state, enum.EGameplayEvent.TagAdded, { tag = tag, source = source })
    end
end

---对标签容器移除 Granted 标签（引用计数归零后移除）
---@param state mini_gas.EntityState
---@param tag mini_gas.TagId
---@param source string
local function remove_granted_tag(state, tag, source)
    local had = tag_mod.has(state.tags, tag)
    tag_mod.remove(state.tags, tag, source)
    if had and not tag_mod.has(state.tags, tag) then
        event_mod.dispatch_event(state, enum.EGameplayEvent.TagRemoved, { tag = tag, source = source })
    end
end

---移除指定来源的所有 Granted 标签
---@param state mini_gas.EntityState
---@param tags mini_gas.TagId[]
---@param source string
local function remove_granted_tags(state, tags, source)
    for _, tag in ipairs(tags or {}) do
        remove_granted_tag(state, tag, source)
    end
end

---授予技能
---@param state mini_gas.EntityState
---@param spec mini_gas.GameplayAbilityDef
---@param level number
---@param stack number|nil
function M.give_ability(state, spec, level, stack)
    level = level or 1
    stack = stack or 1
    local key = ability_key(spec.id)
    if state.abilities[key] then
        return
    end
    local ability = ability_mod.GameplayAbility.new(spec, level, stack)
    state.abilities[key] = ability

    for _, tag in ipairs(spec.grant_tags or {}) do
        add_granted_tag(state, tag, key)
    end

    -- Reactive 技能注册事件监听
    if spec.activation_policy == enum.EAbilityActivationPolicy.Reactive and spec.activation_event then
        local listener = function(payload)
            M.try_activate_ability(state, spec.id, payload)
        end
        state._reactive_listeners[key] = listener
        event_mod.listen_event(state, spec.activation_event, listener)
    end

    -- Passive 技能自动激活
    if spec.activation_policy == enum.EAbilityActivationPolicy.Passive then
        M.try_activate_ability(state, spec.id)
    end
end

---移除技能
---@param state mini_gas.EntityState
---@param ability_id mini_gas.AbilityId
function M.remove_ability(state, ability_id)
    local key = ability_key(ability_id)
    local ability = state.abilities[key]
    if not ability then
        return
    end

    if ability.is_active then
        M.end_ability(state, ability_id)
    end

    -- 移除 Reactive 监听
    if ability.spec.activation_policy == enum.EAbilityActivationPolicy.Reactive and ability.spec.activation_event then
        local listener = state._reactive_listeners[key]
        if listener then
            event_mod.unlisten_event(state, ability.spec.activation_event, listener)
            state._reactive_listeners[key] = nil
        end
    end

    remove_granted_tags(state, ability.spec.grant_tags or {}, key)

    -- 移除该技能来源的持续效果
    for _, effect in pairs(state.effects) do
        if effect.spec.source == ability_id then
            M.remove_effect(state, effect.spec.id)
        end
    end

    state.abilities[key] = nil
end

---设置技能等级
---@param state mini_gas.EntityState
---@param ability_id mini_gas.AbilityId
---@param level number
function M.set_ability_level(state, ability_id, level)
    local key = ability_key(ability_id)
    local ability = state.abilities[key]
    if not ability then
        return
    end
    ability.level = level
    for _, effect in pairs(state.effects) do
        if effect.spec.source == ability_id then
            effect.level = level
        end
    end
end

---设置技能 Stack
---@param state mini_gas.EntityState
---@param ability_id mini_gas.AbilityId
---@param stack number
function M.set_ability_stack(state, ability_id, stack)
    local key = ability_key(ability_id)
    local ability = state.abilities[key]
    if not ability then
        return
    end
    ability.stack = stack
    for _, effect in pairs(state.effects) do
        if effect.spec.source == ability_id then
            effect.stack = stack
        end
    end
end

---结束技能
---@param state mini_gas.EntityState
---@param ability_id mini_gas.AbilityId
function M.end_ability(state, ability_id)
    local key = ability_key(ability_id)
    local ability = state.abilities[key]
    if not ability or not ability.is_active then
        return
    end
    ability_mod.end_ability(ability, state)
    event_mod.dispatch_event(state, enum.EGameplayEvent.AbilityEnded, { ability_id = ability_id })
end

---尝试激活技能
---@param state mini_gas.EntityState
---@param ability_id mini_gas.AbilityId
---@param payload table|nil
---@return boolean
function M.try_activate_ability(state, ability_id, payload)
    local key = ability_key(ability_id)
    local ability = state.abilities[key]
    if not ability then
        return false
    end

    if not ability_mod.can_activate(ability, state) then
        return false
    end

    ability_mod.activate(ability, state, payload)

    -- 应用消耗
    if ability.spec.cost then
        for attr_id, cost_value in pairs(ability.spec.cost) do
            local attr = state.attributes[attr_id]
            if attr then
                local old = attr.current
                attr.current = clamp_attr(attr, attr.current - resolve(cost_value, ability.level))
                if old ~= attr.current then
                    notify_attr_changed(state, attr_id, old, attr.current)
                end
            end
        end
    end

    -- 应用激活时效果
    for _, effect_def in ipairs(ability.spec.effects or {}) do
        local cloned = {}
        for k, v in pairs(effect_def) do
            cloned[k] = v
        end
        cloned.source = ability_id
        M.apply_effect(state, cloned, ability.level, ability.stack)
    end

    event_mod.dispatch_event(state, enum.EGameplayEvent.AbilityActivated, {
        ability_id = ability_id,
        payload = payload,
    })

    -- 非 Passive 技能在激活后自动结束（进入冷却）
    if ability.spec.activation_policy ~= enum.EAbilityActivationPolicy.Passive then
        M.end_ability(state, ability_id)
    end

    return true
end

---立即执行 Modifier（用于 Instant 效果）
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
local function apply_instant_modifiers(state, effect)
    for _, mod in ipairs(effect_mod.active_modifiers(effect)) do
        local attr = state.attributes[mod.def.attribute]
        if not attr then
            modifier_mod.warn("Instant effect 目标 attribute 不存在: " .. tostring(mod.def.attribute))
            goto continue
        end
        if not modifier_mod.is_active(mod, state.tags) then
            goto continue
        end
        local val = modifier_mod.value(mod)
        ---@cast val number
        local old = attr.current
        if mod.def.op == enum.EModifierOp.Add then
            attr.current = clamp_attr(attr, attr.current + val)
        elseif mod.def.op == enum.EModifierOp.Multiply then
            attr.current = clamp_attr(attr, attr.current * val)
        elseif mod.def.op == enum.EModifierOp.Override then
            attr.current = clamp_attr(attr, val)
        else
            modifier_mod.warn("Instant effect 不支持 Compound Modifier")
        end
        if old ~= attr.current then
            notify_attr_changed(state, mod.def.attribute, old, attr.current)
        end
        ::continue::
    end
end

---应用周期性触发（按属性聚合后一次性加入 Current）
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@param count number
local function apply_periodic_modifiers(state, effect, count)
    -- 按目标属性分组
    local groups = {}
    for _, mod in ipairs(effect_mod.active_modifiers(effect)) do
        local id = mod.def.attribute
        groups[id] = groups[id] or {}
        table.insert(groups[id], mod)
    end

    for _ = 1, count do
        for attr_id, mods in pairs(groups) do
            local attr = state.attributes[attr_id]
            if not attr then
                goto continue
            end
            -- 以 0 为基底，按 Modifier 规则计算本次周期增量
            local delta = modifier_mod.calc_attribute(0, mods, state.tags)
            if delta ~= 0 then
                local old = attr.current
                attr.current = clamp_attr(attr, attr.current + delta)
                if old ~= attr.current then
                    notify_attr_changed(state, attr_id, old, attr.current)
                end
            end
            ::continue::
        end
    end
end

---应用效果
---@param state mini_gas.EntityState
---@param spec mini_gas.EffectDef
---@param level number
---@param stack number|nil
function M.apply_effect(state, spec, level, stack)
    level = level or 1
    stack = stack or 1
    local key = effect_key(spec.id)

    -- Stack 处理
    if state.effects[key] then
        local existing = state.effects[key]
        local policy = spec.stacking or enum.EStackingPolicy.None
        if policy == enum.EStackingPolicy.Add then
            local max_stack = spec.max_stack or math.huge
            existing.stack = math.min(existing.stack + stack, max_stack)
            existing.remaining = resolve(spec.duration, level)
            event_mod.dispatch_event(state, enum.EGameplayEvent.EffectApplied, { effect_id = spec.id, stack = existing.stack })
            return
        elseif policy == enum.EStackingPolicy.Refresh then
            existing.remaining = resolve(spec.duration, level)
            existing.stack = math.max(existing.stack, stack)
            existing.level = level
            event_mod.dispatch_event(state, enum.EGameplayEvent.EffectApplied, { effect_id = spec.id, refreshed = true })
            return
        elseif policy == enum.EStackingPolicy.Replace then
            M.remove_effect(state, spec.id)
        else
            M.remove_effect(state, spec.id)
        end
    end

    local effect = effect_mod.GameplayEffect.new(spec, level, stack)

    -- Instant 效果直接生效，不进入持续列表
    if spec.duration_policy == enum.EDurationPolicy.Instant then
        if effect_mod.is_active(effect, state.tags) then
            apply_instant_modifiers(state, effect)
        end
        event_mod.dispatch_event(state, enum.EGameplayEvent.EffectApplied, { effect_id = spec.id })
        return
    end

    -- 授予标签
    for _, tag in ipairs(spec.granted_tags or {}) do
        add_granted_tag(state, tag, key)
    end

    state.effects[key] = effect
    event_mod.dispatch_event(state, enum.EGameplayEvent.EffectApplied, { effect_id = spec.id })
end

---移除效果
---@param state mini_gas.EntityState
---@param effect_id mini_gas.EffectId
function M.remove_effect(state, effect_id)
    local key = effect_key(effect_id)
    local effect = state.effects[key]
    if not effect then
        return
    end

    remove_granted_tags(state, effect.spec.granted_tags or {}, key)
    state.effects[key] = nil
    event_mod.dispatch_event(state, enum.EGameplayEvent.EffectRemoved, { effect_id = effect_id })
end

---设置效果等级
---@param state mini_gas.EntityState
---@param effect_id mini_gas.EffectId
---@param level number
function M.set_effect_level(state, effect_id, level)
    local key = effect_key(effect_id)
    local effect = state.effects[key]
    if effect then
        effect.level = level
    end
end

---设置效果 Stack
---@param state mini_gas.EntityState
---@param effect_id mini_gas.EffectId
---@param stack number
function M.set_effect_stack(state, effect_id, stack)
    local key = effect_key(effect_id)
    local effect = state.effects[key]
    if effect then
        effect.stack = stack
    end
end

---推进单个效果的周期与生命周期
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@param dt number
---@return boolean 是否仍然存活
local function update_effect(state, effect, dt)
    if not effect_mod.is_active(effect, state.tags) then
        -- 挂起状态：仍然推进剩余时间，但不触发周期效果
        if effect.spec.duration_policy == enum.EDurationPolicy.HasDuration then
            effect.remaining = effect.remaining - dt
            if effect.remaining <= 0 then
                return false
            end
        end
        return true
    end

    effect.elapsed = effect.elapsed + dt
    local period = effect_mod.period_value(effect)
    if period > 0 then
        local trigger_count = math.floor(effect.elapsed / period) - effect.last_trigger_count
        if trigger_count > 0 then
            apply_periodic_modifiers(state, effect, trigger_count)
            effect.last_trigger_count = effect.last_trigger_count + trigger_count
        end
    end

    if effect.spec.duration_policy == enum.EDurationPolicy.HasDuration then
        effect.remaining = effect.remaining - dt
        if effect.remaining <= 0 then
            return false
        end
    end

    return true
end

---更新状态
---@param state mini_gas.EntityState
---@param dt number 秒
function M.update(state, dt)
    -- 效果生命周期
    local expired = {}
    for key, effect in pairs(state.effects) do
        if not update_effect(state, effect, dt) then
            table.insert(expired, key)
        end
    end
    for _, key in ipairs(expired) do
        local effect = state.effects[key]
        if effect then
            M.remove_effect(state, effect.spec.id)
        end
    end

    -- 技能冷却
    for _, ability in pairs(state.abilities) do
        if ability.cooldown_remaining > 0 then
            ability.cooldown_remaining = ability.cooldown_remaining - dt
            if ability.cooldown_remaining < 0 then
                ability.cooldown_remaining = 0
            end
        end
    end

    -- 任务推进
    task_mod.update_tasks(state, dt)
end

---批量更新世界状态
---@param world mini_gas.WorldState
---@param dt number 秒
function M.update_world(world, dt)
    for _, state in pairs(world.entities) do
        M.update(state, dt)
    end
end

return M
