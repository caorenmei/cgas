
## 10. GameplayEvent 事件系统

### 10.1 设计目标

`GameplayEvent` 是 `mini-gas` 内部解耦通信机制：

- Ability、Effect、Attribute、Tag 的生命周期变化均通过事件通知。
- Reactive Ability 通过监听事件自动尝试激活。
- 业务系统可监听事件实现日志、任务、统计、表现触发等功能。

事件系统本身不维护任何状态，所有监听器保存在 `EntityState.event_listeners` 中。

### 10.2 事件类型

框架预定义生命周期事件：

| 事件 | 说明 | payload 示例 |
|------|------|-------------|
| `EGameplayEvent.AbilityActivated` | 技能成功激活 | `{ ability_id = ..., payload = ... }` |
| `EGameplayEvent.AbilityEnded` | 非 Passive 技能结束 | `{ ability_id = ... }` |
| `EGameplayEvent.EffectApplied` | 效果被应用 | `{ effect_id = ..., stack = ..., refreshed = ... }` |
| `EGameplayEvent.EffectRemoved` | 效果被移除 | `{ effect_id = ... }` |
| `EGameplayEvent.AttributeChanged` | 属性 Current 值变化 | `{ attribute = ..., old_value = ..., new_value = ... }` |
| `EGameplayEvent.TagAdded` | 标签被添加 | `{ tag = ..., source = ... }` |
| `EGameplayEvent.TagRemoved` | 标签被移除 | `{ tag = ..., source = ... }` |

业务可自定义任意事件 ID，类型为 `mini_gas.GameplayEventId`（`string | integer`）。

### 10.3 API

```lua
---派发事件
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param payload table|nil
function event_mod.dispatch_event(state, event, payload) end

---监听事件
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param listener fun(payload:table|nil)
function event_mod.listen_event(state, event, listener) end

---移除事件监听
---@param state mini_gas.EntityState
---@param event mini_gas.GameplayEventId
---@param listener fun(payload:table|nil)
function event_mod.unlisten_event(state, event, listener) end
```

入口也提供同名便捷方法：

```lua
MiniASC.dispatch_event(state, event, payload?)
MiniASC.listen_event(state, event, listener)
```

### 10.4 实现要点

- 派发事件时先拷贝监听器数组，避免回调中增删监听器导致遍历错误。
- 监听器通过 `pcall` 调用，单个 listener 出错不会中断其他 listener。
- 错误会被注入的日志句柄记录（通过 `mini_gas.set_logger`）。

### 10.5 使用示例

```lua
local mini_gas = require("mini_gas")
local EntityState = mini_gas.EntityState
local MiniASC = mini_gas.MiniASC
local EGameplayEvent = mini_gas.EGameplayEvent

local state = EntityState.new()

-- 监听属性变化
MiniASC.listen_event(state, EGameplayEvent.AttributeChanged, function(payload)
    print(string.format("属性 %s 变化: %.1f -> %.1f",
        payload.attribute, payload.old_value, payload.new_value))
end)

-- 业务自定义事件
MiniASC.listen_event(state, "event.damage.taken", function(payload)
    print(string.format("受到 %.1f 点伤害", payload.damage))
end)

-- 派发自定义事件
MiniASC.dispatch_event(state, "event.damage.taken", { damage = 100 })
```

---

> [返回 Mini-GAS 设计文档总览](./README.md)
