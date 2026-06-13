local M = {}

---@class cgas.net.PredictionKey
---@field id integer
local PredictionKey = {}
PredictionKey.__index = PredictionKey

---Create a prediction key.
---@param id integer
---@return cgas.net.PredictionKey
function M.new(id)
    return setmetatable({ id = id }, PredictionKey)
end

return M
