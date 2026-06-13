-- Test environment setup: configure package paths for local LuaRocks tree
-- No extra runtime dependencies introduced.

local root = debug.getinfo(1, "S").source:sub(2)
root = root:match("^(.*)[/\\]lua_tests[/\\].*$") or "."

local tree = root .. "/lua_modules"
local lua_path = tree .. "/share/lua/5.4/?.lua"
local lua_init = tree .. "/share/lua/5.4/?/init.lua"
local lua_cpath = tree .. "/lib/lua/5.4/?.so"

package.path = lua_path .. ";" .. lua_init .. ";" .. package.path
package.cpath = lua_cpath .. ";" .. package.cpath
