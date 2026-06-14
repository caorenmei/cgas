--- GameplayTask 轻量异步任务
--- 类型定义见 mini_gas.types
local event_mod = require("mini_gas.event")

local M = {}

---@param kind "delay"|"periodic"|"wait_event"
---@param opts table
---@return mini_gas.GameplayTask
local function new_task(kind, opts)
    return {
        kind = kind,
        remaining = opts.remaining or 0,
        interval = opts.interval or 0,
        event = opts.event,
        callback = opts.callback,
        repeat_count = opts.repeat_count,
        completed = false,
    }
end

---创建延时任务
---@param delay number 秒
---@param callback fun(payload:table|nil)
---@return mini_gas.GameplayTask
function M.delay(delay, callback)
    return new_task("delay", { remaining = delay, callback = callback })
end

---创建周期任务
---@param period number 秒
---@param callback fun(dt:number) 每次触发传入间隔
---@param repeat_count number|nil 重复次数，nil 表示无限
---@return mini_gas.GameplayTask
function M.periodic(period, callback, repeat_count)
    return new_task("periodic", {
        remaining = period,
        interval = period,
        callback = callback,
        repeat_count = repeat_count,
    })
end

---创建等待事件任务
---@param event mini_gas.GameplayEventId
---@param callback fun(payload:table|nil)
---@return mini_gas.GameplayTask
function M.wait_event(event, callback)
    return new_task("wait_event", { event = event, callback = callback })
end

---将任务注册到状态中
---@param state mini_gas.EntityState
---@param task mini_gas.GameplayTask
function M.register_task(state, task)
    state.tasks = state.tasks or {}
    local tasks = state.tasks
    tasks[#tasks + 1] = task
    if task.kind == "wait_event" and task.event then
        local wrapper
        wrapper = function(payload)
            task.completed = true
            if task.callback then
                task.callback(payload)
            end
            event_mod.unlisten_event(state, task.event, wrapper)
        end
        task._listener = wrapper
        event_mod.listen_event(state, task.event, wrapper)
    end
    return task
end

---推进任务
---@param state mini_gas.EntityState
---@param dt number 秒
function M.update_tasks(state, dt)
    if not state.tasks then
        return
    end
    local i = 1
    while i <= #state.tasks do
        local task = state.tasks[i]
        if task.completed then
            table.remove(state.tasks, i)
            goto continue
        end

        if task.kind == "delay" then
            task.remaining = task.remaining - dt
            if task.remaining <= 0 then
                task.completed = true
                if task.callback then
                    task.callback(nil)
                end
                table.remove(state.tasks, i)
                goto continue
            end
        elseif task.kind == "periodic" then
            task.remaining = task.remaining - dt
            while not task.completed and task.remaining <= 0 do
                task.remaining = task.remaining + task.interval
                if task.callback then
                    task.callback(task.interval)
                end
                if task.repeat_count then
                    task.repeat_count = task.repeat_count - 1
                    if task.repeat_count <= 0 then
                        task.completed = true
                        break
                    end
                end
            end
            if task.completed then
                table.remove(state.tasks, i)
                goto continue
            end
        end

        i = i + 1
        ::continue::
    end
end

M.GameplayTask = {
    delay = M.delay,
    periodic = M.periodic,
    wait_event = M.wait_event,
    register_task = M.register_task,
}

return M
