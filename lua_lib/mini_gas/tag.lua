--- GameplayTagContainer
--- 标签直接使用字符串 ID，不封装 GameplayTag 对象。
local M = {}

M.GameplayTagContainer = {}

local DOT_BYTE = string.byte(".")

---判断两个标签名是否匹配（精确或层级父级）
---@param a string
---@param b string
---@return boolean
local function tag_matches(a, b)
    if a == b then
        return true
    end
    local la, lb = #a, #b
    if la < lb then
        local start_pos, end_pos = b:find(a, 1, true)
        return start_pos == 1 and end_pos == la and b:byte(la + 1) == DOT_BYTE
    elseif la > lb then
        local start_pos, end_pos = a:find(b, 1, true)
        return start_pos == 1 and end_pos == lb and a:byte(lb + 1) == DOT_BYTE
    end
    return false
end

---创建空容器
---@return mini_gas.GameplayTagContainer
function M.GameplayTagContainer.new()
    return {
        tags = {},
    }
end

---添加标签（支持按来源引用计数）
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source string|nil 来源标识，默认 "_explicit"
function M.add(container, tag, source)
    source = source or "_explicit"
    local name = tostring(tag)
    local entry = container.tags[name]
    if not entry then
        entry = {}
        container.tags[name] = entry
    end
    entry[source] = (entry[source] or 0) + 1
end

---移除标签（按来源递减引用计数）
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@param source string|nil 来源标识，默认 "_explicit"
function M.remove(container, tag, source)
    source = source or "_explicit"
    local name = tostring(tag)
    local entry = container.tags[name]
    if not entry then
        return
    end
    entry[source] = (entry[source] or 0) - 1
    if entry[source] <= 0 then
        entry[source] = nil
    end
    if not next(entry) then
        container.tags[name] = nil
    end
end

---判断是否包含指定标签（支持父级匹配）
---@param container mini_gas.GameplayTagContainer
---@param tag mini_gas.TagId
---@return boolean
function M.has(container, tag)
    local query = tostring(tag)
    for name, _ in pairs(container.tags) do
        if tag_matches(name, query) then
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

M.matches = tag_matches

return M
