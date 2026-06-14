
## 3. 核心设计原则

### 3.1 独立无依赖

`mini-gas` 仅依赖 Lua 标准库，不依赖任何外部 GAS 库或第三方库。所有类型、工具函数均在 `lua_lib/mini_gas` 内自包含。

### 3.2 Level / Stack 驱动成长

游戏中的英雄、技能、装备、Buff 都具有成长性。`mini-gas` 的成长性由运行时实例的 `level` / `stack` 与配置 `Def` 中的公式函数共同描述：

- `AbilityDef.cooldown` / `AbilityDef.cost[attr]`：`fun(self: GameplayAbility): number`
- `EffectDef.duration` / `EffectDef.period`：`fun(self: GameplayEffect): number`
- `ModifierDef.value`（Compound）：`fun(self: Modifier, v: number): number`

`MiniASC` 在实例化时将传入的 `level` / `stack` 写入运行时实例，公式函数读取这些字段完成数值计算。

### 3.3 无魔术字符串

所有标识符均通过 `@enum` 或 `@class` 定义，且其值对应策划配置的 `alias`（`string | integer`）：

- 属性名：`mini_gas.EAttribute`（框架不预定义业务属性；由策划配置）
- 标签名：`mini_gas.ETag`（框架不预定义业务标签；由策划配置）
- 技能 ID：`mini_gas.EAbilityId`（框架不预定义业务技能；由策划配置）
- 效果 ID：`mini_gas.EEffectId`（框架不预定义业务效果；由策划配置）
- 事件名：`mini_gas.EGameplayEvent`（框架仅预定义生命周期事件；业务事件由策划配置）
- 修饰操作：`mini_gas.EModifierOp`
- 生命周期策略：`mini_gas.EDurationPolicy`
- 技能激活策略：`mini_gas.EAbilityActivationPolicy`

业务代码禁止直接书写 `"attr.max_hp"`、`"Add"`、`"ability.attack"` 等字面量。业务 ID 应由策划配置并通过 `ConfigAdapter` 映射到项目级 `@enum`。

### 3.4 状态完全自包含

`mini-gas` 的运行时状态对象（`EntityState` / `Modifier` / `GameplayEffect` / `GameplayAbility` / `GameplayTask`）均为无元表的普通 Lua 表，且**不引用任何外部对象**（包括配置 Def、下划线查找表、其他运行时实例）。运行时数据在创建时即复制完整的 Def 信息，可直接序列化、持久化与网络同步。

配置定义集中存放在 `Defs` 表中，由调用方持有，并在需要的 API 调用中传入。

### 3.5 事件驱动

技能激活、效果触发、标签变化、属性变化均通过 `GameplayEvent` 进行通知，便于业务系统扩展。

```mermaid
%%{init: {'theme': 'neutral'}}%%
mindmap
  root((核心设计原则))
    独立无依赖
      不依赖外部 GAS 库
      不依赖第三方库
      仅 Lua 标准库
    Level / Stack 驱动成长
      GameplayAbility.level/stack
      GameplayEffect.level/stack
      Modifier.level/stack
      按类型公式函数
    无魔术字符串
      idAliasText["alias: string | integer"]
      项目级 @enum
      ConfigAdapter 映射
    状态完全自包含
      EntityState 外置
      Defs 分离
      便于序列化
      便于持久化
    事件驱动
      Ability 激活
      Effect 应用/移除
      Attribute 变化
      Tag 变化
```

---

## 4. 架构

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TD
    A[外部配置源<br/>Excel / JSON / DB / 策划脚本 / 硬编码] -->|原始配置| B[ConfigAdapter<br/>配置适配器]
    B -->|AbilityDef / EffectDef /<br/>AttributeDef| D[mini_gas.Defs]
    D -->|defs| C[mini_gas.MiniASC]
    E[EntityState<br/>业务方持有<br/>可序列化] -->|state| C
    W[WorldState<br/>table<EntityId, EntityState>] -->|world| C
    C -->|修改后的 state| E
    C -->|修改后的 world| W
    C -->|计算结果| F[业务系统使用方<br/>战斗 / 技能 / VIP / 道具 / 建筑 / 任务 / 成长]
```

```mermaid
%%{init: {'theme': 'neutral'}}%%
mindmap
  root((类型体系))
    idEnum["@enum"]
      EModifierOp
      EDurationPolicy
      EStackingPolicy
      EAbilityActivationPolicy
      EAttribute
      ETag
      EAbilityId
      EEffectId
      EGameplayEvent
    idClass["@class"]
      MiniASC
      Defs
      EntityState
      WorldState
      GameplayAbility
      GameplayAbilityDef
      GameplayEffect
      EffectDef
      Modifier
      ModifierDef
      AttributeDef
      GameplayTagContainer
      GameplayTask
    idAlias["@alias"]
      TagId
      AttributeId
      AbilityId
      EffectId
      GameplayEventId
      ConfigAdapter
```

---

---

> [返回 Mini-GAS 设计文档总览](./README.md)
