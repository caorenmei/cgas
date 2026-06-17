--- MiniGas V2 内部对象池
--- 分类复用 evaluate 过程中的临时表，降低 GC 压力

local M = {}

--- 通用表对象池，用于复用 evaluate 内部的小型临时表
local table_pool = {}

--- 分类对象池
local tags_pool = {}
local attrs_pool = {}
local evaluate_args_pool = {}
local active_abilities_pool = {}

--- 从指定对象池获取一张已清空的表
---@param pool table
---@return table
local function acquire_from(pool)
    local t = table.remove(pool)
    if t then
        t.__in_pool = nil
        for k, _ in pairs(t) do
            t[k] = nil
        end
    else
        t = {}
    end
    return t
end

--- 将表清空并归还指定对象池，带有重复释放保护
---@param pool table
---@param t table
local function release_to(pool, t)
    if not t or t.__in_pool then
        return
    end
    for k, _ in pairs(t) do
        t[k] = nil
    end
    t.__in_pool = true
    table.insert(pool, t)
end

--- 从通用对象池获取一张已清空的表
---@return table
function M.acquire_table()
    return acquire_from(table_pool)
end

--- 将表清空并归还通用对象池
---@param t table
function M.release_table(t)
    release_to(table_pool, t)
end

--- 从 tags 对象池获取一张已清空的表
---@return table<mini_gas.Tag, boolean>
function M.acquire_tags()
    return acquire_from(tags_pool)
end

--- 将表归还 tags 对象池
---@param t table
function M.release_tags(t)
    release_to(tags_pool, t)
end

--- 从 attrs 对象池获取一张已清空的表
---@return table
function M.acquire_attrs()
    return acquire_from(attrs_pool)
end

--- 将表归还 attrs 对象池
---@param t table
function M.release_attrs(t)
    release_to(attrs_pool, t)
end

--- 从 evaluate_args 对象池获取一张已清空的表
---@return table
function M.acquire_evaluate_args()
    return acquire_from(evaluate_args_pool)
end

--- 将表归还 evaluate_args 对象池
---@param t table
function M.release_evaluate_args(t)
    release_to(evaluate_args_pool, t)
end

--- 从 active_abilities 对象池获取一张已清空的表
---@return table
function M.acquire_active_abilities()
    return acquire_from(active_abilities_pool)
end

--- 将表归还 active_abilities 对象池
---@param t table
function M.release_active_abilities(t)
    release_to(active_abilities_pool, t)
end

return M
