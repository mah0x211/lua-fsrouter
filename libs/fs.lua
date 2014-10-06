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

  libs/fs.lua
  lua-router
  Created by Masatoshi Teruya on 14/08/16.
 
--]]

-- modules
local util = require('util');
local typeof = util.typeof;
local path = require('path');
local normalize = path.normalize;
local exists = path.exists;
local readdir = path.readdir;
local stat = path.stat;
local extname = path.extname;
local getcwd = require('process').getcwd;
local lrex = require('rex_onig');
-- init lrex-oniguruma
lrex.setdefaultsyntax('PERL');
-- constants
local CONSTANTS = require('router.constants');
local LUA_EXT = CONSTANTS.LUA_EXT;
local SPECIAL_FILES = {
    [CONSTANTS.AUTH_FILE] = 'auth',
    [CONSTANTS.FILTER_FILE] = 'filter'
};
local MIME = require('router.mime');
-- init for libmagic
local MAGIC;
do
    local mgc = require('magic');
    MAGIC = mgc.open( mgc.MIME_ENCODING, mgc.NO_CHECK_COMPRESS, mgc.SYMLINK );
    MAGIC:load();
end
-- class
local FS = require('halo').class.File;

function FS:init( docroot, followSymlinks, ignore )
    local ignorePtns = util.table.copy( CONSTANTS.IGNORE_PATTERNS );
    -- change relative-path to absolute-path
    local rootpath, err = exists( docroot:sub(1,1) == '/' and docroot or
                          normalize( getcwd(), docroot ) );

    -- set document root
    assert( not err, ('docroot %q does not exists'):format( docroot ) );
    self.docroot = rootpath;
    
    -- set follow symlinks option
    if followSymlinks == nil then
        self.followSymlinks = false;
    else
        assert( typeof.boolean( followSymlinks ),
            'followSymlinks must be type of boolean'
        );
        self.followSymlinks = followSymlinks;
    end
    
    -- set ignore list
    if ignore then
        assert( typeof.table( ignore ), 'ignore must be type of table' );
        util.table.each( ignore, function( val, idx )
            assert( typeof.string( val ),
                ('ignore pattern#%d must be type of string'):format( idx )
            );
            table.insert( ignorePtns, #ignorePtns + 1, val );
        end);
    end
    ignorePtns = '^(?:' .. table.concat( ignorePtns, '|' ) .. ')$';
    self.ignore = lrex.new( ignorePtns, 'i' );
    
    return self;
end


function FS:realpath( rpath )
    return normalize( self.docroot, rpath );
end


function FS:read( rpath )
    local pathname = self:realpath( rpath );
    local fh, err = io.open( pathname );
    local src;
    
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


function FS:readdir( rpath )
    local entries, err = readdir( normalize( self.docroot, rpath ) );
    
    if not err then
        local result = {
            dirs = {},
            files = {},
            scripts = {}
        };
        local dirs = result.dirs;
        local files = result.files;
        local scripts = result.scripts;
        local info, field;
        
        -- list up
        for _, entry in ipairs( entries ) do
            field = SPECIAL_FILES[entry];
            -- AUTH_FILE and FILTER_FILE is highest priority file
            if field then
                info, err = self:stat( normalize( rpath, entry ) );
                if err then
                    return nil, err;
                elseif info.type == 'reg' then
                    result[field] = info;
                end
                -- remove type field
                info.type = nil;
            -- not ignoring files
            elseif not self.ignore:match( entry ) then
                info, err = self:stat( normalize( rpath, entry ) );
                -- error: stat
                if err then
                    return nil, err;
                elseif info.type == 'dir' then
                    dirs[entry] = info.rpath;
                elseif info.type == 'reg' then
                    if info.ext == LUA_EXT then
                        -- remove file extension LUA_EXT
                        scripts[entry:sub( 1, #entry - #LUA_EXT )] = info;
                    else
                        files[entry] = info;
                    end
                end
                -- remove type field
                info.type = nil;
            end
        end
        
        return result;
    end
    
    return nil, ('failed to readdir %s - %s'):format( rpath, err );
end


function FS:stat( rpath )
    local pathname = normalize( self.docroot, rpath );
    local info, err = stat( pathname, self.followSymlinks, true );
    
    if err then
        return nil, ('failed to stat: %s - %s'):format( rpath, err );
    -- regular file
    elseif info.type == 'reg' then
        local ext = extname( rpath );
        
        return {
            ['type'] = info.type,
            pathname = pathname,
            rpath = rpath,
            ext = ext,
            charset = MAGIC:file( pathname ),
            mime = MIME[ext],
            ctime = info.ctime,
            mtime = info.mtime,
        };
    end
    
    -- other
    return {
        ['type'] = info.type,
        pathname = pathname,
        rpath = rpath,
        ctime = info.ctime,
        mtime = info.mtime
    };
end


return FS.exports;

