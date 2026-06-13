local M = {}

---@class cgas.net.GameplayEvent
---@field event_name string
---@field payload table
---@field prediction_key cgas.net.PredictionKey?
local GameplayEvent = {}
GameplayEvent.__index = GameplayEvent

---Create a network gameplay event.
---@param event_name string
---@param payload table
---@return cgas.net.GameplayEvent
function M.new(event_name, payload)
    return setmetatable({
        event_name = event_name,
        payload = payload or {},
        prediction_key = nil,
    }, GameplayEvent)
end

return M
