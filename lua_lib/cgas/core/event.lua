--- Queued Event Bus with deferred dispatch and error isolation.
--- Events are queued when emitted and dispatched on the next call to dispatch().
--- Listeners are isolated via pcall so one failing listener does not break others.

local M = {}
M.__index = M

--- Create a new EventBus.
---@return EventBus
function M.new()
    local self = setmetatable({}, M)
    self._listeners = {}       -- event_name -> { [id] = callback }
    self._queue = {}           -- array of { name, payload }
    self._next_id = 0
    self._dispatching = false
    self._pending = {}         -- queue for events emitted during dispatch
    return self
end

--- Subscribe to an event.
---@param event_name string
---@param callback function
---@return integer id
function M:subscribe(event_name, callback)
    self._next_id = self._next_id + 1
    local id = self._next_id
    if not self._listeners[event_name] then
        self._listeners[event_name] = {}
    end
    self._listeners[event_name][id] = callback
    return id
end

--- Unsubscribe by id.
---@param id integer
function M:unsubscribe(id)
    for event_name, listeners in pairs(self._listeners) do
        if listeners[id] then
            listeners[id] = nil
            -- Clean up empty listener tables
            local empty = true
            for _ in pairs(listeners) do
                empty = false
                break
            end
            if empty then
                self._listeners[event_name] = nil
            end
            return
        end
    end
end

--- Emit an event (queued, not dispatched immediately).
---@param event_name string
---@param payload table
function M:emit(event_name, payload)
    if self._dispatching then
        table.insert(self._pending, { name = event_name, payload = payload })
    else
        table.insert(self._queue, { name = event_name, payload = payload })
    end
end

--- Dispatch all queued events.
function M:dispatch()
    -- Swap queue
    local queue = self._queue
    self._queue = {}
    self._dispatching = true

    for _, event in ipairs(queue) do
        local listeners = self._listeners[event.name]
        if listeners then
            for _, callback in pairs(listeners) do
                local ok, err = pcall(callback, event.payload)
                if not ok then
                    -- Error isolation: silently swallow errors
                end
            end
        end
    end

    self._dispatching = false

    -- Move pending events to main queue for next dispatch
    if #self._pending > 0 then
        for _, event in ipairs(self._pending) do
            table.insert(self._queue, event)
        end
        self._pending = {}
    end
end

return M
