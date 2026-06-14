# cgas

`cgas` 是一个基于 Lua 的 GAS（Gameplay Ability System）库，参考 Unreal Engine 的 GAS 系统设计，用于在 Lua 项目中构建技能、属性、效果与标签驱动的游戏玩法机制。

## 功能特性

- **AbilitySystemComponent（ASC）**：实体上的 GAS 入口，管理 Ability、AttributeSet、Effect、Tag 与 Cue。
- **GameplayAbility**：支持生命周期状态机、标签约束、Cost/Cooldown、实例化策略与 AbilityTask。
- **AttributeSet / Attribute**：Base/Current 值、Modifier 聚合（Add → Multiply → Divide → Override → Clamp）。
- **GameplayEffect**：Instant / Duration / Infinite / Periodic 四种持续策略，支持 Stack、Granted Tags 与 Removed Tags。
- **GameplayTag**：层级标签、容器、Query（All/Any/None）。
- **适配层**：提供手动 `update(dt)` 与 Love2D 适配示例。
- **网络占位**：预留 Replication / Prediction / GameplayEvent 数据结构。

## 安装

### LuaRocks（推荐）

```bash
luarocks install cgas
```

> 目前 rockspec 中的 URL 为占位符，正式发布前请替换为实际仓库地址。

### 本地开发

```bash
git clone <repository-url> cgas
cd cgas
./luarocks install busted
./busted lua_tests/
```

## 快速开始

```lua
local cgas = require("cgas")

-- 创建玩家 ASC
local player = cgas.create_asc()

-- 注册属性集
local HealthSet = { name = "HealthSet" }
function HealthSet:on_init(set)
    set:register_attribute("Health", 100, { max_value = 100 })
end
player:add_attribute_set(HealthSet)

-- 定义一个即时治疗效果
local Heal = cgas.GameplayEffect.new({
    name = "Heal",
    duration_policy = "instant",
    modifiers = {
        { attribute_name = "HealthSet.Health", op = "add", magnitude = 20 },
    },
})

-- 应用效果
player:apply_effect({ effect_class = Heal })
print(player:get_attribute("HealthSet.Health").current_value) -- 120
```

更多完整示例请见 `lua_tests/integration/fireball_spec.lua`。

## 运行测试

项目使用 [busted](https://olivinelabs.com/busted/) 作为测试框架：

```bash
./busted lua_tests/
```

`./busted` 会自动配置本地 `lua_modules/` 路径并加载 `luarocks.loader`。

## 项目结构

```
cgas/
├── docs/                    # 项目文档
│   ├── books/               # 第三方库中文文档
│   └── specs/               # 功能规格说明
├── lua_lib/                 # 核心库代码
│   └── cgas/
│       ├── core/            # 核心层（object/event/scheduler/timer/registry）
│       ├── semantics/       # 语义层（asc/ability/attribute/effect/tag/cue/task）
│       ├── adapters/        # 适配层（manual/love2d）
│       └── net/             # 网络占位层
├── lua_tests/               # 测试代码（以 *_spec.lua 命名）
├── lua_modules/             # 本地 LuaRocks 依赖树
├── AGENTS.md                # 项目开发规范
├── CLAUDE.md                # Claude 开发指令
├── cgas-0.1.0-1.rockspec    # LuaRocks 包配置
└── .luarc.json              # LuaLS 配置
```

## 开发规范

详细规范请阅读 `AGENTS.md`，核心要点：

- **语言**：用户交互、文档、注释使用简体中文；代码与配置使用英文。
- **TDD**：新功能、Bug 修复、重构遵循红-绿-重构循环。
- **静态诊断**：提交前运行 `lua-language-server --check . --configpath .luarc.json`。
- **Git Worktree**：使用 `git worktree` 管理多分支并行开发，worktree 统一放在 `.worktrees/` 下。

## 许可证

MIT
