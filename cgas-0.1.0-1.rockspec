package = "cgas"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/example/cgas.git", -- placeholder
}
description = {
    summary = "Lua GAS (Gameplay Ability System) library",
    detailed = "A Lua implementation of Gameplay Ability System inspired by Unreal Engine's GAS.",
    homepage = "https://github.com/example/cgas", -- placeholder
    license = "MIT",
}
dependencies = {
    "lua >= 5.4",
}
test_dependencies = {
    "busted >= 2.0",
}
build = {
    type = "builtin",
    modules = {
        ["cgas"] = "lua_lib/cgas/init.lua",
        ["cgas.core.object"] = "lua_lib/cgas/core/object.lua",
        ["cgas.core.event"] = "lua_lib/cgas/core/event.lua",
        ["cgas.core.scheduler"] = "lua_lib/cgas/core/scheduler.lua",
        ["cgas.core.timer"] = "lua_lib/cgas/core/timer.lua",
        ["cgas.core.registry"] = "lua_lib/cgas/core/registry.lua",
        ["cgas.semantics.asc"] = "lua_lib/cgas/semantics/asc.lua",
        ["cgas.semantics.ability"] = "lua_lib/cgas/semantics/ability.lua",
        ["cgas.semantics.attribute"] = "lua_lib/cgas/semantics/attribute.lua",
        ["cgas.semantics.effect"] = "lua_lib/cgas/semantics/effect.lua",
        ["cgas.semantics.tag"] = "lua_lib/cgas/semantics/tag.lua",
        ["cgas.semantics.cue"] = "lua_lib/cgas/semantics/cue.lua",
        ["cgas.semantics.task"] = "lua_lib/cgas/semantics/task.lua",
        ["cgas.adapters.manual"] = "lua_lib/cgas/adapters/manual.lua",
        ["cgas.adapters.love2d"] = "lua_lib/cgas/adapters/love2d.lua",
        ["cgas.net.context"] = "lua_lib/cgas/net/context.lua",
        ["cgas.net.prediction"] = "lua_lib/cgas/net/prediction.lua",
        ["cgas.net.event"] = "lua_lib/cgas/net/event.lua",
    },
}
