# Mini-GAS 设计文档

> 文档版本：v1.0  
> 编写日期：2026-06-14  
> 目标读者：服务端开发者、数值/系统策划  
> 关联项目：[cgas](../../../) — 基于 Lua 的 GAS 库

---

## 1. 背景与目标

### 1.1 背景

完整版 `cgas` 参考 Unreal Engine 的 Gameplay Ability System（GAS），覆盖 Ability、AttributeSet、Effect、Tag、Cue、Task 等完整子系统，适合客户端+服务端联动的复杂战斗系统。

但在很多服务端场景中，我们只需要一个**轻量、可配置、易桥接**的属性计算框架：

- 计算英雄、宠物、装备等战斗对象的最终属性。
- 叠加 VIP、特殊道具、主城建筑等系统带来的属性效果。
- 效果可能是永久生效，也可能是周期性生效（如每 5 秒恢复一次）。
- 配置来源多样：Excel、JSON、数据库、策划脚本等。

因此设计 `mini-gas`：在保留 GAS 核心思想（Effect + Modifier + Attribute）的同时，大幅裁剪非必要概念，专注于服务端属性计算。

### 1.2 目标

- **极简 API**：核心概念少，接口简洁，降低接入成本。
- **配置无关**：不绑定任何配置格式，通过适配器函数桥接任意配置源。
- **永久 + 周期**：支持一次性永久修改和周期性持续修改。
- **可扩展**：保留向完整版 `cgas` 迁移或共存的接口位置。
- **无全局状态**：每个计算上下文独立持有自己的 Effect 与 Attribute 状态。

---

## 2. 范围

### 2.1 包含内容

| 模块 | 说明 |
|------|------|
| Attribute（属性） | 数值定义，支持 Base 值与 Final 值 |
| Modifier（修饰器） | 对属性的修改方式：Add、Multiply、Override |
| Effect（效果） | 对 Attribute 的修改单元，支持永久 / 周期 |
| Context（计算上下文） | 持有 Attribute 与 Effect，执行聚合计算 |
| ConfigAdapter（配置适配器） | 将外部配置转换为 Effect / Attribute 定义的桥梁 |

### 2.2 明确不包含

- GameplayAbility（技能）
- GameplayTag（标签）
- GameplayCue（表现）
- AbilityTask（异步任务）
- 网络同步 / 预测

> 当项目需要这些能力时，应迁移至完整版 `cgas`，或在架构上让 `mini-gas` 作为 `cgas` 的一个轻量子集运行。

---

## 3. 核心概念

### 3.1 Attribute（属性）

一个 Attribute 表示一个可被计算的数值，例如 `max_hp`、`attack_speed`、`vip_exp_bonus`。

```lua
---@class mini_gas.Attribute
---@field name string 属性名
---@field base number 基础值
---@field final number 最终值（计算后）
```

- `base`：未经过任何 Effect 修改的原始值。
- `final`：经过所有生效中 Effect 聚合后的值。

### 3.2 Modifier（修饰器）

Modifier 描述如何修改一个 Attribute。

```lua
---@enum mini_gas.ModifierOp
local ModifierOp = {
    Add = "Add",               -- 加法，聚合为 sum
    Multiply = "Multiply",     -- 乘法，聚合为 product
    Override = "Override",     -- 覆盖，取最高优先级
}
```

聚合顺序：

1. 以 `base` 为起点。
2. 应用所有 `Add` Modifier 的累加和。
3. 应用所有 `Multiply` Modifier 的累乘积。
4. 若存在 `Override` Modifier，按优先级取最终值（默认取最大 override 值）。

### 3.3 Effect（效果）

Effect 是一组 Modifier 的容器，并携带生命周期信息。

```lua
---@class mini_gas.Effect
---@field id string 效果唯一标识
---@field modifiers mini_gas.Modifier[] 修饰器列表
---@field duration number|nil 持续时间（秒），nil 表示永久
---@field period number|nil 周期（秒），nil 表示非周期
---@field remaining number 剩余时间
---@field elapsed number 已进行时间
---@field source any 来源信息（用于调试/追踪）
```

Effect 类型：

| 类型 | duration | period | 说明 |
|------|----------|--------|------|
| Permanent | nil | nil | 永久生效，如装备、宠物、VIP |
| Duration | > 0 | nil | 持续一段时间后消失，如临时 Buff |
| Periodic | > 0 | > 0 | 周期性触发，如每 5 秒回血 |

### 3.4 Context（计算上下文）

Context 是 `mini-gas` 的运行时入口，持有 Attribute 与 Effect，负责计算与更新。

