--- EntityState / WorldState
local tag_mod = require("mini_gas.tag")

local M = {}

---@class mini_gas.EntityState
---@field attributes table<mini_gas.AttributeId, mini_gas.Attribute>
---@field abilities table<string, mini_gas.GameplayAbility>
---@field effects table<string, mini_gas.GameplayEffect>
---@field tags mini_gas.GameplayTagContainer
---@field event_listeners table<mini_gas.GameplayEventId, fun(payload:table|nil)[]>
---@field tasks mini_gas.GameplayTask[]
---@field _reactive_listeners table<string, fun(payload:table|nil)>
---@field source any
local EntityState = {}
EntityState.__index = EntityState

---创建新的实体状态
---@return mini_gas.EntityState
function EntityState.new()
    return setmetatable({
        attributes = {},
        abilities = {},
        effects = {},
        tags = tag_mod.GameplayTagContainer.new(),
        event_listeners = {},
        tasks = {},
        _reactive_listeners = {},
        source = nil,
    }, EntityState)
end

---@class mini_gas.WorldState
---@field entities table<string, mini_gas.EntityState>
local WorldState = {}
WorldState.__index = WorldState

---创建新的世界状态
---@return mini_gas.WorldState
function WorldState.new()
    return setmetatable({
        entities = {},
    }, WorldState)
end

---注册实体状态
---@param self mini_gas.WorldState
---@param id string
---@param state mini_gas.EntityState
function WorldState:register_entity(id, state)
    self.entities[id] = state
end

M.EntityState = EntityState
M.WorldState = WorldState

return M
