local object = require("cgas.core.object")
local Scheduler = require("cgas.core.scheduler")
local EventBus = require("cgas.core.event")
local TimeSource = require("cgas.core.timer")
local Registry = require("cgas.core.registry")
local tag = require("cgas.semantics.tag")
local attr = require("cgas.semantics.attribute")
local effect_mod = require("cgas.semantics.effect")
local ability_mod = require("cgas.semantics.ability")
local cue_mod = require("cgas.semantics.cue")

local M = {}

---@class cgas.semantics.ASC
---@field handle integer
---@field scheduler cgas.core.Scheduler
---@field event_bus cgas.core.EventBus
---@field time_source cgas.core.TimeSource
---@field registry cgas.core.Registry
---@field attribute_sets table<string, cgas.semantics.AttributeSet>
---@field granted_abilities table<integer, cgas.semantics.GameplayAbility>
---@field active_effects table<integer, cgas.semantics.ActiveGameplayEffect>
---@field owned_tags cgas.semantics.GameplayTagContainer
---@field blocked_tags cgas.semantics.GameplayTagContainer
---@field cue_manager cgas.semantics.GameplayCueManager
local ASC = {}
ASC.__index = ASC

---Create an ASC.
---@param opts table
---@return cgas.semantics.ASC|nil asc
---@return string|nil error
function ASC.new(opts)
    opts = opts or {}
    local asc = setmetatable({
        handle = object.next_handle(),
        scheduler = opts.scheduler or Scheduler.new(),
        event_bus = opts.event_bus or EventBus.new(),
        time_source = opts.time_source or TimeSource.new(),
        registry = opts.registry or Registry.new(),
        attribute_sets = {},
        granted_abilities = {},
        active_effects = {},
        owned_tags = tag.GameplayTagContainer.new(),
        blocked_tags = tag.GameplayTagContainer.new(),
        cue_manager = cue_mod.GameplayCueManager.new(),
    }, ASC)
    asc.scheduler:register(asc.handle, function(dt) asc:_tick(dt) end, 10)
    return asc, nil
end

---@param raw_dt number
function ASC:_tick(raw_dt)
    local dt = self.time_source:scale_dt(self.handle, raw_dt)
    self.time_source:advance(dt)
    self:_update_effects(dt)
    self:_update_abilities(dt)
    self.event_bus:dispatch()
    self.event_bus:emit("on_post_update", { asc = self, dt = dt })
    self.event_bus:dispatch()
end

---@param raw_dt number
function ASC:update(raw_dt)
    self.scheduler:update(raw_dt)
end

---@param dt number
function ASC:_update_effects(dt)
    local expired = {}
    for handle, active in pairs(self.active_effects) do
        active:update(dt)
        if active:is_expired() then
            table.insert(expired, handle)
        end
    end
    for _, handle in ipairs(expired) do
        self:remove_active_effect(handle)
    end
end

---@param dt number
function ASC:_update_abilities(dt)
    for _, ab in pairs(self.granted_abilities) do
        ab:update(dt)
    end
end

---Add an AttributeSet.
---@param attr_set_class table
---@return cgas.semantics.AttributeSet|nil attr_set
---@return string|nil error
function ASC:add_attribute_set(attr_set_class)
    local set = attr.AttributeSet.new(attr_set_class.name)
    if attr_set_class.on_init then
        attr_set_class:on_init(set)
    end
    self.attribute_sets[attr_set_class.name] = set
    return set, nil
end

---Get an AttributeSet by name.
---@param set_name string
---@return cgas.semantics.AttributeSet|nil
function ASC:get_attribute_set(set_name)
    return self.attribute_sets[set_name]
end

---Get an attribute by path "SetName.AttributeName".
---@param attr_path string
---@return cgas.semantics.Attribute|nil
function ASC:get_attribute(attr_path)
    local set_name, attr_name = attr_path:match("^([^%.]+)%.([^%.]+)$")
    if not set_name then return nil end
    local set = self.attribute_sets[set_name]
    if not set then return nil end
    return set:get(attr_name)
end

---Grant an ability.
---@param ability_class table
---@param source_level integer?
---@return integer|nil ability_handle
---@return string|nil error
function ASC:give_ability(ability_class, source_level)
    local ab = ability_mod.GameplayAbility.new(self, ability_class, source_level)
    self.granted_abilities[ab.handle] = ab
    return ab.handle, nil
end

---Remove an ability.
---@param ability_handle integer
---@return boolean ok
function ASC:remove_ability(ability_handle)
    local ab = self.granted_abilities[ability_handle]
    if not ab then return false end
    if ab.state == "active" then
        ab:end_ability()
    end
    self.granted_abilities[ability_handle] = nil
    return true
end

