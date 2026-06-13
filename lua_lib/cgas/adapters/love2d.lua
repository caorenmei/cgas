local M = {}

---@param asc cgas.semantics.ASC
---@return fun(dt: number)
function M.update(asc)
    return function(dt)
        asc:update(dt)
    end
end

return M
