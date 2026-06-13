# cgas Gameplay Ability System 设计文档

> 文档版本：v1.0  
> 编写日期：2026-06-14  
> 目标读者：cgas 库开发者  
> 关联项目：[cgas](../../../) — 基于 Lua 的 GAS 库

---

## 1. 目标与范围

### 1.1 目标

本设计文档为 `cgas`（C-Lua Gameplay Ability System）提供一套相对完整的实现规范，参考 Unreal Engine 的 Gameplay Ability System（GAS）核心概念与行为，但使用 Lua 原生机制进行重新设计与实现。文档目标是：

- 统一核心术语与模块边界，降低后续实现阶段的沟通成本。
- 明确各子系统的数据结构、接口签名、状态转换与关键算法。
- 作为单元测试与集成测试的验收依据。
- 在单机/本地模式下可立即落地，同时为未来网络扩展预留清晰的接口位置。

### 1.2 范围

本次设计覆盖 UE GAS 的全部核心子系统：

| 子系统 | 覆盖内容 |
|--------|----------|
| AbilitySystemComponent（ASC） | 实体上的 GAS 入口、Ability/AttributeSet/Effect 容器 |
| GameplayAbility（GA） | 技能定义、生命周期、实例化策略、Cost/Cooldown、标签约束 |
| AttributeSet / Attribute | 属性定义、Base/Current 值、Modifier 聚合、Meta Attribute |
| GameplayEffect（GE） | Instant/Duration/Infinite/Periodic、Modifier、Stack、Granted Tags |
| GameplayTag | 层级标签、容器、查询（Query）、标签变更事件 |
| GameplayCue | 表现层触发器、Cue 管理器、触发时机 |
| AbilityTask | 异步/延迟任务、常用任务类型、生命周期绑定 |
| Replication / Prediction | 单机模式下仅做概念层占位，定义未来扩展接口 |

### 1.3 约束

- **运行环境**：单机/本地，无实际网络同步需求。
- **集成方式**：独立 Lua 库，通过 `require("cgas")` 使用，由调用方在自定义游戏循环中调用 `update(dt)`。
- **语言与风格**：代码与配置使用英文，注释与文档使用简体中文；类型注解遵循 LuaCATS（参考 `docs/books/LuaCATS-annotations.md`）。
- **设计原则**：
  - 核心层与语义层分离，避免 UE 特定假设污染 Lua 原生实现。
  - 无全局可变状态，所有运行时状态由 ASC 与注入的 Scheduler/Timer 持有。
  - 事件驱动、非递归派发，错误隔离。

---

## 2. 总体架构

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                        使用方游戏代码                          │
│         (定义 Ability / AttributeSet / Effect / Cue)          │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────┐   ┌──────────────────┐   ┌────────────────┐
│  语义层       │   │     语义层        │   │    适配层       │
│ semantics.*  │   │    semantics.*   │   │   adapters.*   │
│ Ability /    │   │ Effect / Tag /   │   │  manual /      │
│ Attribute    │   │ Cue / Task       │   │  love2d / ...  │
└──────────────┘   └──────────────────┘   └────────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                  ┌──────────────────────┐
                  │       核心层          │
                  │     core.object      │
                  │     core.event       │
                  │     core.scheduler   │
                  │     core.timer       │
                  │     core.registry    │
                  └──────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │    网络层（占位）      │
                  │     net.context      │
                  │     net.prediction   │
                  │     net.event        │
                  └──────────────────────┘
```

### 2.2 各层职责

- **核心层（`cgas.core.*`）**：提供对象标识、事件总线、调度器、时间源、注册表等基础设施，完全使用 Lua 表与闭包实现，不依赖任何游戏引擎语义。
- **语义层（`cgas.semantics.*`）**：将 UE GAS 的核心概念映射为 Lua 模块，保持概念对齐但接口 Lua 化。
- **适配层（`cgas.adapters.*`）**：提供可选的游戏循环集成，例如 `manual`（手动 `update(dt)`）或 `love2d`（Love2D 集成示例）。
- **网络层（`cgas.net.*`）**：本次仅做接口占位，确保后续网络扩展时语义层改动最小。

### 2.3 核心设计原则

1. **显式依赖注入**：Scheduler、Timer、EventBus 均由 ASC 持有并注入，避免全局单例。
2. **句柄解耦**：所有运行时实例通过全局唯一句柄引用，减少循环引用风险，便于调试。
3. **事件非递归派发**：事件在 Tick 中批量处理，处理过程中产生的新事件进入下一帧队列。
4. **失败可预测**：公共接口对非法输入返回 `nil, error_message`，不抛出未处理异常。

---

## 3. 模块划分与目录结构

```
lua_lib/
├── cgas/
│   ├── init.lua                  -- 库入口，导出公共 API
│   ├── core/
│   │   ├── object.lua            -- 对象标识与句柄生成
│   │   ├── event.lua             -- 事件总线与多播委托
│   │   ├── scheduler.lua         -- Tick 与延迟任务调度
│   │   ├── timer.lua             -- 时间源与 TimeDilation
│   │   └── registry.lua          -- 类型/实例注册表
│   ├── semantics/
│   │   ├── asc.lua               -- AbilitySystemComponent
│   │   ├── ability.lua           -- GameplayAbility
│   │   ├── attribute.lua         -- Attribute / AttributeSet
│   │   ├── effect.lua            -- GameplayEffect
│   │   ├── tag.lua               -- GameplayTag / GameplayTagContainer
│   │   ├── cue.lua               -- GameplayCue
│   │   └── task.lua              -- AbilityTask
│   ├── adapters/
│   │   ├── manual.lua            -- 手动 update(dt) 驱动
│   │   └── love2d.lua            -- Love2D 适配示例
│   └── net/
│       ├── context.lua           -- 网络上下文（Authority/Simulated/Autonomous）
│       ├── prediction.lua        -- PredictionKey 占位
│       └── event.lua             -- 可序列化 GameplayEvent 占位
└── cgas_spec/                    -- 类型定义与内部工具（可选）
    └── types.lua
