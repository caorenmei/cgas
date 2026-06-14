--- EntityState / WorldState
--- 状态表均为无元表的普通 Lua 表，便于序列化与持久化。
local tag_mod = require("mini_gas.tag")

local M = {}

M.EntityState = {}
M.WorldState = {}

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
        _reactive_listeners = {},
        source = nil,
    }
end

---创建新的世界状态（纯 Lua 表）
---@return mini_gas.WorldState
function M.WorldState.new()
    return {
        entities = {},
        register_entity = function(self, id, state)
            self.entities[id] = state
        end,
    }
end

return M
