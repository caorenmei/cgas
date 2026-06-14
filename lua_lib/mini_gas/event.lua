--- GameplayEvent 派发与监听
local M = {}

---派发事件
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param payload table|nil
function M.dispatch_event(state, event, payload)
    local listeners = state.event_listeners[event]
    if not listeners then
        return
    end
    -- 遍历副本，避免监听回调中修改列表导致错误
    local copy = {}
    for i, fn in ipairs(listeners) do
        copy[i] = fn
    end
    for _, fn in ipairs(copy) do
        local ok, err = pcall(fn, payload)
        if not ok then
            io.stderr:write("[mini_gas.event] listener error: " .. tostring(err) .. "\n")
        end
    end
end

---监听事件
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param listener fun(payload:table|nil)
function M.listen_event(state, event, listener)
    state.event_listeners[event] = state.event_listeners[event] or {}
    table.insert(state.event_listeners[event], listener)
end

---移除事件监听
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param listener fun(payload:table|nil)
function M.unlisten_event(state, event, listener)
    local listeners = state.event_listeners[event]
    if not listeners then
        return
    end
    for i = #listeners, 1, -1 do
        if listeners[i] == listener then
            table.remove(listeners, i)
        end
    end
end

return M