```

---

## 4. 核心层（`cgas.core`）

### 4.1 object.lua — 对象标识

每个运行时实例（ASC、Ability、Effect、Task）拥有一个全局唯一句柄。

```lua
---@class cgas.core.Object
---@field handle integer 全局唯一句柄

---@class cgas.core.ObjectManager
local ObjectManager = {}

---生成新的唯一句柄
---@return integer handle
function ObjectManager.next_handle() end

---注册实例
---@param handle integer
---@param instance table
function ObjectManager.register(handle, instance) end

---注销实例
---@param handle integer
function ObjectManager.unregister(handle) end

---根据句柄获取实例
---@param handle integer
---@return table|nil instance
function ObjectManager.get(handle) end
```

- 句柄使用单调递增整数，从 1 开始。
- 注册表以 `handle -> weak table` 方式存储，避免内存泄漏。

### 4.2 event.lua — 事件总线

```lua
---@class cgas.core.EventBus
local EventBus = {}

---订阅事件
---@param event_name string
---@param listener fun(payload: table)
---@return integer subscription_id
function EventBus:subscribe(event_name, listener) end

---取消订阅
---@param subscription_id integer
function EventBus:unsubscribe(subscription_id) end

---派发事件（进入队列，下一帧处理）
---@param event_name string
---@param payload table
function EventBus:emit(event_name, payload) end

---处理当前队列中的所有事件
function EventBus:dispatch() end
```

- 事件派发是**入队而非立即执行**，在 Scheduler 的 Tick 末尾统一处理。
- 事件处理器抛错不会中断其他处理器，错误会被记录。
- 允许在事件处理中再次 `emit`，新事件进入下一帧队列。

### 4.3 scheduler.lua — 调度器

```lua
---@class cgas.core.Scheduler
local Scheduler = {}

---注册每帧更新对象
---@param handle integer
---@param callback fun(dt: number)
function Scheduler:register(handle, callback) end

---取消注册
---@param handle integer
function Scheduler:unregister(handle) end

---延迟调用
---@param fn fun()
---@param delay number 单位：秒
---@return integer job_id
function Scheduler:defer(fn, delay) end

---周期性调用
---@param fn fun()
---@param interval number 单位：秒
---@param immediate boolean? 是否立即执行一次
---@return integer job_id
function Scheduler:every(fn, interval, immediate) end

---取消任务
---@param job_id integer
function Scheduler:cancel(job_id) end

---驱动一帧
---@param dt number
function Scheduler:update(dt) end
```

- Scheduler 内部按优先级升序调用已注册对象。
- Effect 更新优先级高于 Ability，确保 Ability 读取到最新属性。

### 4.4 timer.lua — 时间源

```lua
---@class cgas.core.TimeSource
local TimeSource = {}

---推进时间
---@param dt number
function TimeSource:advance(dt) end

---获取当前时间
---@return number time
function TimeSource:now() end

---设置全局时间膨胀
---@param dilation number
function TimeSource:set_global_dilation(dilation) end

---设置局部时间膨胀（作用于特定 ASC）
---@param asc_handle integer
---@param dilation number
function TimeSource:set_local_dilation(asc_handle, dilation) end

---获取某 ASC 的实际 dt
---@param asc_handle integer
---@param raw_dt number
---@return number scaled_dt
function TimeSource:scale_dt(asc_handle, raw_dt) end
```

- GE 的 Duration、Cooldown、Period 均基于 TimeSource 计算。
- 局部 TimeDilation 用于角色被减速等效果。

### 4.5 registry.lua — 注册表

```lua
---@class cgas.core.Registry
local Registry = {}

