
## 9. 目录结构

```
lua_lib/
└── mini_gas/                      -- 独立目录
    ├── init.lua                   -- 模块入口，导出公共 API
    ├── types.lua                  -- LuaCATS 类型定义集中文件
    ├── enum.lua                   -- 枚举常量定义
    ├── asc.lua                    -- 核心求值入口与主控流程（轻量）
    ├── tag.lua                    -- 层级标签匹配工具
    ├── ability.lua                -- Ability 激活条件与 active_abilities 收集
    ├── effect.lua                 -- Effect 目标匹配与应用
    ├── modifier.lua               -- Modifier 解析与属性聚合
    ├── pool.lua                   -- 分类对象池
    └── debug.lua                  -- 调试钩子辅助函数
```

> MiniGas V2 为自包含实现，所有代码均在 `lua_lib/mini_gas/` 内，不依赖任何外部 GAS 库。

---

## 10. API 汇总

### 10.1 模块入口

```lua
local mini_gas = require("mini_gas")
```

### 10.2 枚举

| 字段 | 说明 |
|------|------|
| `mini_gas.EModifierOp` | Add / Multiply / Override |
| `mini_gas.EAbilityActivationPolicy` | Passive |
| `mini_gas.EEffectTarget` | Self / Other / All |

### 10.3 标签匹配

```lua
---层级标签匹配
---@param a mini_gas.Tag
---@param b mini_gas.Tag
---@return boolean
function mini_gas.match_tag(a, b) end

---判断实体是否拥有与给定标签模式匹配的标签
---@param entity mini_gas.IEntityState
---@param module mini_gas.IEntityModule
---@param pattern mini_gas.Tag
---@return boolean
function mini_gas.entity_match_tag(entity, module, pattern) end

---判断实体是否满足 allof / anyof / noneof 标签约束
---@param entity mini_gas.IEntityState
---@param module mini_gas.IEntityModule
---@param allof_tags? mini_gas.Tag[]
---@param anyof_tags? mini_gas.Tag[]
---@param noneof_tags? mini_gas.Tag[]
---@return boolean
function mini_gas.match_tags(entity, module, allof_tags, anyof_tags, noneof_tags) end
```

### 10.4 快照求值

```lua
---世界快照求值入口
--- IDebug 通过 context.debug 传入
---@param context mini_gas.IContext
---@param apply mini_gas.ApplyFun
---@param ... unknown
function mini_gas.evaluate(context, apply, ...) end
```

`ApplyFun` 在每个 `target` 实体全部求值完成后调用一次，传递该实体获得的所有授予标签集合（`table<mini_gas.Tag, boolean>`）与属性变化映射。`tags` 与 `attributes` 归库所有，`apply` 返回后会被回收。可选的 `IDebug` 通过 `context.debug` 传入，用于日志或副作用。

### 10.5 内部模块

以下模块为内部实现，不对外暴露，但可通过 `require("mini_gas.xxx")` 在测试或扩展中单独使用：

| 模块 | 说明 |
|------|------|
| `mini_gas.tag` | 层级标签匹配 |
| `mini_gas.ability` | Ability 激活条件与收集 |
| `mini_gas.effect` | Effect 目标匹配与应用 |
| `mini_gas.modifier` | Modifier 解析与聚合 |
| `mini_gas.pool` | 两类对象池：`table_pool`（键值表）与 `array_pool`（纯数组表） |
| `mini_gas.debug` | 调试钩子辅助函数 |

---

> [返回 Mini-GAS 设计文档总览](./README.md)
