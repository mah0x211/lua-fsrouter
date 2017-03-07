package = "fsrouter"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-fsrouter.git"
}
description = {
    summary = "filesystem based url router",
    homepage = "https://github.com/mah0x211/lua-fsrouter",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "rootdir >= 1.0.5",
    "vardir >= 0.1.0"
}
build = {
    type = "builtin",
    modules = {
        fsrouter = "fsrouter.lua"
    }
}