---注册 Ability 类
---@param class_name string
---@param class table
function Registry:register_ability(class_name, class) end

---注册 Effect 类
---@param class_name string
---@param class table
function Registry:register_effect(class_name, class) end

---注册 AttributeSet 类
---@param class_name string
---@param class table
function Registry:register_attribute_set(class_name, class) end

---按名称获取类
---@param kind "ability"|"effect"|"attribute_set"
---@param class_name string
---@return table|nil class
function Registry:get(kind, class_name) end
```

- 类注册使用类名 -> 类表的映射，便于运行时通过字符串实例化。
- 注册表本身无状态，可注入到 ASC 中。

---

## 5. AbilitySystemComponent（ASC）

ASC 是 GAS 的入口，每个游戏实体（角色、道具、环境对象）可拥有一个 ASC 实例。

### 5.1 数据结构

```lua
---@class cgas.semantics.ASC
---@field handle integer
---@field scheduler cgas.core.Scheduler
---@field event_bus cgas.core.EventBus
---@field time_source cgas.core.TimeSource
---@field registry cgas.core.Registry
---@field attribute_sets table<string, cgas.semantics.AttributeSet>
---@field granted_abilities table<integer, cgas.semantics.GameplayAbility>
---@field active_effects table<integer, cgas.semantics.ActiveGameplayEffect>
---@field owned_tags cgas.semantics.GameplayTagContainer
---@field blocked_tags cgas.semantics.GameplayTagContainer
---@field cue_manager cgas.semantics.GameplayCueManager
local ASC = {}
```

### 5.2 构造与初始化

```lua
---@param opts table
---@return cgas.semantics.ASC|nil asc
---@return string|nil error
function ASC.new(opts) end
```

`opts` 可包含：
- `scheduler`：外部 Scheduler，可选，默认新建。
- `event_bus`：外部 EventBus，可选，默认新建。
- `time_source`：外部 TimeSource，可选，默认新建。
- `registry`：外部 Registry，可选，默认新建。

初始化流程：
1. 创建 ASC 实例并分配句柄。
2. 注入 Scheduler、EventBus、TimeSource、Registry。
3. 注册到 Scheduler，准备接收 Tick。

### 5.3 Ability 管理

```lua
---@param ability_class table
---@param source_level integer? 默认 1
---@return integer|nil ability_handle
---@return string|nil error
function ASC:give_ability(ability_class, source_level) end

---@param ability_handle integer
---@return boolean ok
function ASC:remove_ability(ability_handle) end

---@param tag cgas.semantics.GameplayTag
---@return integer|nil ability_handle
function ASC:find_ability_by_tag(tag) end

---@param input_id integer|string
---@return boolean ok
function ASC:try_activate_ability_by_input(input_id) end

---@param ability_handle integer
---@return boolean ok
---@return string|nil error
function ASC:try_activate_ability(ability_handle) end
```

### 5.4 AttributeSet 管理

```lua
---@param attr_set_class table
---@return cgas.semantics.AttributeSet|nil attr_set
---@return string|nil error
function ASC:add_attribute_set(attr_set_class) end

---@param set_name string
---@return cgas.semantics.AttributeSet|nil attr_set
function ASC:get_attribute_set(set_name) end

---@param attr_path string 格式 "SetName.AttributeName"
---@return cgas.semantics.Attribute|nil attr
function ASC:get_attribute(attr_path) end
```

### 5.5 Effect 应用

```lua
---@param effect_spec cgas.semantics.GameplayEffectSpec
---@return integer|nil active_effect_handle
---@return string|nil error
function ASC:apply_effect(effect_spec) end

---@param active_effect_handle integer
---@return boolean ok
function ASC:remove_active_effect(active_effect_handle) end
```

### 5.6 Tag 管理

```lua
---@param tag cgas.semantics.GameplayTag
function ASC:add_tag(tag) end

---@param tag cgas.semantics.GameplayTag
function ASC:remove_tag(tag) end

