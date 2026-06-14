--- EntityState / WorldState / Defs
--- 状态表均为无元表的普通 Lua 表。
local tag_mod = require("mini_gas.tag")

local M = {}

M.EntityState = {}
M.WorldState = {}
M.Defs = {}

---创建新的实体状态（纯 Lua 表）
---@return mini_gas.EntityState
function M.EntityState.new()
    return {
        attributes = {},
        abilities = {},
        effects = {},
        tags = tag_mod.GameplayTagContainer.new(),
        event_listeners = {},
        tasks = {},
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

---创建新的配置定义表（纯 Lua 表）
---@return mini_gas.Defs
function M.Defs.new()
    return {
        attribute_defs = {},
        ability_defs = {},
        effect_defs = {},
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
