# LuaLS 注解（Annotations）参考手册

> **来源**: [Lua Language Server Wiki - Annotations](https://luals.github.io/wiki/annotations/)  
> **翻译整理日期**: 2026-06-01

---

## 目录

- [注解](#注解)
- [注解格式化](#注解格式化)
- [引用符号](#引用符号)
- [小技巧](#小技巧)
- [类型文档化](#类型文档化)
- [理解本页](#理解本页)
- [注解列表](#注解列表)
  - [@alias](#alias)
  - [@as](#as)
  - [@async](#async)
  - [@cast](#cast)
  - [@class](#class)
  - [@deprecated](#deprecated)
  - [@diagnostic](#diagnostic)
  - [@enum](#enum)
  - [@field](#field)
  - [@generic](#generic)
  - [@meta](#meta)
  - [@module](#module)
  - [@nodiscard](#nodiscard)
  - [@operator](#operator)
  - [@overload](#overload)
  - [@package](#package)
  - [@param](#param)
  - [@private](#private)
  - [@protected](#protected)
  - [@return](#return)
  - [@see](#see)
  - [@source](#source)
  - [@type](#type)
  - [@vararg](#vararg)
  - [@version](#version)

---

## 注解

为你的代码和类型检查添加额外的上下文信息。

语言服务器会尽力通过上下文分析来推断类型，但有时仍需手动编写文档以改进补全和签名信息。这是通过 **LuaCATS**（**L**ua **C**omment **A**nd **T**ype **S**ystem，Lua 注释与类型系统）注解实现的，该系统基于 [EmmyLua 注解](https://emmylua.github.io/annotation.html)。

注解以 `---` 为前缀，类似于 Lua 注释但多了一个横杠。

> **⚠️ 警告**  
> 从 v3 版本开始，LuaCATS 注解与 [EmmyLua 注解](https://emmylua.github.io/annotation.html) [不再交叉兼容](https://github.com/LuaLS/lua-language-server/issues/980)。

---

## 注解格式化

注解支持大部分 [Markdown 语法](https://www.markdownguide.org/cheat-sheet/)。具体来说，你可以使用：

- 标题（headings）
- 粗体文本（bold text）
- 斜体文本（italic text）
- 删除线文本（struckthrough text）
- 有序列表（ordered list）
- 无序列表（unordered list）
- 块引用（blockquote）
- 行内代码（code）
- 代码块（code block）
- 水平分割线（horizontal rule）
- 链接（link）
- 图片（image）

有多种方式可以在注解中添加换行。最可靠的方法是简单地添加一行仅包含 `---` 的额外行，不过它的作用类似于段落分隔，而非新行。

以下方法可以添加到行尾：

- HTML `<br>` 标签（推荐）
- `\n` 换行转义字符
- 两个尾部空格（可能被格式化工具移除）
- Markdown 反斜杠 `\`（[不推荐](https://www.markdownguide.org/basic-syntax#line-break-best-practices)）

---

## 引用符号

从 [v3.9.2](https://github.com/LuaLS/lua-language-server/releases/tag/3.9.2) 开始，你可以在 Markdown 描述中使用 Markdown 链接引用工作区中的符号。悬停在描述的值上时会显示一个超链接，点击后会跳转到该符号的定义位置。

```lua
---@alias MyCustomType integer

---使用 [my custom type](lua://MyCustomType) 计算一个值
function calculate(x)
end
```

---

## 小技巧

如果你在函数上方一行输入 `---`，你将收到一个建议的代码片段，其中包含函数中每个参数和返回值的 `@param` 和 `@return` 注解。

**【图片 OCR 识别 - VS Code 自动补全截图】**

> 下图展示了在 VS Code 中编写 Lua 代码时，在函数定义上方输入 `---` 后触发的自动补全功能：
>
> - 文件：`lua.lua`
> - 在第 2 行输入 `---comment` 后，编辑器弹出自动补全建议
> - 建议项显示：`@param;@return`
> - 预览的生成代码：
>   ```lua
>   ---@param b any
>   ---@param c any
>   ---@param d any
>   ```
> - 第 3 行函数定义：`local function myFunc(a, b, c, d)`
> - 第 5 行：`end`
>
> 这表明当在 `myFunc(a, b, c, d)` 函数上方输入 `---` 时，LuaLS 会自动为每个参数生成对应的 `@param` 注解。

---

## 类型文档化

使用语言服务器正确地文档化类型非常重要，这是许多功能和优势所在。以下是所有已识别的 Lua 类型列表（无论使用哪个版本）：

| 基础类型 |
|---------|
| `nil` |
| `any` |
| `boolean` |
| `string` |
| `number` |
| `integer` |
| `function` |
| `table` |
| `thread` |
| `userdata` |
| `lightuserdata` |

你还可以模拟 [类（classes）](#class) 和 [字段（fields）](#field)，甚至 [创建自己的类型](#alias)。

在类型后添加问号（`?`），如 `boolean?` 或 `number?`，等同于 `boolean|nil` 或 `number|nil`。这可用于指定某个值要么是指定类型，**要么**是 `nil`。这对于函数返回值可能返回一个值 **或** `nil` 的情况非常有用。

以下是文档化更高级类型的方法：

| 类型 | 文档化方式 |
|------|-----------|
| 联合类型（Union Type） | `TYPE_1 | TYPE_2` |
| 数组（Array） | `VALUE_TYPE[]` |
| 元组（Tuple） | `[VALUE_TYPE, VALUE_TYPE]` |
| 字典（Dictionary） | `{ [string]: VALUE_TYPE }` |
| 键值表（Key-Value Table） | `table<KEY_TYPE, VALUE_TYPE>` |
| 表字面量（Table literal） | `{ key1: VALUE_TYPE, key2: VALUE_TYPE }` |
| 函数（Function） | `fun(PARAM: TYPE): RETURN_TYPE` |

在某些情况下，联合类型可能需要放在括号中，例如定义包含多种值类型的数组时：

```lua
---@type (string | integer)[]
local myArray = {}
```

---

## 理解本页

要理解如何使用本页描述的注解，你需要了解如何阅读每个注解的**语法**部分。

| 符号 | 含义 |
|------|------|
| `<value_name>` | 你需要提供的必需值 |
| `[value_name]` | 方括号内的所有内容都是可选的 |
| `[value_name...]` | 该值是可重复的 |
| `value_name | value_name` | 左侧 **或** 右侧都是有效的 |

任何其他符号在语法上是必需的，应原样复制。

如果这令人困惑，可以查看注解下面的一些示例，应该会更好理解。

---

## 注解列表

以下是语言服务器识别的所有注解列表：

---

### @alias

别名可用于创建你自己的类型。你也可以用它创建一个在运行时不存在的枚举。对于在运行时确实存在的枚举，请参见 [@enum](#enum)。

**语法**

```lua
---@alias <name> <type>
```

**示例**

**简单别名**
```lua
---@alias userID integer  -- 用户的 ID
```

**自定义类型**
```lua
---@alias modes "r" | "w"
```

**带描述的自定义类型**
```lua
---@alias DeviceSide
---| '"left"'    # 设备的左侧
---| '"right"'   # 设备的右侧
---| '"top"'     # 设备的顶部
---| '"bottom"'  # 设备的底部
---| '"front"'   # 设备的正面
---| '"back"'    # 设备的背面

---@param side DeviceSide
local function checkSide(side)
end
```

**字面量自定义类型**
```lua
local A = "Hello"
local B = "World"

---@alias myLiteralAlias `A` | `B`

---@param x myLiteralAlias
function foo(x)
end
```

---

### @as

强制将某个类型赋予一个表达式。

> **⚠️ 警告**  
> 此注解不能使用 `---@as <type>` 的形式添加，必须使用 `--[[@as <type>]]` 的格式。

> **📝 注意**  
> 当将表达式标记为数组（如 `string[]`）时，必须使用 `--[=[@as string[]]=]`，因为额外的方括号会导致解析问题。

**语法**

```lua
--[[@as <type>]]
```

> **📝 注意**  
> 上述语法定义中的方括号不是指它是可选的。这些方括号必须原样使用。

**示例**

**覆盖类型**
```lua
---@param key string 必须是字符串
local function doSomething(key)
end

local x = nil
doSomething(x --[[@as string]])
```

---

### @async

将函数标记为异步。当 `hint.await` 为 `true` 时，标记为 `@async` 的函数在被调用时会显示 `await` 提示。被 [await 诊断组](https://luals.github.io/wiki/diagnostics/#await) 使用。

**语法**

```lua
---@async
```

**示例**

**将函数标记为异步**
```lua
---@async
---执行异步 HTTP GET 请求
function http.get(url)
end
```

---

### @cast

将变量转换为不同的类型或多个类型。

**语法**

```lua
---@cast <value_name> [+|-]<type|?>[, [+|-]<type|?>...]
```

**示例**

**简单转换**
```lua
---@type integer | string
local x

---@cast x string
print(x)  --> x: string
```

**添加类型**
```lua
---@type integer
local x

---@cast x +boolean
print(x)  --> x: integer | boolean
```

**移除类型**
```lua
---@type integer | string
local x

---@cast x -integer
print(x)  --> x: string
```

**转换多个类型**
```lua
---@type string
local x  --> x: string

---@cast x +boolean, +number
print(x)  --> x:string | boolean | number
```

**转换可能为 nil**
```lua
---@type string
local x

---@cast x +?
print(x)  --> x:string?
```

---

### @class

定义一个类。可以与 [@field](#field) 一起使用来定义表结构。一旦定义了类，就可以将其用作 [参数](#param)、[返回值](#return) 等的类型。类还可以继承一个或多个父类。将类标记为 `(exact)` 意味着定义后不能注入字段。

**语法**

```lua
---@class [(exact)] <name>[: <parent>[, <parent>...]]
```

**示例**

**定义类**
```lua
---@class Car
local Car = {}
```

**类继承**
```lua
---@class Vehicle
local Vehicle = {}

---@class Plane : Vehicle
local Plane = {}
```

**创建精确类**
```lua
---@class (exact) Point
---@field x number
---@field y number
local Point = {}

Point.x = 1   -- OK
Point.y = 2   -- OK
Point.z = 3   -- 警告！不能注入新字段
```

**table 类的实现方式**
```lua
---@class table<K, V> : { [K]: V }
```

---

### @deprecated

将函数标记为已弃用。这将触发 [deprecated 诊断](https://luals.github.io/wiki/diagnostics/#deprecated)，并将其显示为 ~~删除线~~。

**语法**

```lua
---@deprecated
```

**示例**

**将函数标记为已弃用**
```lua
---@deprecated
function outdated()
end
```

---

### @diagnostic

为下一行、当前行或整个文件切换[诊断](https://luals.github.io/wiki/diagnostics/)功能。

**语法**

```lua
---@diagnostic <state>:<diagnostic>[, diagnostic…]
```

**state 选项：**

| 选项 | 说明 |
|------|------|
| `disable-next-line` | 禁用下一行的诊断 |
| `disable-line` | 禁用当前行的诊断 |
| `disable` | 禁用当前文件的诊断 |
| `enable` | 启用当前文件的诊断 |

**示例**

**禁用下一行的诊断**
```lua
---@diagnostic disable-next-line: unused-local
```

**在当前文件中启用拼写检查**
```lua
---@diagnostic enable: spell-check
```

---

### @enum

将一个 Lua 表标记为枚举，赋予它与 [@alias](#alias) 类似的功能，但该表在运行时仍然可用。添加 `(key)` 属性将使用枚举的键而不是值。

[原始功能请求](https://github.com/LuaLS/lua-language-server/issues/1255)

**语法**

```lua
---@enum [(key)] <name>
```

**示例**

**将表定义为枚举**
```lua
---@enum colors
local COLORS = {
    black  = 0,
    red    = 2,
    green  = 4,
    yellow = 8,
    blue   = 16,
    white  = 32
}

---@param color colors
local function setColor(color)
end

setColor(COLORS.green)
```

**将表的键定义为枚举**
```lua
---@enum (key) Direction
local direction = {
    LEFT  = 1,
    RIGHT = 2,
}

---@param dir Direction
local function move(dir)
    assert(dir == "LEFT" or dir == "RIGHT")
    assert(direction[dir] == 1 or direction[dir] == 2)
    assert(direction[dir] == direction.LEFT or direction[dir] == direction.RIGHT)
end

move("LEFT")
```

---

### @field

定义表中的字段。应紧接在 [@class](#class) 之后。从 v3.6 开始，你可以将字段标记为 `private`、`protected`、`public` 或 `package`。

**语法**

```lua
---@field [scope] <name[?]> <type> [description]
```

也可以允许添加任何指定类型的键，使用以下语法：

```lua
---@field [scope] [<type>] <type> [description]
```

> **📝 注意**  
> 上述第一个类型周围的方括号必须原样复制。此外，任何命名字段必须先定义。请参阅下面的**类型化字段**示例。

**示例**

**类的简单文档化**
```lua
---@class Person
---@field height   number   此人的身高（厘米）
---@field weight   number   此人的体重（公斤）
---@field firstName string  此人的名字
---@field lastName  ?string  此人的姓氏（可选）
---@field age      integer  此人的年龄

---@param person Person
local function hire(person)
end
```

**将字段标记为私有**
```lua
---@class Animal
---@field private legs integer
---@field        eyes integer

---@class Dog : Animal
local myDog = {}

---子类 Dog 不能使用私有字段 legs
function myDog:legCount()
    return self.legs  -- 错误！
end
```

**将字段标记为受保护**
```lua
---@class Animal
---@field protected legs integer
---@field           eyes integer

---@class Dog : Animal
local myDog = {}

---子类 Dog 可以使用受保护字段 legs
function myDog:legCount()
    return self.legs  -- OK
end
```

**类型化字段**
```lua
---@class Numbers
---@field named string
---@field [string] integer

local Numbers = {}
```

---

### @generic

泛型允许代码被复用，并作为某种类型的"占位符"。用反引号（`` ` ``）包围泛型将捕获参数中的字符串值，并将命名的类/类型推断为泛型类型。

[泛型仍在开发中](https://github.com/LuaLS/lua-language-server/issues/1861)。

**语法**

```lua
---@generic <name> [:parent_type] [, <name> [:parent_type]]
```

**示例**

**泛型函数**
```lua
---@generic T : integer

---@param p1 T
---@return T, T[]
function Generic(p1)
end

-- v1: string
-- v2: string[]
local v1, v2 = Generic("String")

-- v3: integer
-- v4: integer[]
local v3, v4 = Generic(10)
```

**使用反引号捕获**
```lua
---@class Vehicle

---@generic T
---@param class `T`     # 类型被捕获
---@return T             # 返回类型将是根据 `class` 参数的字符串值推断出的类/类型
local function newWithCapture(class)
end

-- obj1 在这里的类型是 `Vehicle`，因为 "Vehicle" 从提供的参数中被捕获
local obj1 = newWithCapture("Vehicle")

---@generic T
---@param class T       # 类型不被捕获
---@return T             # 返回类型将与 `class` 参数的类型相同
local function newWithoutCapture(class)
end

-- obj2 在这里的类型是 `string`，因为提供的参数是字符串
local obj2 = newWithoutCapture("Vehicle")
```

**使用泛型的数组类**
```lua
---@class Array<T> : { [integer]: T }

---@type Array<string>
local arr = {}

-- 警告：将 boolean 赋值给 string
arr[1] = false
arr[3] = "Correct"
```

**使用泛型的字典类**
```lua
---@class Dictionary<T> : { [string]: T }

---@type Dictionary<boolean>
local dict = {}

-- 尽管赋值了字符串，但不会警告
dict["foo"] = "bar?"
dict["correct"] = true
```

---

### @meta

将文件标记为"元"（meta），意味着它用于定义而不是作为功能性 Lua 代码。语言服务器内部使用它来定义[内置 Lua 库](https://github.com/LuaLS/lua-language-server/tree/master/meta/template)。如果你正在编写自己的[定义文件](https://luals.github.io/wiki/definition-files/)，你可能需要在其中包含此注解。如果指定了名称，则只能通过该名称来 require。将名称设为 `_` 将使其无法被 require。带有 `@meta` 标签的文件行为略有不同：

- 在元文件中不会显示上下文的补全
- 悬停在元文件的 require 上将显示 `[meta]` 而不是其绝对路径
- 查找引用会忽略元文件

**语法**

```lua
---@meta [name]
```

**示例**

**标记元文件**
```lua
---@meta
```

---

### @module

模拟 `require` 一个文件。

**语法**

```lua
---@module '<module_name>'
```

**示例**

**"Require" 一个文件**
```lua
---@module 'http'
-- 上述等同于
require 'http'
-- 在语言服务器内部
```

**"Require" 一个文件并赋值给变量**
```lua
---@module 'http'
local http
-- 上述等同于
local http = require 'http'
-- 在语言服务器内部
```

---

### @nodiscard

将函数标记为具有**不能**被忽略/丢弃的返回值。这可以帮助用户理解如何使用该函数，因为如果他们不捕获返回值，将会发出警告。

**语法**

```lua
---@nodiscard
```

**示例**

**防止忽略函数的返回值**
```lua
---@return string username
---@nodiscard
function getUsername()
end
```

---

### @operator

为[运算符元方法](http://lua-users.org/wiki/MetatableEvents)提供类型声明。

[原始功能请求](https://github.com/LuaLS/lua-language-server/issues/599)

**语法**

```lua
---@operator <operation>[(param_type)]:<return_type>
```

> **📝 注意**  
> 此语法与用于定义函数的 `fun()` 语法略有不同。注意这里的括号是**可选**的，所以 `@operator call:integer` 是有效的。

**示例**

**声明 `__add` 元方法**
```lua
---@class Vector
---@operator add(Vector): Vector

---@type Vector
local v1

---@type Vector
local v2

--> v3: Vector
local v3 = v1 + v2
```

**声明一元减号元方法**
```lua
---@class Passcode
---@operator unm: integer

---@type Passcode
local pA

local pB = -pA  --> integer
```

**声明 `__call` 元方法**

> 建议使用 [@overload](#overload) 来指定类的调用签名。

```lua
---@class URL
---@operator call: string

local URL = {}
```

---

### @overload

为函数定义额外的签名。

**语法**

```lua
---@overload fun([param: type[, param: type...]]): [return_value[,return_value]]
```

> **⚠️ 问题**  
> 当前存在[重载时类型收窄的问题](https://github.com/LuaLS/lua-language-server/issues/1456)。

> **📝 注意**  
> 如果你正在编写[定义文件](https://luals.github.io/wiki/definition-files/)，建议改为编写多个函数定义，每个需要的签名都使用其 [@param](#param) 和 [@return](#return) 注解。这可以让函数尽可能详细。因为这些函数在运行时不存在，所以这是可接受的。

**示例**

**定义函数重载**
```lua
---@param objectID      integer  要移除的对象 ID
---@param whenOutOfView boolean  仅在对象不可见时移除
---@return boolean success       对象是否成功移除
---@overload fun(objectID: integer): boolean
local function removeObject(objectID, whenOutOfView)
end
```

**定义类调用签名**
```lua
---@overload fun(a: string): boolean

local foo = setmetatable({}, {
    __call = function(a)
        print(a)
        return true
    end,
})

local bool = foo("myString")
```

---

### @package

将函数标记为仅在其定义的文件中私有。打包的函数不能从另一个文件访问。

**语法**

```lua
---@package
```

**示例**

**将函数标记为包私有**
```lua
---@class Animal
---@field private eyes integer
local Animal = {}

---@package
---此函数不能在另一个文件中访问
function Animal:eyesCount()
    return self.eyes
end
```

---

### @param

为函数定义参数/实参。这告诉语言服务器期望的类型是什么，并可以帮助强制执行类型和提供补全。在参数名后加问号（`?`）会将其标记为可选，意味着 `nil` 是可接受的类型。提供的类型当然也可以是 [@alias](#alias)、[@enum](#enum) 或 [@class](#class)。

**语法**

```lua
---@param <name[?]> <type[|type...]> [description]
```

**示例**

**简单函数参数**
```lua
---@param username string 要为此用户设置的名字
function setUsername(username)
end
```

**参数联合类型**
```lua
---@param setting string         设置的名称
---@param value   string|number|boolean  设置的值
local function settings.set(setting, value)
end
```

**可选参数**
```lua
---@param role     string  角色的名称
---@param isActive ?boolean 角色当前是否激活
---@return Role
function Role.new(role, isActive)
end
```

**可变数量的参数**
```lua
---@param index  integer
---@param ...    string  要添加到此条目的标签
local function addTags(index, ...)
end
```

**泛型函数参数**
```lua
---@class Box

---@generic T
---@param objectID integer    要设置类型的对象的 ID
---@param type     `T`       要设置的类型
---@return `T` object        作为 Lua 对象的对象
local function setObjectType(objectID, type)
end

--> boxObject: Box
local boxObject = setObjectType(1, "Box")
-- 详见 @generic 获取更多信息
```

**自定义类型参数**
```lua
---@param mode string
---| "'immediate'"  # 注释 1
---| "'async'"      # 注释 2
function bar(mode)
end
```

**字面量自定义类型参数**
```lua
local A = 0
local B = 1

---@param active integer
---| `A`   # 值为 0
---| `B`   # 值为 1
function set(active)
end

-- 想用表来实现？你可能需要使用 @enum
```

---

### @private

将函数标记为 [@class](#class) 的私有函数。私有函数只能从其类内部访问，**不能**从子类访问。

**语法**

```lua
---@private
```

**示例**

**将函数标记为私有**
```lua
---@class Animal
---@field private eyes integer
local Animal = {}

---@private
function Animal:eyesCount()
    return self.eyes
end

---@class Dog : Animal
local myDog = {}

-- 不允许！
myDog:eyesCount()
```

---

### @protected

将函数标记为 [@class](#class) 的受保护函数。受保护函数只能从其类内部或子类访问。

**语法**

```lua
---@protected
```

**示例**

**将函数标记为受保护**
```lua
---@class Animal
---@field private eyes integer
local Animal = {}

---@protected
function Animal:eyesCount()
    return self.eyes
end

---@class Dog : Animal
local myDog = {}

-- 允许，因为函数是受保护的，不是私有的
myDog:eyesCount()
```

---

### @return

定义函数的[返回值](#return)。这告诉语言服务器期望的类型是什么，并可以帮助强制执行类型和提供补全。

**语法**

```lua
---@return <type> [<name> [comment] | [name] #<comment>]
```

**示例**

**简单函数返回**
```lua
---@return boolean
local function isEnabled()
end
```

**命名函数返回**
```lua
---@return boolean enabled
local function isEnabled()
end
```

**命名、描述的函数返回**
```lua
---@return boolean enabled 如果项目已启用
local function isEnabled()
end
```

**多个命名、描述的函数返回**
```lua
---@return boolean ok        # 成功时返回 true
---@return table|nil result  # 解析结果或出错时返回 nil
local function parse()
end
```

**描述的函数返回**
```lua
---@return boolean  # 如果项目已启用
local function isEnabled()
end
```

**可选函数返回**
```lua
---@return boolean|nil error
local function makeRequest()
end
```

**可变函数返回**
```lua
---@return integer count  找到的昵称数量
---@return string ...
local function getNicknames()
end
```

---

### @see

允许你引用工作区中的特定符号（例如 `function`、`class`）。你也可以使用 [markdown 链接](#引用符号) 来引用符号。

**语法**

```lua
---@see <symbol>
```

**示例**

**基本用法**
```lua
---悬停在下面的函数上将显示一个跳转到 http.get() 的链接
---@see http.get
function request(url)
end
```

---

### @source

提供对存在于另一个文件中的某些源代码的引用。当搜索项目的定义时，将使用其 `@source`。

**语法**

```lua
---@source <path>
```

**示例**

**使用绝对路径链接到文件**
```lua
---@source C:/Users/me/Documents/program/myFile.c
local a
```

**使用 URI 链接到文件**
```lua
---@source file:///C:/Users/me/Documents/program/myFile.c:10
local b
```

**使用相对路径链接到文件**
```lua
---@source local/file.c
local c
```

**链接到文件中的行和字符**
```lua
---@source local/file.c:10:8
local d
```

---

### @type

将变量标记为属于某种类型。联合类型使用管道字符 `|` 分隔。提供的类型也可以是 [@alias](#alias)、[@enum](#enum) 或 [@class](#class)。请注意，你不能使用 `@type` 向类添加字段，[必须使用 @class](#class)。

**语法**

```lua
---@type <type>
```

**示例**

**基本类型定义**
```lua
---@type boolean
local x
```

**数组类型定义**
```lua
---@type string[]
local names
```

**字典类型定义**
```lua
---@type { [string]: boolean }
local statuses
```

**表类型定义**
```lua
---@type table<userID, Player>
local players
```

**联合类型定义**
```lua
---@type boolean|number|"yes"|"no"
local x
```

**函数类型定义**
```lua
---@type fun(name: string, value: any): boolean
local x
```

---

### @vararg

将[函数](#function)标记为具有可变参数。对于可变返回，请参见 [@return](#return)。

> **⚠️ 已弃用**  
> 此注解已弃用，纯粹为了兼容 EmmyLua 注解而保留。请使用 [@param](#param) 代替。

**语法**

```lua
---@vararg <type>
```

**示例**

**基本可变函数参数**
```lua
---@vararg string
function concat(...)
end
```

---

### @version

标记[函数](#function)或[@class](#class)所需的 Lua 版本。

**语法**

```lua
---@version [<|>]<version> [, [<|>]version...]
```

可能的 `version` 值：

- `5.1`
- `5.2`
- `5.3`
- `5.4`
- `JIT`

**示例**

**声明函数版本**
```lua
---仅适用于 Lua 5.3 及更高版本
---@version >= 5.3
function foo()
end

---仅适用于 Lua 5.1
---@version 5.1
function bar()
end
```

**声明类版本**
```lua
---@version >= 5.1
---@class Foo
```

---

## 参考链接

- [Lua Language Server 官方网站](https://luals.github.io/)
- [Lua Language Server GitHub](https://github.com/luals/lua-language-server)
- [EmmyLua 注解（原始参考）](https://emmylua.github.io/annotation.html)
- [Markdown 语法指南](https://www.markdownguide.org/cheat-sheet/)