---@param query cgas.semantics.GameplayTagQuery
---@return boolean matches
function ASC:matches_tag_query(query) end
```

### 5.7 Tick 驱动

```lua
---@param raw_dt number
function ASC:update(raw_dt) end
```

每帧执行：
1. 通过 TimeSource 缩放 `raw_dt` 得到 `dt`。
2. 更新所有 `ActiveGameplayEffect`（Duration、Period、Stack）。
3. 更新所有 `ActiveGameplayAbility` 与 `AbilityTask`。
4. 派发事件队列。

### 5.8 销毁

```lua
function ASC:destroy() end
```

- 移除所有 ActiveEffect、GrantedAbility、AttributeSet。
- 派发 `on_asc_destroyed` 事件。
- 从 Scheduler 注销。

---

## 6. GameplayAbility（GA）

### 6.1 数据结构

```lua
---@class cgas.semantics.GameplayAbility
---@field handle integer
---@field asc cgas.semantics.ASC
---@field class table
---@field state "inactive"|"committing"|"active"|"ending"
---@field instance_policy "non_instanced"|"instanced_per_actor"|"instanced_per_execution"
---@field level integer
---@field input_id integer|string|nil
---@field ability_tags cgas.semantics.GameplayTagContainer
---@field activation_owned_tags cgas.semantics.GameplayTagContainer
---@field activation_blocked_tags cgas.semantics.GameplayTagContainer
---@field activation_required_tags cgas.semantics.GameplayTagContainer
---@field cancel_abilities_with_tag cgas.semantics.GameplayTagContainer
---@field block_abilities_with_tag cgas.semantics.GameplayTagContainer
---@field cost_effect_class table|nil
---@field cooldown_effect_class table|nil
---@field active_tasks table<integer, cgas.semantics.AbilityTask>
local GameplayAbility = {}
```

### 6.2 生命周期状态

```
        ┌─────────────────────────────────────┐
        │           inactive                  │
        │  （已授予，但未激活）                  │
        └───────────────┬─────────────────────┘
                        │ try_activate
                        ▼
        ┌─────────────────────────────────────┐
        │           committing                │
        │  （CanActivate 通过，准备 Commit）    │
        └───────────────┬─────────────────────┘
                        │ commit_ability
                        ▼
        ┌─────────────────────────────────────┐
        │            active                   │
        │  （ActivateAbility 执行中）           │
        └───────────────┬─────────────────────┘
                        │ end_ability
                        ▼
        ┌─────────────────────────────────────┐
        │           ending                    │
        │  （清理 Task，派发结束事件）           │
        └───────────────┬─────────────────────┘
                        │
                        ▼
                   inactive / destroyed
```

### 6.3 核心方法

```lua
---@return boolean can_activate
---@return string|nil error
function GameplayAbility:can_activate() end

---@return boolean ok
function GameplayAbility:activate() end

---@return boolean ok
function GameplayAbility:commit() end

---@return boolean ok
function GameplayAbility:end_ability() end

---@return boolean ok
function GameplayAbility:cancel() end
```

- `can_activate`：检查 `activation_required_tags`、`activation_blocked_tags`、Cost、Cooldown。
- `activate`：调用 `ActivateAbility` 虚方法，Ability 子类在此实现具体逻辑。
- `commit`：应用 Cost GE 与 Cooldown GE，进入 `active` 状态。
- `end_ability`：停止所有 Task，移除 `activation_owned_tags`，回到 `inactive`。

### 6.4 实例化策略

| 策略 | 说明 | 适用场景 |
|------|------|----------|
| `non_instanced` | 全局单例，无运行时状态 | 简单被动、无状态技能 |
| `instanced_per_actor` | 每个 ASC 一个实例 | 需要跨激活保持状态 |
| `instanced_per_execution` | 每次激活新建实例（默认） | 大多数主动技能 |

### 6.5 标签约束

- `ability_tags`：该能力的身份标签，用于查找与匹配。
- `activation_owned_tags`：激活期间赋予 ASC 的标签。
- `activation_blocked_tags`：ASC 拥有这些标签时无法激活。
- `activation_required_tags`：ASC 必须拥有这些标签才能激活。
- `cancel_abilities_with_tag`：本能力激活时，取消其他拥有指定标签的能力。
- `block_abilities_with_tag`：本能力激活期间，阻止其他拥有指定标签的能力激活。

### 6.6 Cost 与 Cooldown

- **Cost**：通过 `cost_effect_class` 指定一个 Instant GE，通常消耗 Mana/Stamina 等属性。
- **Cooldown**：通过 `cooldown_effect_class` 指定一个 Duration GE，持续期间通过标签或句柄阻止再次激活。
- 两者均在 `commit` 阶段应用。

---

## 7. AttributeSet / Attribute

### 7.1 Attribute 数据结构

```lua
---@class cgas.semantics.Attribute
---@field name string
---@field base_value number
---@field current_value number
---@field min_value number?
---@field max_value number?
---@field is_meta boolean 是否为 Meta Attribute
local Attribute = {}
```

- `BaseValue`：GE 直接修改的值。
- `CurrentValue`：由 `BaseValue` 经所有 Aggregate Modifier 计算得出。
- `MinValue` / `MaxValue`：可选的 Clamp 范围。

### 7.2 AttributeSet 数据结构

```lua
---@class cgas.semantics.AttributeSet
---@field name string
---@field attributes table<string, cgas.semantics.Attribute>
local AttributeSet = {}

