--- EntityState / WorldState
--- 状态表均为无元表的普通 Lua 表。
local tag_mod = require("mini_gas.tag")

local M = {}

M.EntityState = {}
M.WorldState = {}

---创建新的实体状态（纯 Lua 表）
---@return mini_gas.EntityState
function M.EntityState.new()
    return {
        attributes = {},
        _attribute_defs = {},
        abilities = {},
        _ability_defs = {},
        effects = {},
        _effect_defs = {},
        tags = tag_mod.GameplayTagContainer.new(),
        event_listeners = {},
        tasks = {},
        _reactive_listeners = {},
        source = nil,
    }
end

---创建新的世界状态（纯 Lua 表）
---@return mini_gas.WorldState
function M.WorldState.new()
    return {
        entities = {},
    }
end

---注册实体状态
---@param world mini_gas.WorldState
---@param id string
---@param state mini_gas.EntityState
function M.register_entity(world, id, state)
    world.entities[id] = state
end

return M
