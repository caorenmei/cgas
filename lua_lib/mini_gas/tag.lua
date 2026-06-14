--- GameplayTag 与 GameplayTagContainer
--- 类型定义见 mini_gas.types
--- GameplayTag / GameplayTagContainer 实例为无元表的纯数据表，操作通过模块级函数完成。
local M = {}

M.GameplayTag = {}
M.GameplayTagContainer = {}

---构造标签
---@param tag mini_gas.TagId
---@return mini_gas.GameplayTag
function M.GameplayTag.new(tag)
    return {
        name = tostring(tag),
    }
end

---判断点分层级前缀关系
---@param a string
---@param b string
---@return boolean
local function tag_matches(a, b)
    if a == b then
        return true
    end
    return a:sub(1, #b + 1) == b .. "." or b:sub(1, #a + 1) == a .. "."
end

---判断自身是否匹配另一个标签（精确或父级）
---@param tag mini_gas.GameplayTag
---@param other mini_gas.GameplayTag
---@return boolean
function M.matches(tag, other)
    return tag_matches(tag.name, other.name)
end

---创建空容器
---@return mini_gas.GameplayTagContainer
function M.GameplayTagContainer.new()
    return {
        tags = {},
        counts = {},
    }
end

---添加标签（支持按来源引用计数）
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source string|nil 来源标识，默认 "_explicit"
function M.add(container, tag, source)
    source = source or "_explicit"
    local name = tostring(tag)
    container.counts[name] = container.counts[name] or {}
    container.counts[name][source] = (container.counts[name][source] or 0) + 1
    if not container.tags[name] then
        container.tags[name] = M.GameplayTag.new(tag)
    end
end

---移除标签（按来源递减引用计数）
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source string|nil 来源标识，默认 "_explicit"
function M.remove(container, tag, source)
    source = source or "_explicit"
    local name = tostring(tag)
    local counts = container.counts[name]
    if not counts then
        return
    end
    counts[source] = (counts[source] or 0) - 1
    if counts[source] <= 0 then
        counts[source] = nil
    end
    if not next(counts) then
        container.tags[name] = nil
        container.counts[name] = nil
    end
end

---判断是否包含指定标签（支持父级匹配）
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@return boolean
function M.has(container, tag)
    local query = M.GameplayTag.new(tag)
    for _, stored in pairs(container.tags) do
        if M.matches(stored, query) then
            return true
        end
    end
    return false
end

---判断是否包含任意一个标签
---@param container mini_gas.GameplayTagContainer
---@param tags mini_gas.TagId[]
---@return boolean
function M.has_any(container, tags)
    for _, tag in ipairs(tags or {}) do
        if M.has(container, tag) then
            return true
        end
    end
    return false
end

---判断是否包含所有标签
---@param container mini_gas.GameplayTagContainer
---@param tags mini_gas.TagId[]
---@return boolean
function M.has_all(container, tags)
    for _, tag in ipairs(tags or {}) do
        if not M.has(container, tag) then
            return false
        end
    end
    return true
end

return M
