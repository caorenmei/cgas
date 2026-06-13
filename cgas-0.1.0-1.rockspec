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
    modules = {},
}
