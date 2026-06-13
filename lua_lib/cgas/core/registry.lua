--- Class registry for abilities, effects, and attribute sets.
--- Provides named lookup for GAS class definitions.

local M = {}
M.__index = M

--- Create a new Registry.
---@return Registry
function M.new()
    local self = setmetatable({}, M)
    self._abilities = {}
    self._effects = {}
    self._attribute_sets = {}
    return self
end

--- Register an ability class.
---@param name string
---@param class table
function M:register_ability(name, class)
    self._abilities[name] = class
end

--- Register an effect class.
---@param name string
---@param class table
function M:register_effect(name, class)
    self._effects[name] = class
end

--- Register an attribute set class.
---@param name string
---@param class table
function M:register_attribute_set(name, class)
    self._attribute_sets[name] = class
end

--- Retrieve a class by category and name.
---@param category "ability"|"effect"|"attribute_set"
---@param name string
---@return table|nil class
function M:get(category, name)
    if category == "ability" then
        return self._abilities[name]
    elseif category == "effect" then
        return self._effects[name]
    elseif category == "attribute_set" then
        return self._attribute_sets[name]
    end
    return nil
end

return M
