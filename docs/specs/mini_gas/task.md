
## 11. GameplayTask 轻量任务

### 11.1 设计目标

`GameplayTask` 提供延时、周期、等待事件三类轻量异步任务，用于替代复杂的协程/定时器调度：

- **delay**：指定时间后执行一次回调。
- **periodic**：按固定周期重复执行回调，可限制次数。
- **wait_event**：等待指定事件触发后执行回调。

任务实例保存在 `EntityState.tasks` 中，由 `MiniASC.update(state, defs, dt)` 统一推进。

### 11.2 任务类型

```lua
---@class mini_gas.GameplayTask
---@field kind "delay"|"periodic"|"wait_event"
---@field remaining number
---@field interval number
---@field event? mini_gas.GameplayEventId
---@field callback fun(payload:table?)|fun(dt:number)|nil
---@field repeat_count? number
---@field completed boolean
---@field listener? fun(payload:table?)
```

### 11.3 API

```lua
---创建延时任务
---@param delay number 秒
---@param callback fun(payload:table|nil)
---@return mini_gas.GameplayTask
function task_mod.delay(delay, callback) end

---创建周期任务
---@param period number 秒
---@param callback fun(dt:number) 每次触发传入间隔
---@param repeat_count number|nil 重复次数，nil 表示无限
---@return mini_gas.GameplayTask
function task_mod.periodic(period, callback, repeat_count) end

---创建等待事件任务
---@param event mini_gas.GameplayEventId
---@param callback fun(payload:table|nil)
---@return mini_gas.GameplayTask
function task_mod.wait_event(event, callback) end

---将任务注册到状态中
---@param state mini_gas.EntityState
---@param task mini_gas.GameplayTask
function task_mod.register_task(state, task) end
```

入口提供构造器对象：

```lua
local GameplayTask = mini_gas.GameplayTask

GameplayTask.delay(delay, callback)
GameplayTask.periodic(period, callback, repeat_count?)
GameplayTask.wait_event(event, callback)
GameplayTask.register_task(state, task)
```

### 11.4 实现要点

- `delay` 与 `periodic` 任务由 `MiniASC.update` 推进。
- `wait_event` 任务注册时会自动监听对应事件，事件触发后自动取消监听并标记完成。
- 已完成的任务会在下一次 `update` 时被清理出 `state.tasks`。
- `periodic` 在一个 `dt` 内可能触发多次，通过 `while` 循环保证不丢 Tick。

### 11.5 使用示例

```lua
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local Defs = mini_gas.Defs
local MiniASC = mini_gas.MiniASC
local GameplayTask = mini_gas.GameplayTask
local EGameplayEvent = mini_gas.EGameplayEvent

local state = EntityState.new()
local defs = Defs.new()

-- 延时任务
GameplayTask.register_task(state, GameplayTask.delay(2, function()
    print("2 秒后执行")
end))

-- 周期任务，限制 3 次
GameplayTask.register_task(state, GameplayTask.periodic(1, function(dt)
    print(string.format("周期触发，间隔 %.1f 秒", dt))
end, 3))

-- 等待事件任务
GameplayTask.register_task(state, GameplayTask.wait_event(EGameplayEvent.TagAdded, function(payload)
    print(string.format("标签 %s 被添加", payload.tag))
end))

-- 游戏主循环中推进
MiniASC.update(state, defs, 0.1)
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
