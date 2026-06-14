--- MiniASC 无状态函数集合
local enum = require("mini_gas.enum")
local attribute_mod = require("mini_gas.attribute")
local modifier_mod = require("mini_gas.modifier")
local effect_mod = require("mini_gas.effect")
local ability_mod = require("mini_gas.ability")
local event_mod = require("mini_gas.event")
local task_mod = require("mini_gas.task")
local tag_mod = require("mini_gas.tag")
local log_mod = require("mini_gas.log")

local M = {}

---获取属性定义
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@return mini_gas.AttributeDef|nil
local function attr_def(state, attr_id)
    return state._attribute_defs[attr_id]
end

---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@param value number
---@return number
local function clamp_attr(state, attr_id, value)
    local def = attr_def(state, attr_id)
    if not def then
        return value
    end
    return attribute_mod.clamp(def, value)
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

---解析常量或成长函数
---@param value number | mini_gas.GrowthCurve
---@param level number
---@return number
local function resolve(value, level)
    return ability_mod.resolve_value(value, level)
end

---派发属性变化事件
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@param old_value number
---@param new_value number
local function notify_attr_changed(state, attr_id, old_value, new_value)
    event_mod.dispatch_event(state, enum.EGameplayEvent.AttributeChanged, {
        attribute = attr_id,
        old_value = old_value,
        new_value = new_value,
    })
end

---注册属性定义
---@param state mini_gas.EntityState
---@param defs mini_gas.AttributeDef[]
function M.register_attributes(state, defs)
    for _, def in ipairs(defs or {}) do
        state._attribute_defs[def.name] = def
        state.attributes[def.name] = attribute_mod.calc_base(def, 1)
    end
end

---获取属性 Base 值
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@return number
function M.get_base(state, attr_id)
    return state.attributes[attr_id] or 0
end

---设置属性 Current 值
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@param value number
function M.set_current(state, attr_id, value)
    local def = attr_def(state, attr_id)
    if not def then
        log_mod.warn("set_current: attribute not found: " .. tostring(attr_id))
        return
    end
    local old = state.attributes[attr_id] or 0
    state.attributes[attr_id] = clamp_attr(state, attr_id, value)
    if old ~= state.attributes[attr_id] then
        notify_attr_changed(state, attr_id, old, state.attributes[attr_id])
    end
end

