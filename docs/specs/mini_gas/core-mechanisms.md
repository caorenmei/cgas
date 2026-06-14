
## 6. 核心机制

### 6.1 GameplayTag

#### 6.1.1 层级语义

标签采用点分层级结构，例如 `state.dead`、`effect.burning`。父级标签匹配所有子级标签：`state` 匹配 `state.dead`，`state.dead` 不匹配 `state.stunned`。

#### 6.1.2 Granted 标签（赋予标签）

- **Ability** 授予或 **Effect** 应用时，可通过 `grant_tags` / `granted_tags` 自动向实体添加一组标签。
- 技能/效果移除时，对应 Granted 标签自动移除（引用计数）。
- **效果的赋予应优先通过标签实现**：例如 VIP 效果授予 `buff.vip` 标签，建筑产出效果的倍率 Modifier 通过 `require_tags = {buff.vip}` 启用，从而实现系统间的相互影响，无需额外的跨实体链接机制。

#### 6.1.3 标签约束

- **Require Tags（需求标签）**：必须全部存在，技能/效果/Modifier 才能激活或生效。
- **Forbid Tags（禁用标签）**：任意一个存在，技能/效果/Modifier 即不能激活或生效。
- 约束检查在技能激活、效果应用、效果持续生效、Modifier 聚合时均会执行。

### 6.2 Attribute

#### 6.2.1 Base 与 Current

- **Base**：属性的基础值，通常由等级、装备、成长曲线决定，不随瞬时战斗波动。
- **Current**：属性的当前值，受 Effect 的 Modifier 影响后的结果。

#### 6.2.2 成长曲线

Attribute 的 Base 值可通过 `GrowthCurve` 随等级成长。`GrowthCurve` 必须提供公式函数，框架调用 `formula(level, base, params)` 计算数值；禁止通过等级查表实现。

#### 6.2.3 数值边界

每个 Attribute 可配置 `min` 与 `max`。`Current` 值在每次计算后被 Clamp 到边界内。`Hp` 等属性特别适合使用边界约束。

### 6.3 Modifier

#### 6.3.1 聚合顺序

以 `Current` 已提交值（`attr.current`，会被 Instant 效果或 `set_current` 修改）为起点，按以下顺序计算最终读取值：

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    B[Base] --> A[累加 Add]
    A --> M[累乘 Multiply]
    M --> O{存在 Override?}
    O -->|是| O2[按优先级取最终值]
    O -->|否| C1[当前结果]
    O2 --> C2[当前结果]
    C1 --> C{存在 Compound?}
    C2 --> C
    C -->|是| F[Compound 公式]
    C -->|否| R[Current]
    F --> R
```

#### 6.3.2 Modifier 标签约束

每个 Modifier 可单独配置 `require_tags` 与 `forbid_tags`。聚合时，只有满足标签约束的 Modifier 才会参与计算。这允许通过标签动态开启/关闭特定加成，例如：

- VIP 效果授予 `buff.vip` 标签。
- 建筑产出效果中的倍率 Modifier 设置 `require_tags = {buff.vip}`，仅在英雄拥有 VIP 时生效。

#### 6.3.3 等级缩放

Modifier 的 `value` 可以是 `number` 或 `GrowthCurve`。当为 `GrowthCurve` 时，根据 Effect/Ability 的等级动态取值。

### 6.4 GameplayEffect

#### 6.4.1 生命周期策略

| 策略 | 说明 |
|------|------|
| Instant | 立即执行一次 Modifier（通常是修改 Current 或 Base），不进入持续效果列表 |
| Infinite | 永久生效，直到被显式移除 |
| HasDuration | 持续 `duration` 秒后自动移除 |

#### 6.4.2 周期性效果

当 `period > 0` 时，Effect 在持续期间每隔 `period` 秒触发一次 Modifier 应用（通常是 `Add` 类型的资源产出或回血）。

#### 6.4.3 Stack 规则

- 同一 `effect_id` 再次应用时，根据 `stacking` 策略处理。
- `None`：重复应用时替换旧效果。
- `Add`：Stack 数增加，不超过 `max_stack`。
- `Replace`：用新效果替换旧效果。
- `Refresh`：刷新持续时间，Stack 数不变或取较大值。

#### 6.4.4 标签约束

效果在应用时和每帧更新时都会检查 `require_tags` 与 `forbid_tags`。若不再满足条件，效果进入挂起状态，不应用 Modifier；条件恢复后继续生效。

此外，效果内部每个 Modifier 也有独立的 `require_tags` / `forbid_tags`。即使效果本身处于激活状态，不满足约束的单个 Modifier 也不会参与聚合。这实现了精细化的标签驱动加成。

```mermaid
%%{init: {'theme': 'neutral'}}%%
stateDiagram-v2
    [*] --> Applied: apply_effect
    Applied --> Active: 满足标签约束
    Applied --> Suspended: 不满足标签约束
    Active --> Suspended: 标签约束失效
    Suspended --> Active: 标签约束恢复
    Active --> Expired: duration <= 0
    Active --> Removed: remove_effect
    Suspended --> Removed: remove_effect
    Expired --> [*]
    Removed --> [*]
