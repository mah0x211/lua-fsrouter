--[[

  Copyright (C) 2014 Masatoshi Teruya
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

  lib/make.lua
  lua-router
  Created by Masatoshi Teruya on 14/08/16.
 
--]]

local util = require('util');
local typeof = util.typeof;
local eval = util.eval;
-- constants
local HANDLER_NAME = 'Handle';
-- method names
local M_AUTH = {
    authn   = 'authn',
    authz   = 'authz',
};
local M_AUTH_LIST = table.concat({
    'authn', 'authz'
}, ' or ' );
local M_METHOD = {
    head    = 'head',
    options = 'options',
    get     = 'get',
    post    = 'post',
    put     = 'put',
    delete  = 'delete'
};
local M_METHOD_LIST = table.concat({
    'head', 'options', 'get', 'post', 'put', 'delete'
}, ' or ' );
local REGISTRY = {};


local function setAuthRegistry( index )
    REGISTRY = {
        M_TABLE = M_AUTH,
        M_LIST  = M_AUTH_LIST,
        M_INDEX = index
    };
end

local function setMethodRegistry( index )
    REGISTRY = {
        M_TABLE = M_METHOD,
        M_LIST  = M_METHOD_LIST,
        M_INDEX = index
    };
end


local DELEGATE = setmetatable({},{
    __newindex = function( _, method, fn )
        if not REGISTRY.M_TABLE[typeof.string( method ) and method or ''] then
            error( ('method name must be %s'):format( REGISTRY.M_LIST ), 2 );
        elseif not typeof.Function( fn ) then
            error( 'method must be type of function', 2 );
        elseif REGISTRY.M_INDEX[method] then
            error( ('method %s already defined'):format( method ), 2 );
        end
        REGISTRY.M_INDEX[method] = fn;
    end
});


local function readFile( pathname )
    local fh, err = io.open( pathname );
    local src, fn, co, ok;
    
    if err then
        return nil, err;
    end
    
    src, err = fh:read('*a');
    fh:close();
    if err then
        return nil, err;
    end
    
    return src;
end


local function make( pathname, env )
    local src, err = readFile( pathname );
    local fn, co, ok;
    
    if err then
        return err;
    end
    
    fn, err = eval( src, env, pathname );
    if err then
        return err;
    end
    
    co = coroutine.create( fn );
    ok, err = coroutine.resume( co );
    if err then
        return err;
    elseif coroutine.status( co ) == 'suspended' then
        return 'cannot suspend Handler';
    end
end


local function makeHandler( registryFn, pathname, env )
    local handler = {};
    local err;
    
    registryFn( handler );
    rawset( env, HANDLER_NAME, DELEGATE );
    err = make( pathname, env );
    rawset( env, HANDLER_NAME, nil );
    
    if err then
        return nil, err;
    end
    
    return handler;
end


local function authHandler( pathname, env )
    return makeHandler( setAuthRegistry, pathname, env );
end


local function methodHandler( pathname, env )
    return makeHandler( setMethodRegistry, pathname, env );
end


return {
    authHandler = authHandler,
    methodHandler = methodHandler
};

