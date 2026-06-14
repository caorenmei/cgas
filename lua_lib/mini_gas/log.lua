--- 日志句柄注入模块
--- 默认使用 print，业务方可通过 set_logger 注入自定义句柄。
local M = {}

---@type { warn: fun(msg: string) }|nil
M._logger = nil

---注入日志句柄
---@param logger { warn: fun(msg: string) }|nil
function M.set_logger(logger)
    M._logger = logger
end

---记录警告
---@param msg string
function M.warn(msg)
    local logger = M._logger
    if logger and type(logger.warn) == "function" then
        logger.warn(msg)
    else
        print("[mini_gas.warn] " .. msg)
    end
end

return M
