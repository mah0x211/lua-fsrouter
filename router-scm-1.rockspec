package = "router"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-router.git"
}
description = {
    summary = "url router",
    homepage = "https://github.com/mah0x211/lua-router",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo",
    "util",
    "path",
    "process",
    "usher",
    "magic",
    "lrexlib-oniguruma >= 2.7.2"
}
build = {
    type = "builtin",
    modules = {
        router = "router.lua",
        ["router.mime"] = "libs/mime.lua",
        ["router.constants"] = "libs/constants.lua",
        ["router.fs"] = "libs/fs.lua",
        ["router.make"] = "libs/make.lua"
    }
}
