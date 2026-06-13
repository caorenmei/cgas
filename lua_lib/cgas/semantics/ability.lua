local object = require("cgas.core.object")
local tag = require("cgas.semantics.tag")

local M = {}

---@class cgas.semantics.GameplayAbility
---@field handle integer
---@field asc cgas.semantics.ASC
---@field class table
---@field state "inactive"|"committing"|"active"|"ending"
---@field instance_policy "non_instanced"|"instanced_per_actor"|"instanced_per_execution"
---@field level integer
---@field input_id integer|string|nil
---@field ability_tags cgas.semantics.GameplayTagContainer
---@field activation_owned_tags cgas.semantics.GameplayTagContainer
---@field activation_blocked_tags cgas.semantics.GameplayTagContainer
---@field activation_required_tags cgas.semantics.GameplayTagQuery
---@field cancel_abilities_with_tag cgas.semantics.GameplayTagContainer
---@field block_abilities_with_tag cgas.semantics.GameplayTagContainer
---@field cost_effect_class table|nil
---@field cooldown_effect_class table|nil
---@field active_tasks table<integer, cgas.semantics.AbilityTask>
local GameplayAbility = {}
GameplayAbility.__index = GameplayAbility

---Evaluate a class field that may be a value or a function.
---@param cls table
---@param key string
---@return any
local function class_field(cls, key)
    local v = cls[key]
    if type(v) == "function" then
        return v(cls)
    end
    return v
end

---Create an ability instance.
---@param asc cgas.semantics.ASC
---@param class table
---@param level integer?
---@return cgas.semantics.GameplayAbility
function GameplayAbility.new(asc, class, level)
    local ab = setmetatable({
        handle = object.next_handle(),
        asc = asc,
        class = class,
        state = "inactive",
        instance_policy = class.instance_policy or "instanced_per_execution",
        level = level or 1,
        input_id = class.input_id,
        ability_tags = class_field(class, "ability_tags") or tag.GameplayTagContainer.new(),
        activation_owned_tags = class_field(class, "activation_owned_tags") or tag.GameplayTagContainer.new(),
        activation_blocked_tags = class_field(class, "activation_blocked_tags") or tag.GameplayTagContainer.new(),
        activation_required_tags = class_field(class, "activation_required_tags") or tag.GameplayTagQuery.new(),
        cancel_abilities_with_tag = class_field(class, "cancel_abilities_with_tag") or tag.GameplayTagContainer.new(),
        block_abilities_with_tag = class_field(class, "block_abilities_with_tag") or tag.GameplayTagContainer.new(),
        cost_effect_class = class.cost_effect_class,
        cooldown_effect_class = class.cooldown_effect_class,
        active_tasks = {},
    }, GameplayAbility)
    return ab
end

---Check if activation is allowed.
---@return boolean can_activate
---@return string|nil error
function GameplayAbility:can_activate()
    if not self.activation_required_tags:matches(self.asc.owned_tags) then
        return false, "activation blocked: missing required tags"
    end
    if self.activation_blocked_tags:matches_any(self.asc.owned_tags) then
        return false, "activation blocked: owns blocked tags"
    end
    return true, nil
end

---Activate the ability.
---@return boolean ok
function GameplayAbility:activate()
    if self.state ~= "inactive" then return false end
    local ok, err = self:can_activate()
    if not ok then
        print("[cgas.ability] activate failed: " .. tostring(err))
        return false
    end
    self.state = "committing"
    for _, t in pairs(self.activation_owned_tags.tags) do
        self.asc.owned_tags:add(t)
    end
    self.state = "active"
    if self.class.ActivateAbility then
        local ok2, err2 = pcall(self.class.ActivateAbility, self)
        if not ok2 then
            print("[cgas.ability] ActivateAbility error: " .. tostring(err2))
            self:end_ability()
            return false
        end
    end
    return true
end

---Commit the ability (cost and cooldown).
---@return boolean ok
function GameplayAbility:commit()
    if self.state ~= "active" then return false end
    if self.cost_effect_class then
        self.asc:apply_effect({ effect_class = self.cost_effect_class, source = self.asc, level = self.level })
    end
    if self.cooldown_effect_class then
        self.asc:apply_effect({ effect_class = self.cooldown_effect_class, source = self.asc, level = self.level })
    end
    return true
end

---End the ability.
---@return boolean ok
function GameplayAbility:end_ability()
    if self.state ~= "active" then return false end
    self.state = "ending"
    for _, task in pairs(self.active_tasks) do
        task:finish(nil)
    end
    self.active_tasks = {}
    for _, t in pairs(self.activation_owned_tags.tags) do
        self.asc.owned_tags:remove(t)
    end
    self.state = "inactive"
    return true
end

---Cancel the ability.
---@return boolean ok
function GameplayAbility:cancel()
    if self.state ~= "active" then return false end
    return self:end_ability()
end

---Cancel other active abilities matching cancel_abilities_with_tag.
function GameplayAbility:cancel_matching_abilities()
    for _, other in pairs(self.asc.granted_abilities or {}) do
        if other ~= self and other.state == "active" then
            if other.ability_tags:matches_any(self.cancel_abilities_with_tag) then
                other:cancel()
            end
        end
    end
end

---Update the ability (and tasks).
---@param dt number
function GameplayAbility:update(dt)
    for _, task in pairs(self.active_tasks) do
        task:update(dt)
    end
end

M.GameplayAbility = GameplayAbility

return M
