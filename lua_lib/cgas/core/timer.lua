--- Time source with global and per-ASC (Ability System Component) dilation.
--- Dilation scales delta time for slow-motion or speed-up effects.

local M = {}
M.__index = M

--- Create a new Timer.
---@return Timer
function M.new()
    local self = setmetatable({}, M)
    self._time = 0
    self._global_dilation = 1.0
    self._local_dilations = {}  -- asc_id -> dilation
    return self
end

--- Advance time by a delta.
---@param dt number
function M:advance(dt)
    self._time = self._time + dt
end

--- Get current time.
---@return number
function M:now()
    return self._time
end

--- Set global dilation.
---@param dilation number
function M:set_global_dilation(dilation)
    self._global_dilation = dilation
end

--- Set local dilation for an ASC.
---@param asc_id integer
---@param dilation number
function M:set_local_dilation(asc_id, dilation)
    self._local_dilations[asc_id] = dilation
end

--- Scale delta time by global and local dilation.
---@param asc_id integer
---@param dt number
---@return number scaled_dt
function M:scale_dt(asc_id, dt)
    local local_dilation = self._local_dilations[asc_id] or 1.0
    return dt * self._global_dilation * local_dilation
end

return M