```lua
---@class mini_gas.Context
local Context = {}

---创建一个新的计算上下文
---@return mini_gas.Context
function Context.new() end

---注册属性定义
---@param self mini_gas.Context
---@param defs table<string, number> 属性名 -> 基础值
function Context:register_attributes(defs) end

---应用一个 Effect
---@param self mini_gas.Context
---@param effect mini_gas.Effect
function Context:apply_effect(effect) end

---移除一个 Effect
---@param self mini_gas.Context
---@param effect_id string
function Context:remove_effect(effect_id) end

---更新上下文（由外部调用，传入 dt）
---@param self mini_gas.Context
---@param dt number 秒
function Context:update(dt) end

---获取最终属性值
---@param self mini_gas.Context
---@param name string
---@return number
function Context:get_final(name) end

---获取基础属性值
---@param self mini_gas.Context
---@param name string
---@return number
function Context:get_base(name) end
```

---

## 4. 架构

```
┌─────────────────────────────────────────────┐
│              外部配置源（任意）                │
│      Excel / JSON / DB / 策划脚本 / 硬编码      │
└─────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           ConfigAdapter（配置适配器）          │
│    将外部配置转换为 AttributeDef / EffectDef   │
└─────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│              mini_gas.Context                 │
│   持有 Attributes + Effects，执行聚合计算     │
└─────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│              业务系统使用方                   │
│   战斗、VIP、道具、建筑、经济、任务等         │
└─────────────────────────────────────────────┘
```

---

## 5. 配置桥接设计

### 5.1 设计原则

- `mini-gas` 不读取任何文件，也不解析任何配置格式。
- 所有配置通过**适配器函数**转换为内部定义结构。
- 适配器由业务方提供，可复用、可替换。

### 5.2 内部定义结构

```lua
---@class mini_gas.AttributeDef
---@field name string
---@field base number

---@class mini_gas.ModifierDef
---@field attribute string 目标属性名
---@field op mini_gas.ModifierOp
---@field value number

---@class mini_gas.EffectDef
---@field id string
---@field modifiers mini_gas.ModifierDef[]
---@field duration number|nil
---@field period number|nil
---@field source any
```

### 5.3 适配器接口

```lua
---@alias mini_gas.ConfigAdapter fun(raw_config: any): mini_gas.EffectDef|mini_gas.AttributeDef
```

业务方提供任意函数，输入原始配置，输出 `EffectDef` 或 `AttributeDef`。

### 5.4 示例：从 JSON 配置桥接

假设策划配置如下：

```json
{
  "id": "vip_3_bonus",
  "modifiers": [
    {"attribute": "gold_gain_rate", "op": "Multiply", "value": 1.15},
    {"attribute": "exp_gain_rate", "op": "Multiply", "value": 1.10}
  ]
}
```

适配器实现：

```lua
local function vip_adapter(json_cfg)
    local modifiers = {}
    for _, m in ipairs(json_cfg.modifiers) do
        table.insert(modifiers, {
            attribute = m.attribute,
            op = m.op,
            value = m.value,
        })
    end
    return {
        id = json_cfg.id,
        modifiers = modifiers,
    }
end
```

使用：

```lua
local ctx = mini_gas.Context.new()
ctx:register_attributes({
    gold_gain_rate = 1.0,
    exp_gain_rate = 1.0,
})

local effect_def = vip_adapter(json.decode(vip_config_text))
ctx:apply_effect(effect_def)
```

---

## 6. 使用示例

### 6.1 英雄基础属性 + 装备 + VIP

```lua
local mini_gas = require("cgas.mini_gas")

-- 1. 创建上下文
local hero = mini_gas.Context.new()

-- 2. 注册英雄基础属性
hero:register_attributes({
    max_hp = 1000,
    attack = 100,
    defense = 50,
    gold_gain_rate = 1.0,
})

-- 3. 装备效果（永久）
hero:apply_effect({
    id = "equip_sword_001",
    modifiers = {
        { attribute = "attack", op = "Add", value = 50 },
    },
})

-- 4. VIP 效果（永久）
hero:apply_effect({
    id = "vip_level_3",
    modifiers = {
        { attribute = "gold_gain_rate", op = "Multiply", value = 1.15 },
    },
})

-- 5. 计算结果
print(hero:get_final("attack"))           -- 150
print(hero:get_final("gold_gain_rate"))   -- 1.15
```

### 6.2 周期性效果：主城建筑产出

