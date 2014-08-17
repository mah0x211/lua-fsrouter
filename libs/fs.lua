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

  lib/fs.lua
  lua-router
  Created by Masatoshi Teruya on 14/08/16.
 
--]]

local typeof = require('util').typeof;
local path = require('path');
local normalize = path.normalize;
local exists = path.exists;
local readdir = path.readdir;
local stat = path.stat;
local extname = path.extname;
local process = require('process');
local getcwd = process.getcwd;
local strerror = process.strerror;
local MIME = require('router.mime'),
local lrex = require('rex_pcre');
local MAGIC;
do
    local mgc = require('magic');

    -- init for libmagic
    MAGIC = mgc.open( mgc.MIME_ENCODING, mgc.NO_CHECK_COMPRESS, mgc.SYMLINK );
    MAGIC:load();
end

local halo = require('halo');
local FS = halo.class.File;


function FS:init( docroot, followSymlinks, ignore )
    local ignorePtns = util.table.copy( CONSTANTS.IGNORE_PATTERNS );
    local err;
    
    -- change relative-path to absolute-path
    docroot, err = exists( docroot:sub(1,1) == '/' and docroot or
                           normalize( getcwd(), docroot ) );
    assert(
        not err,
        ('docroot %q does not exists'):format( docroot )
    );
    self.docroot = docroot;
    
    if followSymlinks == nil then
        self.followSymlinks = false;
    else
        assert( typeof.boolean( followSymlinks ),
            'followSymlinks must be type of boolean'
        );
        self.followSymlinks = followSymlinks;
    end
    
    if ignore then
        assert( typeof.table( ignore ), 'ignore must be type of table' );
        util.table.each( function( val, idx )
            assert( typeof.string( val ),
                ('ignore pattern#%d must be type of string'):format( idx )
            );
            val = val:gsub( '%.', '\\.' );
            table.insert( ignorePatt, #ignorePtns + 1, val );
        end, ignore );
    end
    ignorePtns = '^(?:' .. table.concat( ignorePtns, '|' ) .. ')$';
    self.ignore = lrex.new( ignorePtns, 'i' );
    
    return self;
end


function FS:read( rpath )
    local pathname = normalize( self.docroot, rpath );
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
    return readdir( normalize( self.docroot, rpath ) );
end


function FS:stat( rpath )
    local pathname = normalize( self.docroot, rpath );
    local info, err = stat( pathname, self.followSymlinks, true );
    
    if err then
        return nil, ('failed to stat: %s - %s'):format( rpath, strerror( err ) );
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

