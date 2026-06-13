--- Scheduler with priority-sorted tick callbacks, deferred jobs, and periodic jobs.
--- Error isolation via pcall ensures one failing callback does not break others.

local M = {}
M.__index = M

--- Create a new Scheduler.
---@return Scheduler
function M.new()
    local self = setmetatable({}, M)
    self._tick_callbacks = {}  -- id -> { priority = number, callback = function }
    self._jobs = {}            -- id -> { type = "defer"|"every", callback = function, interval = number, elapsed = number }
    self._next_id = 0
    return self
end

--- Register a tick callback with optional priority (lower = earlier).
---@param id integer
---@param callback function
---@param priority? number
function M:register(id, callback, priority)
    self._tick_callbacks[id] = {
        priority = priority or 0,
        callback = callback,
    }
end

--- Unregister a tick callback.
---@param id integer
function M:unregister(id)
    self._tick_callbacks[id] = nil
end

--- Defer a callback after a delay.
---@param callback function
---@param delay number
---@return integer id
function M:defer(callback, delay)
    self._next_id = self._next_id + 1
    local id = self._next_id
    self._jobs[id] = {
        type = "defer",
        callback = callback,
        interval = delay,
        elapsed = 0,
    }
    return id
end

--- Schedule a periodic callback.
---@param callback function
---@param interval number
---@return integer id
function M:every(callback, interval)
    self._next_id = self._next_id + 1
    local id = self._next_id
    self._jobs[id] = {
        type = "every",
        callback = callback,
        interval = interval,
        elapsed = 0,
    }
    return id
end

--- Cancel a deferred or periodic job.
---@param id integer
function M:cancel(id)
    self._jobs[id] = nil
end

--- Update the scheduler with delta time.
---@param dt number
function M:update(dt)
    -- Collect and sort tick callbacks by priority
    local callbacks = {}
    for _, entry in pairs(self._tick_callbacks) do
        table.insert(callbacks, entry)
    end
    table.sort(callbacks, function(a, b)
        return a.priority < b.priority
    end)

    for _, entry in ipairs(callbacks) do
        local ok, err = pcall(entry.callback, dt)
        if not ok then
            -- Error isolation: silently swallow errors
        end
    end

    -- Update jobs
    local jobs_to_remove = {}
    for id, job in pairs(self._jobs) do
        job.elapsed = job.elapsed + dt
        if job.elapsed >= job.interval then
            if job.type == "defer" then
                local ok, err = pcall(job.callback)
                if not ok then
                    -- Error isolation
                end
                table.insert(jobs_to_remove, id)
            elseif job.type == "every" then
                job.elapsed = job.elapsed - job.interval
                local ok, err = pcall(job.callback)
                if not ok then
                    -- Error isolation
                end
            end
        end
    end

    for _, id in ipairs(jobs_to_remove) do
        self._jobs[id] = nil
    end
end

return M
