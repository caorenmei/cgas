local M = {}

---@class cgas.adapters.ManualRunner
---@field asc cgas.semantics.ASC
local ManualRunner = {}
ManualRunner.__index = ManualRunner

---Create a manual update adapter for an ASC.
---@param asc cgas.semantics.ASC
---@return cgas.adapters.ManualRunner
function M.new(asc)
    return setmetatable({ asc = asc }, ManualRunner)
end

---Drive one frame with raw dt.
---@param dt number
function ManualRunner:update(dt)
    self.asc:update(dt)
end

---Destroy the runner and the ASC.
function ManualRunner:destroy()
    self.asc:destroy()
end

return M
