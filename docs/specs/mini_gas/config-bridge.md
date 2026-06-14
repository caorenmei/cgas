
## 8. 配置桥接设计

### 8.1 设计原则

- `mini-gas` 不读取任何文件，也不解析任何配置格式。
- 所有配置通过**适配器函数**转换为 Spec 定义结构。
- 适配器由业务方提供，可复用、可替换。

### 8.2 适配器接口

```lua
---@alias mini_gas.ConfigAdapter fun(raw_config: any): mini_gas.GameplayAbilityDef|mini_gas.EffectDef|mini_gas.AttributeDef
```

业务方提供任意函数，输入原始配置，输出对应 Spec 定义。

### 8.3 示例：从 JSON 桥接 EffectSpec

以下示例展示策划使用 `integer` 作为 alias、成长使用公式、项目级 `@enum` 由业务维护。

策划 JSON 配置：

```json
{
  "id": 1001,
  "alias": "effect.attack_up",
  "duration_policy": "HasDuration",
  "duration": 30,
  "duration_growth": 0,
  "modifiers": [
    {"attribute": 1, "op": "Add", "value": 50, "growth": 10}
  ]
}
```

项目级枚举（由业务维护，基于策划 alias）：

```lua
---@enum project.EAttribute
local EAttribute = {
    Attack = 1, -- 对应策划配置的 attribute alias
}

---@enum project.EEffectId
local EEffectId = {
    AttackUp = 1001, -- 对应策划配置的 id alias
}

-- 策划 alias -> 项目枚举的反向映射
local attr_by_alias = {
    [1] = EAttribute.Attack,
}

local effect_by_alias = {
    [1001] = EEffectId.AttackUp,
}
```

通用线性成长公式：

```lua
---@type mini_gas.GrowthCurve
local function linear_growth(level, base, growth)
    return base + (level - 1) * (growth or 0)
end
```

适配器实现：

```lua
---@param json_cfg table
---@param level? number
---@return mini_gas.EffectDef
local function effect_adapter(json_cfg, level)
    level = level or 1
    local modifiers = {}
    for _, m in ipairs(json_cfg.modifiers) do
        modifiers[#modifiers + 1] = {
            attribute = attr_by_alias[m.attribute], -- 通过策划 alias 映射到项目枚举
            op = mini_gas.EModifierOp[m.op],
            value = linear_growth(level, m.value, m.growth),
        }
    end

    return {
        id = effect_by_alias[json_cfg.id],
        alias = json_cfg.alias,
        duration_policy = mini_gas.EDurationPolicy[json_cfg.duration_policy],
        duration = linear_growth(level, json_cfg.duration, json_cfg.duration_growth),
        modifiers = modifiers,
    }
end
```

使用：

```lua
local state = EntityState.new()
MiniASC.register_attributes(state, {
    { name = EAttribute.Attack, base = 100 },
})

local effect_def = effect_adapter(json.decode(effect_config_text), 3)
MiniASC.apply_effect(state, effect_def, 3, 1) -- 3 级时 value = 50 + (3-1)*10 = 70

-- state 为纯 Lua 表，可直接序列化
local saved = json.encode(state)
```

---

---

> [返回 Mini-GAS 设计文档总览](./README.md)
