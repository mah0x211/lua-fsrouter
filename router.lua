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
local Make = require('router.make');
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
    
    self.index = {
        [cfg.index] = true,
        ['@'..cfg.index] = true
    };
    
    -- create fs
    self.fs = FS.new( cfg.docroot, cfg.followSymlinks );
    -- create make
    self.make = Make.new( self.fs, cfg.sandbox );
    -- create usher
    self.route, err = usher.new('/@/');
    assert( not err, err );
    
    return self;
end


function Router:readdir()
    local authHandler = {};
    local dirs = {};
    local dir = '/';
    local entries, err, handler, filesLua, entry, stat, v, _;
    
    while dir do
        entries, err = self.fs:readdir( dir );

        if err then
            return err;
        end
        -- append dirs
        for _, v in pairs( entries.dirs ) do
            table.insert( dirs, v );
        end
        
        -- check AUTH_FILE
        if entries.fileAuth then
            handler, err = self.make:make( entries.fileAuth.rpath );
            if err then
                return err;
            end
            -- merge
            for k,v in pairs( handler ) do
                authHandler[k] = v;
            end
        end

        -- check entry
        filesLua = entries.filesLua;
        for entry, stat in pairs( entries.files ) do
            -- add auth handler
            stat.authn = authHandler.authn;
            stat.authz = authHandler.authz;
            -- make file handler
            if filesLua[entry] then
                handler, err = self.make:make( filesLua[entry].rpath );
                if err then
                    return err;
                end
                -- add page handler
                for k,v in pairs( handler ) do
                    stat[k] = v;
                end
            end
            
            err = self.route:set( stat.rpath, stat );
            if err then
                return ('failed to set route %s: %s'):format( stat.rpath, err );
            -- add trailing-slash path if entry is index file
            elseif self.index[entry] then
                entry = stat.rpath:sub( 1, #stat.rpath - #entry );
                err = self.route:set( entry, stat );
                if err then
                    return ('failed to set index route %s: %s'):format( entry, err );
                end
            end
        end
        
        dir = util.table.shift( dirs );
    end
end


function Router:lookup( uri )
    return self.route:exec( uri );
end


function Router:dump()
    self.route:dump();
end

return Router.exports;