---Find ability by tag.
---@param t cgas.semantics.GameplayTag
---@return integer|nil ability_handle
function ASC:find_ability_by_tag(t)
    for handle, ab in pairs(self.granted_abilities) do
        if ab.ability_tags:has(t) then
            return handle
        end
    end
    return nil
end

---Try activate ability by input id.
---@param input_id integer|string
---@return boolean ok
function ASC:try_activate_ability_by_input(input_id)
    for _, ab in pairs(self.granted_abilities) do
        if ab.input_id == input_id then
            return self:try_activate_ability(ab.handle)
        end
    end
    return false
end

---Try activate ability by handle.
---@param ability_handle integer
---@return boolean ok
---@return string|nil error
function ASC:try_activate_ability(ability_handle)
    local ab = self.granted_abilities[ability_handle]
    if not ab then return false, "invalid ability handle" end
    if not ab:activate() then return false, "activation failed" end
    ab:commit()
    return true
end

---Apply an effect spec.
---@param spec cgas.semantics.GameplayEffectSpec
---@return integer|nil active_effect_handle
---@return string|nil error
function ASC:apply_effect(spec)
    local effect = spec.effect_class
    if effect.duration_policy == "instant" then
        local active = effect_mod.ActiveGameplayEffect.new({
            effect = effect,
            target_set = self:_resolve_attribute_set(effect),
            source_set = spec.source and self:_source_attribute_set(spec.source, effect),
            level = spec.level or 1,
        })
        active:apply_instant()
        self.event_bus:emit("on_effect_applied", { effect = effect, target = self, source = spec.source })
        self.cue_manager:trigger_effect_cues(effect, "on_apply", { target = self, source = spec.source })
        return active.handle, nil
    end

    local active = effect_mod.ActiveGameplayEffect.new({
        effect = effect,
        target_set = self:_resolve_attribute_set(effect),
        source_set = spec.source and self:_source_attribute_set(spec.source, effect),
        level = spec.level or 1,
    })
    active:on_apply()
    self.active_effects[active.handle] = active
    self.event_bus:emit("on_effect_applied", { effect = effect, target = self, source = spec.source, handle = active.handle })
    self.cue_manager:trigger_effect_cues(effect, "on_apply", { target = self, source = spec.source })
    return active.handle, nil
end

---@private
---@param effect cgas.semantics.GameplayEffect
---@return cgas.semantics.AttributeSet|nil
function ASC:_resolve_attribute_set(effect)
    for _, m in ipairs(effect.modifiers) do
        local set_name = m.attribute_name:match("^([^%.]+)%.[^%.]+$")
        if set_name then
            return self.attribute_sets[set_name]
        end
        for _, set in pairs(self.attribute_sets) do
            if set:get(m.attribute_name) then
                return set
            end
        end
    end
    return nil
end

---@private
---@param source_asc cgas.semantics.ASC
---@param effect cgas.semantics.GameplayEffect
---@return cgas.semantics.AttributeSet|nil
function ASC:_source_attribute_set(source_asc, effect)
    return self:_resolve_attribute_set(effect)
end

---Remove an active effect.
---@param active_effect_handle integer
---@return boolean ok
function ASC:remove_active_effect(active_effect_handle)
    local active = self.active_effects[active_effect_handle]
    if not active then return false end
    self.active_effects[active_effect_handle] = nil
    self.event_bus:emit("on_effect_removed", { effect = active.effect, target = self, handle = active.handle })
    self.cue_manager:trigger_effect_cues(active.effect, "on_remove", { target = self })
    return true
end

---Add a tag.
---@param t cgas.semantics.GameplayTag
function ASC:add_tag(t)
    self.owned_tags:add(t)
    self.event_bus:emit("on_tag_changed", { tag = t, added = true, asc = self })
end

---Remove a tag.
---@param t cgas.semantics.GameplayTag
function ASC:remove_tag(t)
    self.owned_tags:remove(t)
    self.event_bus:emit("on_tag_changed", { tag = t, added = false, asc = self })
end

---Match a tag query.
---@param query cgas.semantics.GameplayTagQuery
---@return boolean matches
function ASC:matches_tag_query(query)
    return query:matches(self.owned_tags)
end

---Destroy the ASC.
function ASC:destroy()
    for handle, _ in pairs(self.granted_abilities) do
        self:remove_ability(handle)
    end
    for handle, _ in pairs(self.active_effects) do
        self:remove_active_effect(handle)
    end
    self.attribute_sets = {}
    self.owned_tags = tag.GameplayTagContainer.new()
    self.scheduler:unregister(self.handle)
    self.event_bus:emit("on_asc_destroyed", { asc = self })
    self.event_bus:dispatch()
end

M.ASC = ASC

return M