```

### 6.5 GameplayAbility

#### 6.5.1 生命周期

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    A[GiveAbility] --> B[TryActivate]
    B --> C{CanActivate?}
    C -->|No| D[拒绝激活]
    C -->|Yes| E[Activate]
    E --> F[ApplyCost]
    F --> G[ApplyEffects]
    G --> H[Active]
    H --> I[EndAbility]
    I --> J[Cooldown]
    J --> B
```

#### 6.5.2 激活策略

| 策略 | 说明 |
|------|------|
| Passive | 授予后自动持续生效，通常用于天赋、光环 |
| Active | 需要业务方显式调用 `try_activate_ability` |
| Reactive | 监听指定 `activation_event`，事件发生时自动尝试激活 |

#### 6.5.3 激活条件

- 技能处于非冷却状态。
- 满足 `require_tags` 且不满足 `forbid_tags`。
- 满足消耗条件（Cost）。
- 业务可自定义 `can_activate` 回调。

#### 6.5.4 消耗

Cost 是一组 `{attribute, value}`，激活时从 `Current` 值中扣除。若任意一项不足，激活失败。

#### 6.5.5 冷却

- 技能激活后进入冷却，`cooldown_remaining` 从 `cooldown` 开始倒数。
- 冷却受等级成长曲线影响。

#### 6.5.6 激活时效果

技能激活时可自动应用一组 `EffectDef`，用于实现伤害、Buff、Debuff 等。

### 6.6 MiniASC

`MiniASC` 是 `mini-gas` 的运行时核心，但**自身不持有任何状态**。它以 `EntityState` 或 `WorldState` 为输入，职责包括：

- 读取并修改传入的 `EntityState` 中的 Attribute、Effect、Ability、Tag。
- 每帧 `update(state, dt)` 时推进 Effect 生命周期、触发周期效果、推进技能冷却。
- 通过 `update_world(world, dt)` 批量推进 `WorldState` 中所有实体的生命周期，便于统一更新。
- 执行 Modifier 聚合，计算 Attribute Current 值。
- 派发事件并通知 `EntityState` 中的监听者。
- 处理 Stack、等级、成长曲线的动态更新。

由于状态完全由调用方持有，`EntityState` 与 `WorldState` 可随时被序列化、保存、加载或通过网络同步。

### 6.7 GameplayEvent

事件是技能与效果之间解耦通信的重要手段：

- 技能激活/结束、效果应用/移除、标签变化、属性变化均会触发事件。
- Reactive 技能通过监听事件自动尝试激活。
- 业务系统可监听事件实现日志、任务、统计等功能。

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TD
    S[EntityState] -->|传入| A[触发源]
    A -->|AbilityActivated| B[MiniASC 派发事件]
    A -->|EffectApplied| B
    A -->|AttributeChanged| B
    A -->|TagAdded / TagRemoved| B
    S -->|传入| B
    B -->|修改后的 state| S
    B --> C[Reactive Ability]
    B --> D[业务监听器]
    B --> E[GameplayTask]
    C -->|TryActivate| F[Ability 激活]
```

---

---

> [返回 Mini-GAS 设计文档总览](./README.md)
