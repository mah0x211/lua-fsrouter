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
local path = require('path');
local url = require('url');
local lfs = require('lfs');
local util = require('util');
local typeof = util.typeof;
local eval = util.eval;
local split = util.string.split;
-- init for libmagic
local magic;
do
    local mgc = require('magic');
    magic = mgc.open( mgc.MIME_ENCODING, mgc.NO_CHECK_COMPRESS, mgc.SYMLINK );
    magic:load();
end
local MIME_TYPES = require('router.mime');
local Router = halo.class.Router;

local METHODS = {
    ['get'] = 'GET',
    ['post'] = 'POST',
    ['put'] = 'PUT',
    ['delete'] = 'DELETE'
};
local AUTHNZ = {
    ['authn'] = 'authn',
    ['authz'] = 'authz',
};
local DEFAULTS = {
    rootpath = 'public',
    sandbox = _G,
    index = 'index.htm'
};

function Router:init( cfg )
    local rootpath = rawget( cfg, 'rootpath' );
    local errno, stat;
    local k, v, t, arg;
    
    -- check config table
    if not cfg then
        cfg = {};
    else
        assert( 
            typeof.table( cfg ), 
            'cfg must be type of table' 
        );
    end
    
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
            stat = path.stat( rootpath );
            assert( 
                path.isDir( stat.mode ), 
                ('cfg.%s: %q is not directory'):format( k, v ) 
            );
            v = arg;
        end
        
        rawset( self, k, v );
    end
    
    rawset( self, 'imp', {
        ['@hook.lua'] = {
            symbol = 'Hook',
            method = METHODS
        },
        ['@auth.lua'] = {
            symbol = 'Auth',
            method = AUTHNZ
        }
    });

    return self;
end

function Router:getPathStat( pathname, followSymlinks )
    local fullpath = path.normalize( rawget( self, 'rootpath' ), pathname );
    local stat, err = path.stat( fullpath, followSymlinks );
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
                path = fullpath,
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
                path = fullpath,
                ctime = stat.ctime,
                mtime = stat.mtime,
                size = stat.size
            };
        end
    end
    
    return info, pathtype, err;
end



function Router:getPathPattern( pathname )
    local params = {};
    local idx = 0;
    
    pathname = path.normalize( pathname );
    -- convert to pattern string
    pathname = pathname:gsub( '[/]%$([^/]+)', function( param )
        idx = idx + 1;
        rawset( params, idx, param );
        return '/([^/]+)';
    end);
    
    return pathname, idx > 0 and params or nil;
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


function Router:readdir()
    local rootpath = rawget( self, 'rootpath' );
    local sandbox = rawget( self, 'sandbox' );
    local dirpath = '/';
    local route = {}
    local routes = {
        [dirpath] = route
    };
    local patternIdx = {};
    local dirs = {};
    local entry, pathname, info, pathtype, err, tbl, pattern, params, imp;
    local delegate = setmetatable({},{
        __newindex = function( _, methodName, fn )
            local method = rawget( imp.method, methodName );
            local methods = rawget( info, 'methods' );
            
            assert(
                typeof.string( methodName ), 
                ('%s method must be type of string'):format( imp.symbol )
            );
            assert( 
                method, 
                ('Invalid %s method: %q'):format( imp.symbol, methodName ) 
            );
            assert( 
                typeof.Function( fn ), 
                ('%s.%s must be type of function'):format( imp.symbol, method ) 
            );
            
            if not typeof.table( methods ) then
                methods = {};
                rawset( info, 'methods', methods );
            end
            
            rawset( methods, method, fn );
        end
    });
    
    repeat
        methods = {};
        
        for entry in lfs.dir( path.normalize( rootpath, dirpath ) ) do
            if entry ~= '@' and not entry:find( '^[.]' ) then
                pathname = path.normalize( dirpath, '/', entry );
                info, pathtype, err = self:getPathStat( pathname, false );
                assert( err == nil, err );
                
                -- save directory entry for next traversing
                if pathtype == 'dir' then
                    tbl = {};
                    -- save parameter name if parametric entry
                    if entry:find('^%$') then
                        entry = entry:match('[^$]+');
                        rawset( tbl, '@param', entry );
                        -- entry renamed to '@'
                        entry = '@';
                    end
                    
                    -- save child entry to current route table
                    rawset( route, entry, tbl );
                    -- add to loop stack
                    rawset( dirs, #dirs + 1, {
                        dirpath = pathname,
                        route = tbl
                    });
                -- check regular file
                elseif pathtype == 'reg' then
                    imp = rawget( self.imp, entry );
                    -- method handler entry
                    if imp then
                        rawset( sandbox, imp.symbol, delegate );
                        err = compile( info.path, sandbox );
                        rawset( sandbox, imp.symbol, nil );
                        assert( err == nil, err );
                        rawset( route, info.basename:match('^(@[^.]+)'), info );
                    -- non @ prefixed files
                    elseif not entry:find('^@') then
                        rawset( route, info.basename, info );
                    end
                -- invalid file
                else
                    print( ('%q is not regular file entry'):format( pathname ) );
                end
            end
        end
        
        -- get remaining directory entry
        entry = table.remove( dirs );
        if entry then
            dirpath = entry.dirpath;
            route = entry.route;
        end
    until not entry;

    rawset( self, 'route', routes );
end


local function getHandler( methodName, node, authn, authz )
    local handler = rawget( node, '@auth' );
    
    if handler then
        authn = rawget( handler.methods, 'authn' ) or authn;
        authz = rawget( handler.methods, 'authz' ) or authz;
    end
    
    handler = rawget( node, '@hook' );
    if handler then
        method = rawget( handler.methods, methodName );
    end
    
    return authn, authz, method;
end


function Router:lookup( methodName, uri )
    local node = rawget( self.route, '/' );
    local params = {};
    local i, seg, authn, authz, method;
    local attr = rawget( node, '@auth' );
    
    -- check authn/authz handler
    if attr then
        authn = rawget( attr.methods, 'authn' ) or authn;
        authz = rawget( attr.methods, 'authz' ) or authz;
    end
    
    uri = split( path.normalize( uri ), '/' );
    for i = 1, #uri do
        -- check segment node
        seg = rawget( uri, i );
        node = rawget( node, seg ) or rawget( node, '@' );
        if not node then
            break;
        end
        
        -- check param
        attr = rawget( node, '@param' );
        if attr then
            rawset( params, attr, seg );
        end
        -- check authn/authz handler
        attr = rawget( node, '@auth' );
        if attr then
            authn = rawget( attr.methods, 'authn' ) or authn;
            authz = rawget( attr.methods, 'authz' ) or authz;
        end
    end
    
    -- check method handler
    if node then
        attr = rawget( node, '@hook' );
        if attr then
            method = rawget( attr.methods, methodName );
        end
        -- check index
        if not rawget( node, 'ext' ) then
            node = rawget( node, rawget( self, 'index' ) );
        end
    end
    
    return node and {
        index = node,
        params = params,
        authn = authn,
        authz = authz,
        method = method
    };
end


return Router.exports;

