
## 9. 目录结构

```
lua_lib/
└── mini_gas/                      -- 独立目录
    ├── init.lua                   -- 模块入口，导出所有公共 API
    ├── types.lua                  -- LuaCATS 类型定义集中文件（不含枚举）
    ├── state.lua                  -- EntityState / WorldState / register_entity
    ├── asc.lua                    -- MiniASC 无状态函数集合
    ├── ability.lua                -- GameplayAbility 运行时实例
    ├── effect.lua                 -- GameplayEffect 运行时实例
    ├── modifier.lua               -- Modifier 聚合逻辑
    ├── attribute.lua              -- Attribute 数值工具函数（clamp / calc_base）
    ├── tag.lua                    -- GameplayTagContainer 与标签匹配
    ├── event.lua                  -- GameplayEvent 派发与监听
    ├── task.lua                   -- GameplayTask 轻量异步任务
    ├── spec.lua                   -- Spec 构造器与 GrowthCurve
    └── enum.lua                   -- 所有枚举常量定义（@enum）
```

> `mini-gas` 为自包含实现，所有代码均在 `lua_lib/mini_gas/` 内，不依赖任何外部 GAS 库。

---

## 10. API 汇总

### 10.1 模块入口

```lua
local mini_gas = require("mini_gas")
```

### 10.2 EntityState

| 方法 | 说明 |
|------|------|
| `EntityState.new()` | 创建新的空实体状态（可序列化的 Lua 表） |

### 10.3 WorldState

| 方法 | 说明 |
|------|------|
| `WorldState.new()` | 创建新的世界状态（`table<EntityId, EntityState>`） |
| `mini_gas.register_entity(world, id, state)` | 注册实体状态到 WorldState（工具函数） |

### 10.4 MiniASC

所有 `MiniASC` 方法均为无状态函数，第一个参数为 `state` 或 `world`。

| 方法 | 说明 |
|------|------|
| `MiniASC.register_attributes(state, defs)` | 批量注册属性定义 |
| `MiniASC.give_ability(state, spec, level, stack?)` | 授予技能 |
| `MiniASC.remove_ability(state, ability_id)` | 移除技能 |
| `MiniASC.set_ability_level(state, ability_id, level)` | 设置技能等级 |
| `MiniASC.set_ability_stack(state, ability_id, stack)` | 设置技能 Stack |
| `MiniASC.try_activate_ability(state, ability_id, payload?)` | 尝试激活技能 |
| `MiniASC.apply_effect(state, spec, level, stack?)` | 应用效果 |
| `MiniASC.remove_effect(state, effect_id)` | 移除效果 |
| `MiniASC.set_effect_level(state, effect_id, level)` | 设置效果等级 |
| `MiniASC.set_effect_stack(state, effect_id, stack)` | 设置效果 Stack |
| `MiniASC.add_tag(state, tag)` | 添加标签 |
| `MiniASC.remove_tag(state, tag)` | 移除标签 |
| `MiniASC.has_tag(state, tag)` | 判断是否包含标签 |
| `MiniASC.dispatch_event(state, event, payload?)` | 派发事件 |
| `MiniASC.listen_event(state, event, listener)` | 监听事件 |
| `MiniASC.update(state, dt)` | 推进时间并触发周期效果、冷却 |
| `MiniASC.update_world(world, dt)` | 批量推进 WorldState 中所有实体的生命周期 |
| `MiniASC.get_base(state, attr)` | 获取属性 Base 值 |
| `MiniASC.get_current(state, attr)` | 获取属性 Current 值 |
| `MiniASC.set_current(state, attr, value)` | 设置属性 Current 值 |

### 10.5 工具函数

```lua
---注入日志句柄（省略或传 nil 时关闭日志）
---@param logger { warn: fun(msg: string) }|nil
function mini_gas.set_logger(logger) end

---将原始配置批量转换为 EffectDef
---@param raw_configs any[]
---@param adapter mini_gas.ConfigAdapter
---@return mini_gas.EffectDef[]
function mini_gas.adapt_effects(raw_configs, adapter) end

---将原始配置批量转换为 AbilityDef
---@param raw_configs any[]
---@param adapter mini_gas.ConfigAdapter
---@return mini_gas.GameplayAbilityDef[]
function mini_gas.adapt_abilities(raw_configs, adapter) end

---计算单个属性的 Current 值（无状态纯函数）
---@param base number
---@param entity_state mini_gas.EntityState
---@param modifiers mini_gas.Modifier[]
---@return number
function mini_gas.calc_attribute(base, entity_state, modifiers) end

---创建成长曲线（返回公式函数本身）
---@param formula mini_gas.GrowthCurve
---@return mini_gas.GrowthCurve
function mini_gas.make_growth_curve(formula) end
```

---

---

> [返回 Mini-GAS 设计文档总览](./README.md)
