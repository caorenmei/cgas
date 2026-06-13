--- Object handle registry with weak-value storage.
--- Provides monotonically increasing integer handles and a weak table mapping
--- handles to instances. This allows GC collection of registered objects when
--- no other references exist.

local M = {}

-- Monotonically increasing handle counter
local _counter = 0

-- Weak-value registry: handle -> instance
local _registry = setmetatable({}, { __mode = "v" })

--- Generate the next unique handle.
---@return integer handle
function M.next_handle()
    _counter = _counter + 1
    return _counter
end

--- Register an instance under a handle.
---@param handle integer
---@param instance table
function M.register(handle, instance)
    _registry[handle] = instance
end

--- Retrieve an instance by handle.
---@param handle integer
---@return table|nil instance
function M.get(handle)
    return _registry[handle]
end

--- Unregister a handle.
---@param handle integer
function M.unregister(handle)
    _registry[handle] = nil
end

return M