---@param attr_name string
---@param default_value number
---@param opts table?
function AttributeSet:register_attribute(attr_name, default_value, opts) end
```

- 一个 ASC 可挂载多个 AttributeSet，例如 `HealthSet`、`CombatSet`、`MovementSet`。
- Attribute 路径格式：`"SetName.AttributeName"`，如 `"HealthSet.Health"`。

### 7.3 Modifier

```lua
---@alias cgas.semantics.ModifierOp
---| "add"
---| "multiply"
---| "divide"
---| "override"

---@class cgas.semantics.Modifier
---@field attribute_name string
---@field op cgas.semantics.ModifierOp
---@field magnitude number
---@field source_handle integer?
local Modifier = {}
```

- `add`：加法（对应 UE 的 `Flat`）。
- `multiply`：乘法（对应 UE 的 `Scale`，通常用于百分比）。
- `divide`：除法。
- `override`：覆盖最终值（对应 UE 的 `Final`）。

### 7.4 计算顺序

`CurrentValue` 计算遵循以下顺序：

1. 从 `BaseValue` 开始。
2. 应用所有 `add` Modifier。
3. 应用所有 `multiply` Modifier。
4. 应用所有 `divide` Modifier。
5. 应用所有 `override` Modifier（仅最后一个生效，或按 Source 优先级选择）。
6. 应用 `MinValue` / `MaxValue` Clamp。

```lua
---重新计算 CurrentValue
function Attribute:recalculate(modifiers) end
```

### 7.5 Meta Attribute

- Meta Attribute 用于中间结算（如 `Damage` 临时属性），不暴露给游戏表现层。
- 通常不注册到显示用的 AttributeSet，而是由 GE 动态创建或复用。

### 7.6 事件

- `on_attribute_base_changed`：`BaseValue` 发生变化。
- `on_attribute_current_changed`：`CurrentValue` 发生变化。
- 事件 payload 包含属性路径、旧值、新值、来源 Effect/Ability 句柄。

---

## 8. GameplayEffect（GE）

### 8.1 GE 定义数据结构

```lua
---@class cgas.semantics.GameplayEffect
---@field name string
---@field duration_policy "instant"|"duration"|"infinite"
---@field duration cgas.semantics.Magnitude? 仅 duration 类型使用
---@field period number? 周期触发间隔
---@field periodic_instant boolean? 周期是否以 Instant 方式执行
---@field modifiers cgas.semantics.Modifier[]
---@field granted_tags cgas.semantics.GameplayTagContainer
---@field removed_tags cgas.semantics.GameplayTagContainer
---@field application_required_tags cgas.semantics.GameplayTagQuery
---@field application_immunity_tags cgas.semantics.GameplayTagQuery
---@field stacking_policy "none"|"aggregate_by_source"|"aggregate_by_target"
---@field stack_limit integer?
---@field stack_refresh "duration"|"magnitude"|"both"
local GameplayEffect = {}
```

### 8.2 ActiveGameplayEffect 数据结构

```lua
---@class cgas.semantics.ActiveGameplayEffect
---@field handle integer
---@field effect cgas.semantics.GameplayEffect
---@field target cgas.semantics.ASC
---@field source cgas.semantics.ASC?
---@field level integer
---@field start_time number
---@field duration number?
---@field period_timer number
---@field stack_count integer
---@field is_active boolean
local ActiveGameplayEffect = {}
```

### 8.3 Duration 类型

| 类型 | 行为 | 回滚 |
|------|------|------|
| `instant` | 立即执行 Modifier 一次，不进入 ActiveEffect 列表 | 不回滚 |
| `duration` | 持续指定时间，期间 Modifier 生效 | 过期后移除 Modifier 与 Tags |
| `infinite` | 永久持续，直到显式移除 | 移除后回滚 |
| `periodic` | 可与 duration/infinite 组合，按周期执行 | 同父类型 |

### 8.4 Magnitude 来源

```lua
---@alias cgas.semantics.Magnitude
---| { type: "scalable_float", value: number, curve: table? }
---| { type: "attribute_based", attribute: string, coefficient: number, pre_multiply: boolean }
---| { type: "custom", func: fun(ctx: table): number }
```

- `scalable_float`：固定值或按等级曲线缩放。
- `attribute_based`：基于源或目标其他属性计算。
- `custom`：用户自定义函数。

### 8.5 应用流程

```lua
---@class cgas.semantics.GameplayEffectSpec
---@field effect_class table
---@field level integer?
---@field source cgas.semantics.ASC?
---@field context table? 用户上下文

