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

-- modules
local usher = require('usher');
local util = require('util');
local typeof = util.typeof;
local FS = require('router.fs');
local AccessDDL = require('router.ddl.access');
local FilterDDL = require('router.ddl.filter');
local ContentDDL = require('router.ddl.content');
-- constants
local DEFAULT = {
    docroot = 'html',
    followSymlink = false,
    index = 'index.htm',
    sandbox = _G
};
-- class
local Router = require('halo').class.Router;

function Router:init( cfg )
    if not cfg then
        cfg = DEFAULT;
    else
        assert( typeof.table( cfg ), 'cfg must be type of table' );
        -- create index table
        if cfg.index then
            assert(
                typeof.string( cfg.index ),
                'cfg.index must be type of string'
            );
            assert(
                not cfg.index:find( '/', 1, true ),
                'cfg.index should not include path-delimiter'
            );
        else
            cfg.index = DEFAULT.index;
        end
    end
    
    -- create index table
    self.index = {
        [cfg.index] = true,
        ['@'..cfg.index] = true
    };
    -- create fs
    self.fs = FS.new( cfg.docroot, cfg.followSymlinks, cfg.ignore );
    -- create ddl
    self.ddl = {
        access = AccessDDL.new(),
        filter = FilterDDL.new( cfg.sandbox ),
        content = ContentDDL.new( cfg.sandbox )
    };
    -- create usher
    self.route = assert( usher.new('/@/') );
    
    return self;
end


local function parsedir( self, dir, access, filter )
    local entries, err = self.fs:readdir( dir );
    local basenameHandler = {};
    local handler, scripts, basename, tbl;

    if err then
        return err;
    end

    -- check $access.lua
    if entries.access then
        access, err = self.ddl.access( 
            self.fs:realpath( entries.access.rpath ), false, access 
        );
        if err then
            return err;
        end
    end
    -- check $filter.lua
    if entries.filter then
        filter, err = self.ddl.filter(
            self.fs:realpath( entries.filter.rpath ), false, filter 
        );
        if err then
            return err;
        end
    end

    -- check entry
    scripts = entries.scripts;
    for entry, stat in pairs( entries.files ) do
        -- add access handler
        stat.access = access;
        
        -- make basename handler
        basename = entry:match('^[^.]+');
        if scripts[basename] then
            tbl = basenameHandler[basename];
            -- not yet compile
            if not tbl then
                tbl, err = self.ddl.content(
                    self.fs:realpath( scripts[basename].rpath ), false 
                );
                if err then
                    return err;
                else
                    basenameHandler[basename] = tbl;
                end
            end
            
            -- set basename handler
            stat.handler = util.table.copy( tbl );
        end
        
        -- make file handler
        if scripts[entry] then
            tbl, err = self.ddl.content(
                self.fs:realpath( scripts[entry].rpath ), false 
            );
            if err then
                return err;
            -- assign handler table
            elseif not stat.handler then
                stat.handler = tbl;
            -- merge handler
            else
                for k, v in pairs( tbl ) do
                    stat.handler[k] = v;
                end
            end
        end
        
        -- merge filter handler with file handler
        if stat.handler then
            tbl = stat.handler;
            stat.handler = util.table.clone( filter or {} );
            for method, fn in pairs( tbl ) do
                tbl = stat.handler[method];
                if not tbl then
                    tbl = { fn };
                    stat.handler[method] = tbl;
                else
                    tbl[#tbl+1] = fn;
                end
            end
        else
            stat.handler = filter;
        end
        
        err = self.route:set( stat.rpath, stat );
        if err then
            return ('failed to set route %s: %s'):format( stat.rpath, err );
        -- add dirname(with trailing-slash) if entry is index file
        elseif self.index[entry] then
            entry = stat.rpath:sub( 1, #stat.rpath - #entry );
            err = self.route:set( entry, stat );
            if err then
                return ('failed to set index route %s: %s'):format( entry, err );
            end
        end
    end
    
    -- recursive call
    for _, v in pairs( entries.dirs ) do
        err = parsedir( self, v, access, filter );
        if err then
            return err;
        end
    end
end


function Router:readdir()
    return parsedir( self, '/' );
end


function Router:lookup( uri )
    return self.route:exec( uri );
end


function Router:dump()
    self.route:dump();
end

return Router.exports;

