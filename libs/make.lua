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

  libs/make.lua
  lua-router
  Created by Masatoshi Teruya on 14/08/16.
 
--]]
-- modules
local util = require('util');
local typeof = util.typeof;
local eval = util.eval;
local path = require('path');
-- constants
local HANDLER_NAME = require('router.constants').HANDLER_NAME;
local M_AUTH = {
    authn   = 'authn',
    authz   = 'authz',
};
local M_AUTH_LIST = table.concat( util.table.keys( M_AUTH ), '|' );
local M_FILTER = {
    any     = '*',
    head    = 'HEAD',
    options = 'OPTIONS',
    get     = 'GET',
    post    = 'POST',
    put     = 'PUT',
    delete  = 'DELETE'
};
local M_FILTER_LIST = table.concat( util.table.keys( M_FILTER ), '|' );
local M_FILE = {
    head    = 'HEAD',
    options = 'OPTIONS',
    get     = 'GET',
    post    = 'POST',
    put     = 'PUT',
    delete  = 'DELETE'
};
local M_FILE_LIST = table.concat( util.table.keys( M_FILE ), '|' );
-- hook mechanism
local REGISTRY = {};
local DELEGATE = setmetatable({},{
    __newindex = function( _, method, fn )
        if not REGISTRY.M_TABLE[typeof.string( method ) and method or ''] then
            error( ('method name must be %s:<%s>'):format( HANDLER_NAME, REGISTRY.M_LIST ), 2 );
        elseif not typeof.Function( fn ) then
            error( 'method must be type of function', 2 );
        elseif REGISTRY.M_INDEX[method] then
            error( ('method %s already defined'):format( method ), 2 );
        end
        REGISTRY.M_INDEX[REGISTRY.M_TABLE[method]] = fn;
    end
});

local function setAuthRegistry( index )
    REGISTRY = {
        M_TABLE = M_AUTH,
        M_LIST  = M_AUTH_LIST,
        M_INDEX = index
    };
end

local function setFilterRegistry( index )
    REGISTRY = {
        M_TABLE = M_FILTER,
        M_LIST  = M_FILTER_LIST,
        M_INDEX = index
    };
end

local function setFileRegistry( index )
    REGISTRY = {
        M_TABLE = M_FILE,
        M_LIST  = M_FILE_LIST,
        M_INDEX = index
    };
end


local function make( src, env, pathname )
    local fn, err = eval( src, env, pathname );
    
    if not err then
        local co = coroutine.create( fn );
        
        err = select( 2, coroutine.resume( co ) );
        if not err and coroutine.status( co ) == 'suspended' then
            err = 'cannot suspend main';
        end
    end
    
    return err;
end


local function compile( fs, setRegistry, env, pathname )
    local src, err = fs:read( pathname );
    
    if not err then
        local handler = {};
        
        setRegistry( handler );
        rawset( env, HANDLER_NAME, DELEGATE );
        err = make( src, env, pathname );
        rawset( env, HANDLER_NAME, nil );
        if err then
            return nil, err;
        -- set wildcard handler to all empty method
        elseif handler['*'] then
            for _, method in pairs( REGISTRY.M_TABLE ) do
                if not handler[method] then
                    handler[method] = handler['*'];
                end
            end
            handler['*'] = nil;
        end
        
        return handler;
    end
    
    return nil, err; 
end


-- class
local halo = require('halo');
local Make = halo.class.Make;

function Make:init( fs, sandbox )
    assert( halo.instanceof( fs, require('router.fs') ),
        'fs must be instance of router.fs'
    );
    self.fs = fs;
    
    if sandbox ~= nil then
        assert( typeof.table( sandbox ), 'sandbox must be type of table' );
        self.sandbox = sandbox;
    else
        self.sandbox = _G;
    end
    
    return self;
end

function Make:asAuthHandler( rpath )
    return compile( self.fs, setAuthRegistry, self.sandbox, rpath );
end

function Make:asFilterHandler( rpath )
    return compile( self.fs, setFilterRegistry, self.sandbox, rpath );
end

function Make:asFileHandler( rpath )
    return compile( self.fs, setFileRegistry, self.sandbox, rpath );
end

return Make.exports;
