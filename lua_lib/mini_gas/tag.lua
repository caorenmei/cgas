--- MiniGas V2 层级标签匹配工具

local M = {}

--- 层级标签匹配：精确匹配，或 a 是 b 的子级（如 state.dead 匹配 state）
---@param a mini_gas.Tag
---@param b mini_gas.Tag
---@return boolean
function M.match_tag(a, b)
    if a == b then
        return true
    end
    if b == "" then
        return false
    end
    return #a > #b and a:find(b, 1, true) == 1 and a:byte(#b + 1) == 46
end

--- 判断实体是否拥有与给定标签模式匹配的标签
---@param entity mini_gas.IEntityState
---@param module mini_gas.IEntityModule
---@param pattern mini_gas.Tag
---@return boolean
function M.entity_match_tag(entity, module, pattern)
    if module.has_static_tag(entity, pattern) then
        return true
    end
    for tag in module.static_tags(entity) do
        if M.match_tag(tag, pattern) then
            return true
        end
    end
    return false
end

--- 判断实体是否满足 allof / anyof / noneof 标签约束
---@param entity mini_gas.IEntityState
---@param module mini_gas.IEntityModule
---@param allof_tags? mini_gas.Tag[]
---@param anyof_tags? mini_gas.Tag[]
---@param noneof_tags? mini_gas.Tag[]
---@return boolean
function M.match_tags(entity, module, allof_tags, anyof_tags, noneof_tags)
    if allof_tags and #allof_tags > 0 then
        for _, pattern in ipairs(allof_tags) do
            if not M.entity_match_tag(entity, module, pattern) then
                return false
            end
        end
    end
    if anyof_tags and #anyof_tags > 0 then
        local any_match = false
        for _, pattern in ipairs(anyof_tags) do
            if M.entity_match_tag(entity, module, pattern) then
                any_match = true
                break
            end
        end
        if not any_match then
            return false
        end
    end
    if noneof_tags and #noneof_tags > 0 then
        for _, pattern in ipairs(noneof_tags) do
            if M.entity_match_tag(entity, module, pattern) then
                return false
            end
        end
    end
    return true
end

return M
