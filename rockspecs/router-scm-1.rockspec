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
    "lrexlib-oniguruma >= 2.7.2",
    "process >= 1.0",
    "magic >= 1.0",
    "ddl >= 1.0",
    "usher",
}
build = {
    type = "builtin",
    modules = {
        router = "router.lua",
        ["router.mime"] = "libs/mime.lua",
        ["router.constants"] = "libs/constants.lua",
        ["router.fs"] = "libs/fs.lua",
        ["router.ddl.helper"] = "ddl/helper.lua",
        ["router.ddl.access"] = "ddl/access.lua",
        ["router.ddl.filter"] = "ddl/filter.lua",
        ["router.ddl.content"] = "ddl/content.lua"
    }
}
