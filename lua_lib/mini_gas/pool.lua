--- MiniGas V2 内部对象池
--- 保留一个键值表池与两个数组池：
---   - table_pool：复用键值型临时表，回收时遍历 pairs 清空
---   - short_array_pool：复用短数组型临时表，回收时按 t.n 逐个置 false
---   - long_array_pool：复用长数组型临时表，语义与 short_array_pool 相同，
---     专用于生命周期跨越整个求值流程、元素较多的数组（如 active_abilities）

local M = {}

--- 键值型表对象池
local table_pool = {}

--- 短数组型表对象池
local short_array_pool = {}

--- 长数组型表对象池
local long_array_pool = {}

--- 从对象池获取一张已清空的表
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

--- 从 table_pool 获取一张已清空的表
---@return table
function M.acquire_table()
    return acquire_from(table_pool)
end

--- 归还 table_pool
--- 使用 pairs 遍历，将所有键值置 nil
---@param t table
function M.release_table(t)
    if not t or t.__in_pool then
        return
    end
    for k, _ in pairs(t) do
        t[k] = nil
    end
    t.__in_pool = true
    table.insert(table_pool, t)
end

--- 从指定数组池获取一张已清空的数组表
---@param pool table
---@return table
local function acquire_array_from(pool)
    local t = table.remove(pool)
    if t then
        t.__in_pool = nil
        local n = t.n or 0
        for i = 1, n do
            t[i] = false
        end
        t.n = 0
    else
        t = { n = 0 }
    end
    return t
end

--- 归还指定数组池
--- 按 t.n 将数组元素置 false，并将 t.n 设为 0
---@param pool table
---@param t table
local function release_array_to(pool, t)
    if not t or t.__in_pool then
        return
    end
    local n = t.n or 0
    for i = 1, n do
        t[i] = false
    end
    t.n = 0
    t.__in_pool = true
    table.insert(pool, t)
end

--- 从 short_array_pool 获取一张已清空的短数组表
---@return table
function M.acquire_short_array()
    return acquire_array_from(short_array_pool)
end

--- 归还 short_array_pool
---@param t table
function M.release_short_array(t)
    release_array_to(short_array_pool, t)
end

--- 从 long_array_pool 获取一张已清空的长数组表
---@return table
function M.acquire_long_array()
    return acquire_array_from(long_array_pool)
end

--- 归还 long_array_pool
---@param t table
function M.release_long_array(t)
    release_array_to(long_array_pool, t)
end

return M
