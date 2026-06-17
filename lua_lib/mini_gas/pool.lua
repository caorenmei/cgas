--- MiniGas V2 内部对象池
--- 仅保留两种池：
---   - table_pool：复用键值型临时表，回收时遍历 pairs 清空
---   - array_pool：复用纯数组型临时表，回收时按 t.n 逐个置 false

local M = {}

--- 键值型表对象池
local table_pool = {}

--- 数组型表对象池
local array_pool = {}

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

--- 从 array_pool 获取一张已清空的数组表
---@return table
function M.acquire_array()
    local t = table.remove(array_pool)
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

--- 归还 array_pool
--- 按 t.n 将数组元素置 false，并将 t.n 设为 0
---@param t table
function M.release_array(t)
    if not t or t.__in_pool then
        return
    end
    local n = t.n or 0
    for i = 1, n do
        t[i] = false
    end
    t.n = 0
    t.__in_pool = true
    table.insert(array_pool, t)
end

return M
