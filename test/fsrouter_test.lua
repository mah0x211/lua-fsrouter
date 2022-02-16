require('luacov')
local testcase = require('testcase')
local fsrouter = require('fsrouter')
local dump = require('dump')

local function contains(act, exp)
    local at = type(act)
    local et = type(exp)

    if at ~= et then
        return false
    elseif at ~= 'table' then
        return act == exp
    end

    for k, v in pairs(exp) do
        if not contains(v, act[k]) then
            return false
        end
    end

    return true
end

function testcase.new()
    -- create router
    local r = assert(fsrouter.new('./valid'))
    for _, v in ipairs({
        {
            pathname = '/',
            glob = {},
            file = {
                rpath = '/index.html',
            },
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/@index.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
            },
        },
        {
            pathname = '/settings',
            glob = {},
            file = {
                rpath = '/settings.html',
            },
            methods = {
                any = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/@settings.lua',
                        type = 'handler',
                        method = 'any',
                    },
                },
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/@settings.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
                post = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/@settings.lua',
                        type = 'handler',
                        method = 'post',
                    },
                },
            },
        },
        {
            pathname = '/api',
            glob = {},
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/api/@index.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
            },
        },
        {
            pathname = '/signin',
            glob = {},
            methods = {
                get = {
                    {
                        name = '/signin/@index.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
                post = {
                    {
                        name = '/signin/@index.lua',
                        type = 'handler',
                        method = 'post',
                    },
                },
            },
        },
        {
            pathname = '/favicon.ico',
            glob = {},
            file = {
                rpath = '/favicon.ico',
                mime = 'image/x-icon',
            },
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                },
            },
        },
        {
            pathname = '/img/example.jpg',
            glob = {},
            file = {
                rpath = '/img/example.jpg',
                mime = 'image/jpeg',
            },
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                },
            },
        },
        {
            pathname = '/uname',
            glob = {
                user = 'uname',
            },
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/#1.block_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/@index.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
            },
        },
        {
            pathname = '/uname/profile',
            glob = {
                user = 'uname',
            },
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/#1.block_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/@profile.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
            },
        },
        {
            pathname = '/uname/posts',
            glob = {
                user = 'uname',
            },
            methods = {
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/#1.block_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/posts/#1.extract_id.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/posts/@index.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
            },
        },
        {
            pathname = '/uname/posts/post-id/hello-world',
            glob = {
                user = 'uname',
                id = 'post-id/hello-world',
            },
            methods = {
                any = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/#1.block_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/posts/#1.extract_id.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/posts/@*id.lua',
                        type = 'handler',
                        method = 'any',
                    },
                },
                get = {
                    {
                        name = '/#1.block_ip.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/#2.check_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/#1.block_user.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/posts/#1.extract_id.lua',
                        type = 'filter',
                        method = 'all',
                    },
                    {
                        name = '/$user/posts/@*id.lua',
                        type = 'handler',
                        method = 'get',
                    },
                },
            },
        },
    }) do
        local val, err, glob = r:lookup(v.pathname)
        assert(not err, err)
        assert.equal(glob, v.glob)
        if v.file and not contains(val.file, v.file) then
            error(string.format('%s is not contains %s', dump(val.file),
                                dump(v.file)))
        end
        if not contains(val.methods, v.methods) then
            error(string.format('%s is not contains %s', dump(val.methods),
                                dump(v.methods)))
        end
    end
end

function testcase.filter_invalid()
    -- test that script file compilation failure
    local r, err = fsrouter.new('./filter_invalid')
    assert.is_nil(r)
    assert.match(err, 'invalid filter file .+ failed to compile', false)
end

function testcase.filter_method_already_defined()
    -- test that method already defined
    local r, err = fsrouter.new('./filter_method_already_defined')
    assert.is_nil(r)
    assert.match(err, 'invalid filter file .+ method "get" already defined',
                 false)
end

function testcase.filter_method_must_be_function()
    -- test that method 'all' cannot be used in filter file
    local r, err = fsrouter.new('./filter_method_must_be_function')
    assert.is_nil(r)
    assert.match(err, 'invalid filter file .+ method must be function', false)
end

function testcase.filter_method_true_is_not_supported()
    -- test that method 'true' is not supported
    local r, err = fsrouter.new('./filter_method_true_is_not_supported')
    assert.is_nil(r)
    assert.match(err, 'invalid filter file .+ method "true" is not supported',
                 false)
end

function testcase.filter_order_duplicated()
    -- test that filter order is duplicated
    local r, err = fsrouter.new('./filter_order_duplicated')
    assert.is_nil(r)
    assert.match(err, 'the order #1 is already used')
end

function testcase.filter_order_invalid()
    -- test that invalid filter order
    local r, err = fsrouter.new('./filter_order_invalid')
    assert.is_nil(r)
    assert.match(err, 'the filename prefix must begin with')
end

function testcase.handler_invalid()
    -- test that script file compilation failure
    local r, err = fsrouter.new('./handler_invalid')
    assert.is_nil(r)
    assert.match(err, 'invalid handler file .+ failed to compile', false)
end

function testcase.handler_method_all_cannot_be_used()
    -- test that method 'all' cannot be used in handler file
    local r, err = fsrouter.new('./handler_method_all_cannot_be_used')
    assert.is_nil(r)
    assert.match(err, 'method "all" cannot be used')
end

function testcase.handler_method_already_defined()
    -- test that method already defined
    local r, err = fsrouter.new('./handler_method_already_defined')
    assert.is_nil(r)
    assert.match(err, 'method "get" already defined')
end

function testcase.handler_method_must_be_function()
    -- test that method 'all' cannot be used in handler file
    local r, err = fsrouter.new('./handler_method_must_be_function')
    assert.is_nil(r)
    assert.match(err, 'method must be function')
end

function testcase.handler_method_true_is_not_supported()
    -- test that method 'true' is not supported
    local r, err = fsrouter.new('./handler_method_true_is_not_supported')
    assert.is_nil(r)
    assert.match(err, 'method "true" is not supported')
end

function testcase.route_index_already_exists()
    -- test that handler route is duplicated
    local r, err = fsrouter.new('./route_index_already_exists')
    assert.is_nil(r)
    assert.match(err, 'route "index" already exists')
end

