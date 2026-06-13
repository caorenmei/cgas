local M = {}

---@class cgas.net.Context
---@field role "authority"|"simulated_proxy"|"autonomous_proxy"
local Context = {}
Context.__index = Context

---Create a default authority context.
---@return cgas.net.Context
function M.new()
    return setmetatable({ role = "authority" }, Context)
end

return M