---@param spec cgas.semantics.GameplayEffectSpec
---@return integer|nil active_handle
---@return string|nil error
function ASC:apply_effect(spec) end
```

应用流程：
1. 实例化 `GameplayEffect`。
2. 检查目标 `application_required_tags` 与 `application_immunity_tags`。
3. 如果是 `instant`，立即执行 Modifier 并退出。
4. 创建 `ActiveGameplayEffect`，处理 Stack 规则。
5. 将 ActiveEffect 加入 ASC 列表，触发 `on_effect_applied`。
6. 应用 `granted_tags` / `removed_tags`。

### 8.6 Stack 规则

- `none`：每次应用都创建新的 ActiveEffect。
- `aggregate_by_source`：同一来源的同名 GE 叠加 Stack。
- `aggregate_by_target`：同名 GE 全局叠加 Stack（无论来源）。
- `stack_refresh`：刷新时选择刷新 Duration、Magnitude 或两者。
- `stack_limit`：Stack 数量上限。

### 8.7 每帧更新

- 更新 `duration`，过期时进入移除流程。
- 更新 `period_timer`，触发周期执行。
- 周期执行时，如果是 `periodic_instant`，立即执行一次 Modifier。
- 移除时回滚所有 Modifier 与 Tags，派发 `on_effect_removed`。

---

## 9. GameplayTag

### 9.1 Tag 注册表

```lua
---@class cgas.semantics.GameplayTagRegistry
local GameplayTagRegistry = {}

---注册标签路径
---@param tag_string string
function GameplayTagRegistry:register(tag_string) end

---检查标签是否已注册
---@param tag_string string
---@return boolean
function GameplayTagRegistry:is_valid(tag_string) end

---获取标签的父标签列表
---@param tag_string string
---@return string[]
function GameplayTagRegistry:get_parents(tag_string) end
```

- 标签以点分隔，如 `state.debuff.stun`。
- 父标签自动继承：`state.debuff.stun` 也匹配 `state.debuff` 和 `state`。
- 开发模式下允许运行时注册；发布模式建议预注册并关闭动态注册。

### 9.2 GameplayTagContainer

```lua
---@class cgas.semantics.GameplayTagContainer
---@field tags table<string, boolean>
local GameplayTagContainer = {}

---@param tag cgas.semantics.GameplayTag
function GameplayTagContainer:add(tag) end

---@param tag cgas.semantics.GameplayTag
function GameplayTagContainer:remove(tag) end

---@param tag cgas.semantics.GameplayTag
---@return boolean
function GameplayTagContainer:has_exact(tag) end

---@param tag cgas.semantics.GameplayTag
---@return boolean 包含自身或父标签
function GameplayTagContainer:has(tag) end

---@param other cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagContainer:matches_any(other) end

---@param other cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagContainer:matches_all(other) end
```

### 9.3 GameplayTagQuery

```lua
---@class cgas.semantics.GameplayTagQuery
---@field all_tags cgas.semantics.GameplayTagContainer
---@field any_tags cgas.semantics.GameplayTagContainer
---@field none_tags cgas.semantics.GameplayTagContainer
local GameplayTagQuery = {}

---@param container cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagQuery:matches(container) end
```

- `all_tags`：必须全部拥有。
- `any_tags`：至少拥有一个。
- `none_tags`：必须一个都没有。

### 9.4 标签变更事件

- ASC 在 `add_tag` / `remove_tag` 时通过 EventBus 派发 `on_tag_changed`。
- payload 包含变更的标签、新增/移除标志、来源句柄。
- Ability 与 GE 监听标签变化以触发取消、阻止或刷新。

---

## 10. GameplayCue

### 10.1 设计定位

GameplayCue 只负责表现/反馈，不修改游戏逻辑。典型用途：播放粒子、音效、震屏、UI 提示。

### 10.2 Cue 管理器

```lua
---@class cgas.semantics.GameplayCueManager
---@field handlers table<string, fun(payload: cgas.semantics.GameplayCuePayload)[]>
local GameplayCueManager = {}

---注册 Cue 处理器
---@param cue_tag cgas.semantics.GameplayTag
---@param handler fun(payload: cgas.semantics.GameplayCuePayload)
function GameplayCueManager:register(cue_tag, handler) end

---触发 Cue
---@param cue_tag cgas.semantics.GameplayTag
---@param payload cgas.semantics.GameplayCuePayload
function GameplayCueManager:trigger(cue_tag, payload) end
```

### 10.3 Cue Payload

```lua
---@class cgas.semantics.GameplayCuePayload
---@field target cgas.semantics.ASC
---@field source cgas.semantics.ASC?
---@field location table? { x, y, z }
---@field normal table?
---@field magnitude number?
---@field context table?
```

### 10.4 触发时机

- GE 应用时触发 `on_apply` Cue。
- GE 移除时触发 `on_remove` Cue。
- GE 周期执行时触发 `on_periodic` Cue。
- Ability 激活/结束时触发对应 Cue。
- Tag 变化时触发 `on_tag_added` / `on_tag_removed` Cue。

### 10.5 本地模式行为

- 所有 Cue 本地立即触发，无需区分 Server/Client。
- 网络模式下，Cue 触发才需根据 `net.Context` 决定是否在 Authority / SimulatedProxy / AutonomousProxy 上执行。

---

## 11. AbilityTask

### 11.1 设计定位

AbilityTask 用于处理需要等待或跨帧的技能逻辑。Lua 无原生 async/await，因此采用回调 + Scheduler 模型。

### 11.2 Task 基类

```lua
---@class cgas.semantics.AbilityTask
---@field handle integer
---@field ability cgas.semantics.GameplayAbility
---@field state "pending"|"running"|"finished"
---@field on_finished fun(result: table)?
local AbilityTask = {}

