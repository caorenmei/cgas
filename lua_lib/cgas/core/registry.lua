--- Class registry for abilities, effects, and attribute sets.
--- Provides named lookup for GAS class definitions.

local M = {}

---@class cgas.core.Registry
---@field private _abilities table<string, table>
---@field private _effects table<string, table>
---@field private _attribute_sets table<string, table>
local Registry = M
Registry.__index = Registry

---Create a new Registry.
---@return cgas.core.Registry
function Registry.new()
    local self = setmetatable({}, Registry)
    self._abilities = {}
    self._effects = {}
    self._attribute_sets = {}
    return self
end

---Register an ability class.
---@param name string
---@param class table
function Registry:register_ability(name, class)
    self._abilities[name] = class
end

---Register an effect class.
---@param name string
---@param class table
function Registry:register_effect(name, class)
    self._effects[name] = class
end

---Register an attribute set class.
---@param name string
---@param class table
function Registry:register_attribute_set(name, class)
    self._attribute_sets[name] = class
end

---Retrieve a class by category and name.
---@param category "ability"|"effect"|"attribute_set"
---@param name string
---@return table|nil class
function Registry:get(category, name)
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
