--- Scheduler with priority-sorted tick callbacks, deferred jobs, and periodic jobs.
--- Error isolation via pcall ensures one failing callback does not break others.

local M = {}

---@class cgas.core.Scheduler
---@field private _tick_callbacks table<integer, {priority: number, callback: function}>
---@field private _jobs table<integer, {type: string, callback: function, interval: number, elapsed: number}>
---@field private _next_id integer
local Scheduler = M
Scheduler.__index = Scheduler

---Create a new Scheduler.
---@return cgas.core.Scheduler
function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self._tick_callbacks = {}
    self._jobs = {}
    self._next_id = 0
    return self
end

---Register a tick callback with optional priority (lower = earlier).
---@param id integer
---@param callback function
---@param priority? number
function Scheduler:register(id, callback, priority)
    self._tick_callbacks[id] = {
        priority = priority or 0,
        callback = callback,
    }
end

---Unregister a tick callback.
---@param id integer
function Scheduler:unregister(id)
    self._tick_callbacks[id] = nil
end

---Defer a callback after a delay.
---@param callback function
---@param delay number
---@return integer id
function Scheduler:defer(callback, delay)
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

---Schedule a periodic callback.
---@param callback function
---@param interval number
---@return integer id
function Scheduler:every(callback, interval)
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

---Cancel a deferred or periodic job.
---@param id integer
function Scheduler:cancel(id)
    self._jobs[id] = nil
end

---Update the scheduler with delta time.
---@param dt number
function Scheduler:update(dt)
    -- Collect and sort tick callbacks by priority
    local callbacks = {}
    for _, entry in pairs(self._tick_callbacks) do
        table.insert(callbacks, entry)
    end
    table.sort(callbacks, function(a, b)
        return a.priority < b.priority
    end)

    for _, entry in ipairs(callbacks) do
        local ok = pcall(entry.callback, dt)
        if not ok then
            print("[cgas.scheduler] tick error")
        end
    end

    -- Update jobs
    local jobs_to_remove = {}
    for id, job in pairs(self._jobs) do
        job.elapsed = job.elapsed + dt
        if job.elapsed >= job.interval then
            if job.type == "defer" then
                local ok = pcall(job.callback)
                if not ok then
                    print("[cgas.scheduler] job error")
                end
                table.insert(jobs_to_remove, id)
            elseif job.type == "every" then
                job.elapsed = job.elapsed - job.interval
                local ok = pcall(job.callback)
                if not ok then
                    print("[cgas.scheduler] job error")
                end
            end
        end
    end

    for _, id in ipairs(jobs_to_remove) do
        self._jobs[id] = nil
    end
end

return M