---收集某属性的所有生效 Modifier（周期性效果不参与持续聚合）
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@return mini_gas.Modifier[]
local function collect_modifiers(state, attr_id)
    local mods = {}
    for _, effect in pairs(state.effects) do
        if effect_mod.is_active(state, effect) and effect_mod.period_value(state, effect) <= 0 then
            for _, mod in ipairs(effect_mod.active_modifiers(state, effect)) do
                local mod_def = modifier_mod.find_def and modifier_mod.find_def(state, mod)
                if mod_def and mod_def.attribute == attr_id then
                    mods[#mods + 1] = mod
                end
            end
        end
    end
    return mods
end

---获取属性 Current 值
---@param state mini_gas.EntityState
---@param attr_id mini_gas.AttributeId
---@return number
function M.get_current(state, attr_id)
    local def = attr_def(state, attr_id)
    if not def then
        return 0
    end
    local base = state.attributes[attr_id] or 0
    local mods = collect_modifiers(state, attr_id)
    local value = modifier_mod.calc_attribute(base, state, mods)
    return clamp_attr(state, attr_id, value)
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
    state._ability_defs[spec.id] = spec
    local ability = ability_mod.GameplayAbility.new(spec.id, level, stack)
    state.abilities[key] = ability

    for _, tag in ipairs(spec.grant_tags or {}) do
        add_granted_tag(state, tag, key)
    end

    if spec.activation_policy == enum.EAbilityActivationPolicy.Reactive and spec.activation_event then
        local listener = function(payload)
            M.try_activate_ability(state, spec.id, payload)
        end
        state._reactive_listeners[key] = listener
        event_mod.listen_event(state, spec.activation_event, listener)
    end

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

    local def = state._ability_defs[ability_id]

    if def and def.activation_policy == enum.EAbilityActivationPolicy.Reactive and def.activation_event then
        local listener = state._reactive_listeners[key]
        if listener then
            event_mod.unlisten_event(state, def.activation_event, listener)
            state._reactive_listeners[key] = nil
        end
    end

    remove_granted_tags(state, def and def.grant_tags or {}, key)

    for _, effect in pairs(state.effects) do
        local effect_def = state._effect_defs[effect.spec_id]
        if effect_def and effect_def.source == ability_id then
            M.remove_effect(state, effect.spec_id)
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
        local effect_def = state._effect_defs[effect.spec_id]
        if effect_def and effect_def.source == ability_id then
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
        local effect_def = state._effect_defs[effect.spec_id]
        if effect_def and effect_def.source == ability_id then
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
    ability_mod.end_ability(state, ability)
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

    if not ability_mod.can_activate(state, ability) then
        return false
    end

    ability_mod.activate(ability)

    local def = state._ability_defs[ability_id]

    if def and def.cost then
        for attr_id, cost_value in pairs(def.cost) do
            local old = state.attributes[attr_id] or 0
            state.attributes[attr_id] = clamp_attr(state, attr_id, old - resolve(cost_value, ability.level))
            if old ~= state.attributes[attr_id] then
                notify_attr_changed(state, attr_id, old, state.attributes[attr_id])
            end
        end
    end

    if def then
        for _, effect_def in ipairs(def.effects or {}) do
            local cloned = {}
            for k, v in pairs(effect_def) do
                cloned[k] = v
            end
            cloned.source = ability_id
            M.apply_effect(state, cloned, ability.level, ability.stack)
        end
    end

    event_mod.dispatch_event(state, enum.EGameplayEvent.AbilityActivated, {
        ability_id = ability_id,
        payload = payload,
    })

    if def and def.activation_policy ~= enum.EAbilityActivationPolicy.Passive then
        M.end_ability(state, ability_id)
    end

    return true
end

---立即执行 Modifier（用于 Instant 效果）
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
local function apply_instant_modifiers(state, effect)
    for _, mod in ipairs(effect_mod.active_modifiers(state, effect)) do
        local mod_def = modifier_mod.find_def and modifier_mod.find_def(state, mod)
        if not mod_def then
            log_mod.warn("Instant effect modifier def not found")
            goto continue
        end
        if not modifier_mod.is_active(state, mod) then
            goto continue
        end
        local attr_id = mod_def.attribute
        local def = attr_def(state, attr_id)
        if not def then
            log_mod.warn("Instant effect 目标 attribute 不存在: " .. tostring(attr_id))
            goto continue
        end
        local val = modifier_mod.value(state, mod)
        if type(val) == "function" then
            log_mod.warn("Instant effect 不支持 Compound Modifier")
            goto continue
        end
        ---@cast val number
        local old = state.attributes[attr_id] or 0
        if mod_def.op == enum.EModifierOp.Add then
            state.attributes[attr_id] = clamp_attr(state, attr_id, old + val)
        elseif mod_def.op == enum.EModifierOp.Multiply then
            state.attributes[attr_id] = clamp_attr(state, attr_id, old * val)
        elseif mod_def.op == enum.EModifierOp.Override then
            state.attributes[attr_id] = clamp_attr(state, attr_id, val)
        else
            log_mod.warn("Instant effect 不支持 Compound Modifier")
        end
        if old ~= state.attributes[attr_id] then
            notify_attr_changed(state, attr_id, old, state.attributes[attr_id])
        end
        ::continue::
    end
end

---应用周期性触发（按属性聚合后一次性加入 Current）
---@param state mini_gas.EntityState
---@param effect mini_gas.GameplayEffect
---@param count number
local function apply_periodic_modifiers(state, effect, count)
    local groups = {}
    for _, mod in ipairs(effect_mod.active_modifiers(state, effect)) do
        local mod_def = modifier_mod.find_def and modifier_mod.find_def(state, mod)
        if mod_def then
            local id = mod_def.attribute
            groups[id] = groups[id] or {}
            local g = groups[id]
            g[#g + 1] = mod
        end
    end

    for _ = 1, count do
        for attr_id, mods in pairs(groups) do
            local def = attr_def(state, attr_id)
            if not def then
                goto continue
            end
            local delta = modifier_mod.calc_attribute(0, state, mods)
            if delta ~= 0 then
                local old = state.attributes[attr_id] or 0
                state.attributes[attr_id] = clamp_attr(state, attr_id, old + delta)
                if old ~= state.attributes[attr_id] then
                    notify_attr_changed(state, attr_id, old, state.attributes[attr_id])
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
    state._effect_defs[spec.id] = spec

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
        else
            M.remove_effect(state, spec.id)
        end
    end

    local effect = effect_mod.GameplayEffect.new(spec.id, level, stack)
    local def = state._effect_defs[spec.id]
    if def and def.duration_policy == enum.EDurationPolicy.HasDuration then
        effect.remaining = resolve(spec.duration, level)
    end

    if def and def.duration_policy == enum.EDurationPolicy.Instant then
        if effect_mod.is_active(state, effect) then
            apply_instant_modifiers(state, effect)
        end
        event_mod.dispatch_event(state, enum.EGameplayEvent.EffectApplied, { effect_id = spec.id })
        return
    end

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

    local def = state._effect_defs[effect_id]
    remove_granted_tags(state, def and def.granted_tags or {}, key)
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
    if not effect_mod.is_active(state, effect) then
        local def = state._effect_defs[effect.spec_id]
        if def and def.duration_policy == enum.EDurationPolicy.HasDuration then
            effect.remaining = effect.remaining - dt
            if effect.remaining <= 0 then
                return false
            end
        end
        return true
    end

    effect.elapsed = effect.elapsed + dt
    local period = effect_mod.period_value(state, effect)
    if period > 0 then
        local trigger_count = math.floor(effect.elapsed / period) - effect.last_trigger_count
        if trigger_count > 0 then
            apply_periodic_modifiers(state, effect, trigger_count)
            effect.last_trigger_count = effect.last_trigger_count + trigger_count
        end
    end

    local def = state._effect_defs[effect.spec_id]
    if def and def.duration_policy == enum.EDurationPolicy.HasDuration then
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
    local expired = {}
    for key, effect in pairs(state.effects) do
        if not update_effect(state, effect, dt) then
            expired[#expired + 1] = key
        end
    end
    for _, key in ipairs(expired) do
        local effect = state.effects[key]
        if effect then
            M.remove_effect(state, effect.spec_id)
        end
    end

    for _, ability in pairs(state.abilities) do
        if ability.cooldown_remaining > 0 then
            ability.cooldown_remaining = ability.cooldown_remaining - dt
            if ability.cooldown_remaining < 0 then
                ability.cooldown_remaining = 0
            end
        end
    end

    task_mod.update_tasks(state, dt)
end

---批量更新世界状态
---@param world mini_gas.WorldState
---@param dt number 秒
function M.update_world(world, dt)
    for _, entity_state in pairs(world.entities) do
        M.update(entity_state, dt)
    end
end

return M
