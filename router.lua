--[[

  Copyright (C) 2013 Masatoshi Teruya
 
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

--]]

local halo = require('halo');
local strerror = require('process').strerror;
local usher = require('usher');
local path = require('path');
local lfs = require('lfs');
local util = require('util');
local typeof = util.typeof;
local eval = util.eval;
-- init for libmagic
local magic;
do
    local mgc = require('magic');
    magic = mgc.open( mgc.MIME_ENCODING, mgc.NO_CHECK_COMPRESS, mgc.SYMLINK );
    magic:load();
end
local MIME_TYPES = require('router.mime');
local CONSTANTS = require('router.constants');
local DEFAULTS = {
    rootpath = 'public',
    sandbox = _G,
    followSymlinks = false,
    index = 'index.htm'
};
local Router = halo.class.Router;

function Router:init( cfg )
    local route, err = usher.new('/@/');
    local errno, stat;
    local k, v, t, arg;
    
    assert( err == nil, err );
    rawset( self, 'route', route );
    
    -- check config table
    if not cfg then
        cfg = {};
    else
        assert( typeof.table( cfg ), 'cfg must be type of table' );
    end
    
    -- set default values
    for k,v in pairs( DEFAULTS ) do
        arg = rawget( cfg, k );
        if arg then
            t = type( v );
            assert( 
                t == type( arg ), 
                ('cfg.%s must be type of %s'):format( k, t ) 
            );
            v = arg;
        end
        
        -- check path existence
        if k == 'rootpath' then
            arg, errno = path.exists( v );
            assert(
                arg, 
                ('cfg.%s = %q: %q'):format( k, v, strerror( errno ) ) 
            );
            stat = path.stat( v );
            assert( 
                path.isDir( stat.mode ), 
                ('cfg.%s: %q is not directory'):format( k, v ) 
            );
            v = arg;
        elseif k == 'index' then
            v = {
                [v] = true,
                ['@'..v] = true
            };
        end
        
        rawset( self, k, v );
    end
    
    return self;
end


function Router:getPathStat( pathname )
    local fullpath = path.normalize( rawget( self, 'rootpath' ), pathname );
    local stat, err = path.stat( fullpath );
    local info, pathtype;
    
    if err then
        err = strerror(err);
    else
        local _, check;
        
        for _, check in ipairs({ 
            'Reg', 'Dir', 'Chr', 'Blk', 'Fifo', 'Lnk', 'Sock' 
        }) do
            if path['is' .. check]( stat.mode ) then
                pathtype = check:lower();
                break;
            end
        end
        
        -- regular file
        if pathtype == 'reg' then
            local basename = path.basename( fullpath );
            local ext = path.extname( basename );
            local charset = magic:file( fullpath );
            
            info = {
                path = pathname,
                basename = basename,
                ext = ext,
                mime = MIME_TYPES[ext],
                charset = charset,
                ctime = stat.ctime,
                mtime = stat.mtime,
                size = stat.size
            };
        else
            info = {
                path = pathname,
                ctime = stat.ctime,
                mtime = stat.mtime,
                size = stat.size
            };
        end
    end
    
    return info, pathtype, err;
end


local function checkField( tblName, tbl, fields, asa )
    local name;
    
    for name in pairs( fields ) do
        assert(
            tbl[name] == nil or typeof[asa]( tbl[name] ) == true,
            ('%s.%s must be type of %s'):format( tblName, name, asa:lower() )
        );
    end
end

function Router:set( pathname, ctx )
    local methods, name, basename, err;
    
    -- check type
    assert( typeof.string( pathname ), 'pathname must be type of string' );
    assert( typeof.table( ctx ), 'ctx must be type of table' );
    assert(
        ctx.methods == nil or typeof.table( ctx.methods ) == true,
        'ctx.methods must be type of table'
    );
    -- check authn/authz field
    checkField( 'ctx', ctx, CONSTANTS.AUTHNZ, 'Function' );
    -- check methods table
    checkField( 'ctx.methods', ctx.methods, CONSTANTS.M_UPPER, 'Function' );
    
    basename = path.basename( pathname );
    err = self.route:set( pathname, ctx );
    if err then
        error( path .. ': ' .. err );
    elseif self.index[basename] then
        err = self.route:set( pathname:sub( 1, #pathname - #basename ), ctx );
        if err then
            error( pathname .. ': ' .. err );
        end
    end
end


local function compile( fullpath, env )
    local fh, err = io.open( fullpath );
    local src, fn, co, ok;
    
    if fh then
        src, err = fh:read('*a');
        fh:close();
        if not err then
            fn, err = eval( src, env );
            if not err then
                co = coroutine.create( fn );
                ok, err = coroutine.resume( co );
                if ok and coroutine.status( co ) == 'suspended' then
                    err = 'do not suspend main function';
                end
            end
        end
    end
    
    return err;
end


local function traverse( self, dirpath, authnz, rootpath, followSymlinks )
    local files = {};
    local dirs = {};
    local methods = {};
    local entry, pathname, info, pathtype, err, imp, symbol;
    local delegate = setmetatable({},{
        __newindex = function( _, method, fn )
            assert(
                typeof.string( method ),
                ('%s method must be type of string'):format( symbol )
            );
            assert(
                CONSTANTS.M_LOWER[method] or CONSTANTS.AUTHNZ[method],
                ('Invalid %s method: %q'):format( symbol, method )
            );
            assert(
                typeof.Function( fn ), 
                ('%s.%s must be type of function'):format( symbol, method )
            );
            if CONSTANTS.M_LOWER[method] then
                local methodName = CONSTANTS.M_LOWER[method];
                -- has already
                assert(
                    methods[methodName] == nil,
                    ('%s.%s already defined'):format( symbol, method )
                );
                methods[methodName] = fn;
            else
                authnz[method] = fn;
            end
        end
    });
    
    -- list up
    for entry in lfs.dir( path.normalize( rootpath, dirpath ) ) do
        -- ignore dot-files
        if not entry:find( '^[.]' ) then
            pathname = path.normalize( dirpath, '/', entry );
            info, pathtype, err = self:getPathStat( pathname, followSymlinks );
            assert( err == nil, err );
            
            if pathtype == 'dir' then
                dirs[entry] = info;
            elseif pathtype == 'reg' then
                if CONSTANTS.SYMBOL[entry] then
                    symbol = CONSTANTS.SYMBOL[entry];
                    imp = info;
                else
                    files[entry] = info;
                end
            -- invalid file
            else
                print( ('%q is not regular file entry'):format( pathname ) );
            end
        end
    end
    
    -- check imp
    if imp then
        -- method handler entry
        self.sandbox[symbol] = delegate;
        err = compile( path.normalize( rootpath, imp.path ), self.sandbox );
        self.sandbox[symbol] = nil;
        assert( err == nil, err );
    end
    
    -- check entry
    for entry, info in pairs( files ) do
        info.methods = methods;
        info.authn = authnz.authn;
        info.authz = authnz.authz;
        self:set( info.path, info );
    end
    
    -- traverse dir
    authnz = util.table.copy( authnz );
    for entry, info in pairs( dirs ) do
        traverse( self, info.path, authnz, rootpath, followSymlinks );
    end
end


function Router:readdir()
    traverse( self, '/', {}, self.rootpath, self.followSymlinks );
end


function Router:lookup( uri )
    return self.route:exec( uri );
end


return Router.exports;