---启动任务
function AbilityTask:start() end

---结束任务
function AbilityTask:finish(result) end

---每帧更新
---@param dt number
function AbilityTask:update(dt) end
```

### 11.3 常用任务

```lua
---@class cgas.semantics.TaskWaitDelay : cgas.semantics.AbilityTask
---@field delay number

---@class cgas.semantics.TaskWaitInputRelease : cgas.semantics.AbilityTask

---@class cgas.semantics.TaskWaitGameplayEvent : cgas.semantics.AbilityTask
---@field event_name string

---@class cgas.semantics.TaskWaitAbilityCommit : cgas.semantics.AbilityTask
```

### 11.4 生命周期绑定

- Task 由 Ability 在 `ActivateAbility` 中创建。
- Ability 结束时，所有 `active_tasks` 自动调用 `finish(nil)`。
- Task 完成时通过回调通知 Ability，Ability 可据此决定 `end_ability` 或启动新 Task。

### 11.5 实现示例

```lua
function MyAbility:activate()
    local task = TaskWaitDelay.new(self, 1.5)
    task.on_finished = function()
        self:apply_damage()
        self:end_ability()
    end
    task:start()
end
```

---

## 12. 生命周期与 Tick

### 12.1 ASC 初始化流程

```
创建 ASC
  ├── 注入 Scheduler / EventBus / TimeSource / Registry
  ├── 注册到 Scheduler
  ├── 添加 AttributeSet
  ├── Give Abilities
  └── 应用 Passive GE
```

### 12.2 每帧更新顺序

```
ASC:update(raw_dt)
  ├── TimeSource:scale_dt(asc_handle, raw_dt) -> dt
  ├── 更新 ActiveGameplayEffects
  │     ├── Duration / Period / Stack
  │     └── 移除过期 Effect
  ├── 更新 ActiveGameplayAbilities
  │     └── 更新 AbilityTask
  ├── 处理 EventBus 队列
  └── 派发 on_post_update
```

### 12.3 清理流程

```
ASC:destroy()
  ├── 停止所有 ActiveAbility
  ├── 移除所有 ActiveEffect
  ├── 移除所有 AttributeSet
  ├── 清空 OwnedTags
  ├── 派发 on_asc_destroyed
  └── 从 Scheduler 注销
