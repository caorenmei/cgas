--- MiniGas V2 调试钩子辅助函数

local M = {}

--- 调用可选调试钩子
---@param debug? mini_gas.IDebug
---@param name string
---@param ... unknown
function M.call_debug(debug, name, ...)
    if not debug then
        return
    end
    local fn = debug[name]
    if fn then
        fn(...)
    end
end

--- 调用通用步骤调试钩子
---@param debug? mini_gas.IDebug
---@param context mini_gas.IContext
---@param phase string
---@param ... unknown
function M.call_step(debug, context, phase, ...)
    if debug and debug.step then
        debug.step(context, phase, ...)
    end
end

return M
