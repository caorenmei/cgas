--- GameplayTag 系统 — 支持层级匹配的 Tag 管理

local M = {}

---@class cgas.semantics.GameplayTag
---@field tag string
local GameplayTag = {}
GameplayTag.__index = GameplayTag
M.GameplayTag = GameplayTag

---创建一个新的 GameplayTag
---@param tag string
---@return cgas.semantics.GameplayTag
function GameplayTag.new(tag)
    local self = setmetatable({}, GameplayTag)
    self.tag = tag
    return self
end

---检查当前 tag 是否包含或等于给定的 tag 字符串
---@param other string | cgas.semantics.GameplayTag
---@return boolean
function GameplayTag:has(other)
    local other_tag = type(other) == "string" and other or other.tag
    if self.tag == other_tag then
        return true
    end
    -- 检查 other_tag 是否是当前 tag 的前缀（层级关系）
    local prefix = other_tag .. "."
    return self.tag:sub(1, #prefix) == prefix
end

---@class cgas.semantics.GameplayTagContainer
---@field tags table<string, cgas.semantics.GameplayTag>
local GameplayTagContainer = {}
GameplayTagContainer.__index = GameplayTagContainer
M.GameplayTagContainer = GameplayTagContainer

---创建空容器
---@return cgas.semantics.GameplayTagContainer
function GameplayTagContainer.new()
    local self = setmetatable({}, GameplayTagContainer)
    self.tags = {}
    return self
end

---添加 tag 到容器
---@param t cgas.semantics.GameplayTag
function GameplayTagContainer:add(t)
    self.tags[t.tag] = t
end

---从容器移除 tag
---@param t cgas.semantics.GameplayTag
function GameplayTagContainer:remove(t)
    self.tags[t.tag] = nil
end

---检查容器是否包含指定 tag（精确匹配）
---@param t cgas.semantics.GameplayTag
---@return boolean
function GameplayTagContainer:has_exact(t)
    return self.tags[t.tag] ~= nil
end

---检查容器是否包含指定 tag（支持层级匹配）
---@param t cgas.semantics.GameplayTag
---@return boolean
function GameplayTagContainer:has(t)
    for tag_str, _ in pairs(self.tags) do
        local gt = GameplayTag.new(tag_str)
        if gt:has(t) or t:has(gt) then
            return true
        end
    end
    return false
end

---检查是否与另一个容器有任意匹配
---@param other cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagContainer:matches_any(other)
    for tag_str, _ in pairs(self.tags) do
        local t = GameplayTag.new(tag_str)
        if other:has(t) then
            return true
        end
    end
    return false
end

---检查是否所有 tag 都与另一个容器匹配
---@param other cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagContainer:matches_all(other)
    for tag_str, _ in pairs(self.tags) do
        local t = GameplayTag.new(tag_str)
        if not other:has(t) then
            return false
        end
    end
    return true
end

---@class cgas.semantics.GameplayTagQuery
---@field all_tags cgas.semantics.GameplayTagContainer
---@field any_tags cgas.semantics.GameplayTagContainer
---@field none_tags cgas.semantics.GameplayTagContainer
local GameplayTagQuery = {}
GameplayTagQuery.__index = GameplayTagQuery
M.GameplayTagQuery = GameplayTagQuery

---创建空查询
---@return cgas.semantics.GameplayTagQuery
function GameplayTagQuery.new()
    local self = setmetatable({}, GameplayTagQuery)
    self.all_tags = GameplayTagContainer.new()
    self.any_tags = GameplayTagContainer.new()
    self.none_tags = GameplayTagContainer.new()
    return self
end

---检查容器是否匹配此查询
---@param container cgas.semantics.GameplayTagContainer
---@return boolean
function GameplayTagQuery:matches(container)
    -- all_tags: 容器必须包含所有
    for tag_str, _ in pairs(self.all_tags.tags) do
        local t = GameplayTag.new(tag_str)
        if not container:has(t) then
            return false
        end
    end
    -- any_tags: 容器至少包含一个（如果没有 any_tags 则跳过）
    local any_count = 0
    for tag_str, _ in pairs(self.any_tags.tags) do
        any_count = any_count + 1
        local t = GameplayTag.new(tag_str)
        if container:has(t) then
            break
        end
        if next(self.any_tags.tags, tag_str) == nil then
            return false
        end
    end
    -- none_tags: 容器不能包含任何
    for tag_str, _ in pairs(self.none_tags.tags) do
        local t = GameplayTag.new(tag_str)
        if container:has(t) then
            return false
        end
    end
    return true
end

---@class cgas.semantics.GameplayTagRegistry
---@field valid_tags table<string, boolean>
local GameplayTagRegistry = {}
GameplayTagRegistry.__index = GameplayTagRegistry
M.GameplayTagRegistry = GameplayTagRegistry

---创建新注册表
---@return cgas.semantics.GameplayTagRegistry
function GameplayTagRegistry.new()
    local self = setmetatable({}, GameplayTagRegistry)
    self.valid_tags = {}
    return self
end

---注册一个 tag，自动注册所有父 tag
---@param tag_str string
function GameplayTagRegistry:register(tag_str)
    local parts = {}
    for part in tag_str:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    local current = ""
    for i, part in ipairs(parts) do
        if i > 1 then
            current = current .. "."
        end
        current = current .. part
        self.valid_tags[current] = true
    end
end

---检查 tag 是否有效
---@param tag_str string
---@return boolean
function GameplayTagRegistry:is_valid(tag_str)
    return self.valid_tags[tag_str] == true
end

return M