```

### 12.4 更新优先级

- Effect 更新优先于 Ability，确保 Ability 读到最新属性。
- 事件派发最后执行，避免同一帧内事件立即触发递归。

---

## 13. Replication / Prediction（单机模式下的定位）

### 13.1 设计原则

本次设计为单机/本地模式，因此网络层不做完整实现，仅提供**概念层占位**，确保：

- 核心语义层代码不依赖网络存在。
- 未来扩展网络时，只需实现网络层与适配点，无需重构 ASC/Ability/Effect。

### 13.2 网络上下文

```lua
---@class cgas.net.Context
---@field role "authority"|"simulated_proxy"|"autonomous_proxy"
local Context = {}
```

- 单机模式下，所有 ASC 默认为 `authority`。

### 13.3 PredictionKey

```lua
---@class cgas.net.PredictionKey
---@field id integer
local PredictionKey = {}
```

- 用于客户端预测占位，单机模式下恒为 `nil`。

### 13.4 可序列化 GameplayEvent

```lua
---@class cgas.net.GameplayEvent
---@field event_name string
---@field payload table
---@field prediction_key cgas.net.PredictionKey?
local GameplayEvent = {}
```

- 定义事件包结构，未来可用于 RPC 或回放系统。

### 13.5 单机模式退化

- `apply_effect`、`activate_ability` 等接口在单机模式下直接本地执行。
- Cue 直接本地触发。
- PredictionKey 不参与任何逻辑。

---

## 14. 错误处理

### 14.1 总体策略

- **防御式接口**：公共 API 对非法参数返回 `nil, error_message`，不抛异常。
- **状态机守卫**：Ability 状态转换非法时返回失败原因。
- **事件错误隔离**：单个事件处理器抛错不影响其他处理器。
- **日志记录**：核心错误通过可注入的日志回调输出，默认使用 `print`。

### 14.2 常见错误场景

| 场景 | 返回/行为 |
|------|-----------|
| 无效句柄 | `nil, "invalid handle"` |
| Ability 激活条件不满足 | `false, "activation blocked by tag: ..."` |
| Cost 不足 | `false, "cost check failed"` |
| GE 应用免疫 | `nil, "target is immune"` |
| Attribute 路径不存在 | `nil, "attribute not found: ..."` |
| 事件处理器抛错 | 记录错误，继续下一个处理器 |

### 14.3 断言与不变量

- Attribute 的 `CurrentValue` 必须在每次 Modifier 变化后重新计算。
- ActiveEffect 的 `duration` 必须大于等于 0。
- Ability 在 `active` 状态下才能启动 Task。

---

## 15. 测试策略

### 15.1 单元测试

每个核心模块与语义模块配套 `*_spec.lua`，覆盖：

- **Attribute**：
  - Base/Current 值更新。
  - Modifier 计算顺序（Add → Multiply → Divide → Override）。
  - Clamp 行为。
- **GameplayEffect**：
  - Instant / Duration / Infinite / Periodic 行为。
  - Stack 叠加与刷新。
  - Tag 赋予/移除。
- **GameplayTag**：
  - 层级匹配。
  - Query 的 All/Any/None 组合。
- **GameplayAbility**：
  - 激活、提交、结束流程。
  - Cost/Cooldown 检查。
  - 标签约束（Required / Blocked / Owned）。
- **ASC**：
  - Ability 授予与移除。
  - Effect 应用与移除。
  - AttributeSet 挂载。

### 15.2 集成测试

构造完整 gameplay 场景：

```
1. 玩家 ASC 拥有 Fireball Ability。
2. 激活 Fireball：检查 Mana Cost（通过）、Cooldown（通过）。
3. 进入 Commit，消耗 Mana，应用 Cooldown GE。
4. 等待 1.5 秒（AbilityTask WaitDelay）。
5. 对目标 ASC 应用 Damage GE（Instant）。
6. 目标 Health 减少。
7. Cooldown 期间再次激活被拒绝。
8. Cooldown 结束后可再次激活。
```

### 15.3 Mock 工具

测试支持目录 `lua_tests/support/` 提供：

- `MockScheduler`：手动推进 `update(dt)`。
- `MockAbility`：可注入 `CanActivateAbility` / `ActivateAbility` 行为。
- `MockAttributeSet`：快速创建含预定义属性的 AttributeSet。
- `MockCueHandler`：记录 Cue 触发次数与参数。

### 15.4 测试驱动要求

- 所有公共接口必须有对应测试。
- 核心算法（Modifier 聚合、GE 执行流程）必须有边界条件测试。
- 状态机转换必须覆盖所有非法路径。

---

## 16. 术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| 能力系统组件 | AbilitySystemComponent（ASC） | 实体的 GAS 入口 |
| 游戏能力 | GameplayAbility（GA） | 可激活的技能 |
| 属性集 | AttributeSet | 属性的集合 |
| 属性 | Attribute | 含 Base/Current 值的游戏数值 |
| 游戏效果 | GameplayEffect（GE） | 对属性/标签/能力的时序性影响 |
| 修改器 | Modifier | GE 中对属性的数值修改 |
| 游戏标签 | GameplayTag | 层级化的字符串标签 |
| 游戏提示 | GameplayCue | 表现层触发事件 |
| 能力任务 | AbilityTask | 异步/延迟技能任务 |
| 花费 | Cost | 激活能力消耗的资源 |
| 冷却 | Cooldown | 能力再次激活的等待时间 |
| 预测 | Prediction | 客户端预测机制（本次占位） |
| 同步 | Replication | 服务器-客户端同步（本次占位） |

---

## 17. 参考资料

- Unreal Engine Documentation: Gameplay Ability System
- `docs/books/LuaCATS-annotations.md`
- `AGENTS.md`
- `CLAUDE.md`

---

## 18. 附录：待实现清单（实现阶段使用）

- [ ] `cgas.core.object`
- [ ] `cgas.core.event`
- [ ] `cgas.core.scheduler`
- [ ] `cgas.core.timer`
- [ ] `cgas.core.registry`
- [ ] `cgas.semantics.asc`
- [ ] `cgas.semantics.ability`
- [ ] `cgas.semantics.attribute`
- [ ] `cgas.semantics.effect`
- [ ] `cgas.semantics.tag`
- [ ] `cgas.semantics.cue`
- [ ] `cgas.semantics.task`
- [ ] `cgas.adapters.manual`
- [ ] `cgas.net.context`（占位）
- [ ] 单元测试套件
- [ ] 集成测试：Fireball 连招