```lua
-- 主城铁矿厂：每 60 秒产出 100 铁矿
local city = mini_gas.Context.new()
city:register_attributes({
    iron_output = 0,
})

city:apply_effect({
    id = "building_iron_mine_01",
    duration = nil,          -- 永久存在
    period = 60,             -- 每 60 秒触发一次
    modifiers = {
        { attribute = "iron_output", op = "Add", value = 100 },
    },
})

-- 在游戏主循环中调用
city:update(dt)

-- 读取累计产出
local total_iron = city:get_final("iron_output")
```

### 6.3 临时 Buff

```lua
hero:apply_effect({
    id = "buff_attack_up",
    duration = 30,           -- 持续 30 秒
    modifiers = {
        { attribute = "attack", op = "Add", value = 200 },
    },
})
```

---

## 7. 周期效果触发语义

### 7.1 触发时机

- `Context:update(dt)` 时，遍历所有带 `period` 的 Effect。
- 每个 Effect 维护 `elapsed` 与 `remaining`。
- 当 `elapsed` 跨越 `period` 的整数倍时，触发一次 Modifier 应用。

### 7.2 累积与防溢出

- 若某帧 `dt` 很大，跨越多个周期，应触发多次。
- 使用 `last_triggered_period_count` 与当前 `floor(elapsed / period)` 对比，计算差值并触发对应次数。

### 7.3 周期效果的方向

- 周期效果默认累加到目标 Attribute（如产出资源、回血）。
- 不直接支持周期性移除；如需移除，业务方可手动调用 `remove_effect` 或设置 `duration`。

---

## 8. API 汇总

### 8.1 模块入口

```lua
local mini_gas = require("cgas.mini_gas")
```

### 8.2 Context

| 方法 | 说明 |
|------|------|
| `Context.new()` | 创建新上下文 |
| `:register_attributes(defs)` | 批量注册属性基础值 |
| `:apply_effect(effect_def)` | 应用效果 |
| `:remove_effect(effect_id)` | 移除效果 |
| `:update(dt)` | 推进时间并触发周期效果 |
| `:get_base(name)` | 获取基础值 |
| `:get_final(name)` | 获取聚合后的最终值 |
| `:get_effect_ids()` | 获取当前所有生效 Effect ID 列表 |

### 8.3 工具函数

```lua
---将原始配置批量转换为 EffectDef
---@param raw_configs any[]
---@param adapter mini_gas.ConfigAdapter
---@return mini_gas.EffectDef[]
function mini_gas.adapt_effects(raw_configs, adapter) end

---计算单个属性的最终值（无状态纯函数）
---@param base number
---@param modifiers mini_gas.ModifierDef[]
---@return number
function mini_gas.calc_attribute(base, modifiers) end
```

---

## 9. 目录结构

```
lua_lib/
└── cgas/
    ├── mini_gas/
    │   ├── init.lua           -- 模块入口
    │   ├── context.lua        -- 计算上下文
    │   ├── attribute.lua      -- 属性定义与计算
    │   ├── modifier.lua       -- 修饰器类型与聚合
    │   └── effect.lua         -- Effect 定义与生命周期
```

---

## 10. 实现要点

1. **纯 Lua 表**：不依赖任何外部库，除 Lua 标准库外无依赖。
2. **无全局状态**：`Context` 自身持有全部状态，可并发创建多个实例。
3. **数值稳定**：Modifier 聚合顺序固定，避免浮点误差导致结果不稳定。
4. **效果去重**：同一 `effect_id` 重复 `apply` 时，默认先移除旧效果再应用新效果（可配置为叠加）。
5. **惰性计算**：`get_final` 可在 `update` 时预计算并缓存，避免每次读取都重新聚合。
6. **错误隔离**：非法 Modifier（目标属性不存在、未知 op）记录警告并不中断其他计算。

---

## 11. 与完整版 cgas 的关系

```
┌────────────────────────────────────────┐
│           完整版 cgas                   │
│  Ability / AttributeSet / Effect / Tag │
│  Cue / Task / Replication              │
└────────────────────────────────────────┘
                   ▲
                   │ 未来可扩展
┌────────────────────────────────────────┐
│           mini-gas                      │
│  Attribute / Modifier / Effect / Context│
│  专注服务端属性计算                      │
└────────────────────────────────────────┘
```

- `mini-gas` 是完整版 `cgas` 的子集与先行实现。
- 当项目需要技能、标签、表现等能力时，可将 `mini-gas` 的 `Context` 迁移为 `cgas.ASC`。
- 设计时保持术语一致：`Attribute`、`Modifier`、`Effect` 的概念与完整版对齐。
