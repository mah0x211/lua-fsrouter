lua-fsrouter
===

[![test](https://github.com/mah0x211/lua-fsrouter/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-fsrouter/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-fsrouter/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-fsrouter?branch=master)

`lua-fsrouter` is a filesystem-based url router based on [lua-plut](https://github.com/mah0x211/lua-plut).


## Installation

```
luarocks install fsrouter
```

## Create a router from the base directory

### r, err, routes = fsrouter.new( pathname [, opts] )

create a new router based on the specified directory.

**Parameters**

- `pathname:string`: path of the base directory.
- `opts:table`
    - `compiler:function`: function to compile a handler file.  
        ```
        -- Specification of the compiler function
        methods [, err] = compiler( pathname )

        - `pathname:string`: path of the target file.
        - `methods:table<string, function>`: method-name/function pairs.
           method-name must be one of the following names:
             'all' / 'any' / 'get' / 'head' / 'post' / 'put' / 'delete' / 
             'connect' / 'trace' / 'patch'.
        ```
    - `loadfenv:function`: function that returns the environment of a handler function. (default: `fsrouter.default.fenv`)
    - other options are passed to [lua-basedir.new function](https://github.com/mah0x211/lua-basedir#bd--basedirnew-pathname--opts-).

**Returns**

- `r:fsrouter`: instance of fsrouter.
- `err:error`: error message.
- `routes:table[]`: registered routing table.


### URL parameter files and directories

`fsrouter` uses files and directories with the `$` and `*` prefixes as 
parameter segments.

```
html/
├── $user
│   ├── $repo.html
│   └── contents
│       └── *id.html
└── index.html
```

the above directory layout will be converted into the following routing table.

- `/`
- `/:user/:repo`
- `/:user/contents/*id`


### Handler Files

`fsrouter` manages files with the `@` and `#` prefixes as handler files.

the functions described in the handler file are categorized as follows, and 
stored in the `methods` table for each route as method name/functions pairs.

**NOTE: the filter handler will be used in the defined directory and the 
directories under it.**


### Describe handler function

`fsrouter` specifies only how to define a function. the specifications of 
function `arguments` and `return values` are left to the user.

In the default compiler, the handler function should be written as follows.

```lua
-- the handler table is a proxy for registering functions.

-- describe a get handler directly
function handler.get()
    -- describe the contents...
end

-- describe a post handler locally
local function do_handle_post_request()
    -- describe the contents...
end
-- assign do_handle_post_request function as a post handler
handler.post = do_handle_post_request
```

The following names can be specified for the handler name;  

- `all`: this method is only available for filter handlers.
- `any`: this method is used when there is no corresponding method except `all` method.
- `get`, `head`, `post`, `put`, `delete`, `connect`, `trace`, `patch`.




### `@` prefix is used as the content handler file.

```
html/
└── $user
    ├── @index.lua     <-- @index.lua is used as a handler for index.html
    ├── @profile.lua
    └── index.html
```

the above directory layout will be converted into the following routing table.

- `/:user`
- `/:user/profile`

**NOTE:**  if the basename of the handler file matches the basename of a static 
file in the same directory, it will be used as the content handler for the 
matched static file.


### `#` prefix is used as the filter handler file.

```
html/
├── #1.block_ip.lua
├── #2.check_user.lua
├── $user
│   ├── #1.block_user.lua
│   └── index.html
├── index.html
└── signin
    ├── #-.block_ip.lua     <-- disable the #1.block_ip.lua filter handlers
    ├── #-.check_user.lua   <-- disable the #2.check_user.lua filter handlers
    └── index.html
```

the above directory layout will be converted into the following routing table.

- `/`
- `/signin`
- `/:user`


**NOTE:** the number following the `#` prefix indicates the `priority`. smaller numbers 
have higher priority, and the same priority number cannot be specified. also, 
you can disable the filter to specify `-` instead of a number.


## Getting the route value by pathname

### v, err, glob = r:lookup( pathname )

getting the route value in the specified pathname.

**Parameters**

- `pathname:string`: target pathname.

**Returns**

- `val:any`: the route value in the specified pathname.
- `err:error`: an error message.
- `glob:table`: holds the the values of variable segment.



## Example

example document root directory.

```
html/
├── #1.block_ip.lua
├── #2.check_user.lua
├── $user
│   ├── #1.block_user.lua
│   ├── @index.lua
│   ├── @profile.lua
│   ├── index.html
│   ├── posts
│   │   ├── #1.extract_id.lua
│   │   ├── *id.html
│   │   ├── @*id.lua
│   │   ├── @index.lua
│   │   └── index.html
│   └── profile.html
├── @index.lua
├── @settings.lua
├── api
│   └── @index.lua
├── index.html
├── settings.html
└── signin
    ├── #-.block_ip.lua
    ├── #-.check_user.lua
    ├── @index.lua
    └── index.html
```

```lua
local dump = require('dump')
local fsrouter = require('fsrouter')

-- create a new router based on the specified directory
local r = fsrouter.new('html')
-- lookup route
local route, err, glob = r:lookup('/foobar/posts/post-id/hello-my-post')
print(dump({
    route = route,
    err = err,
    glob = glob,
}))
```


<details>
<summary>Output of the above code</summary>

```
{
  glob = {
    id = "post-id/hello-my-post",
    user = "foobar"
  },
  route = {
    file = {
      charset = "us-ascii",
      ctime = 1642664589.0,
      entry = "*id.html",
      ext = ".html",
      mime = "text/html",
      mtime = 1642664589.0,
      pathname = "/***/html/$user/posts/*id.html",
      rpath = "/$user/posts/*id.html",
      size = 10.0,
      type = "file"
    },
    filters = {
      all = {
        [1] = {
          fn = "function: 0x7f92cbe21540",
          name = "block_ip.lua",
          order = 1,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#1.block_ip.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cbe21540"
            },
            mtime = 1642664589.0,
            order = 1,
            pathname = "/***/html/#1.block_ip.lua",
            rpath = "/#1.block_ip.lua",
            size = 201.0
          }
        },
        [2] = {
          fn = "function: 0x7f92cbe1f100",
          name = "check_user.lua",
          order = 2,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#2.check_user.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cbe1f100"
            },
            mtime = 1642664589.0,
            order = 2,
            pathname = "/***/html/#2.check_user.lua",
            rpath = "/#2.check_user.lua",
            size = 275.0
          }
        },
        [3] = {
          fn = "function: 0x7f92cdd0bc40",
          name = "block_user.lua",
          order = 1,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#1.block_user.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cdd0bc40"
            },
            mtime = 1642664589.0,
            order = 1,
            pathname = "/***/html/$user/#1.block_user.lua",
            rpath = "/$user/#1.block_user.lua",
            size = 168.0
          }
        },
        [4] = {
          fn = "function: 0x7f92cdd15280",
          name = "extract_id.lua",
          order = 1,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#1.extract_id.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cdd15280"
            },
            mtime = 1642664589.0,
            order = 1,
            pathname = "/***/html/$user/posts/#1.extract_id.lua",
            rpath = "/$user/posts/#1.extract_id.lua",
            size = 170.0
          }
        }
      }
    },
    handler = {
      charset = "us-ascii",
      ctime = 1642664589.0,
      entry = "@*id.lua",
      ext = ".lua",
      methods = {
        any = "function: 0x7f92cdd140a0",
        get = "function: 0x7f92cdd14010"
      },
      mtime = 1642664589.0,
      pathname = "/***/html/$user/posts/@*id.lua",
      rpath = "/$user/posts/@*id.lua",
      size = 173.0
    },
    methods = {
      any = {
        [1] = {
          fn = "function: 0x7f92cbe21540",
          idx = 1,
          method = "all",
          name = "/#1.block_ip.lua",
          type = "filter"
        },
        [2] = {
          fn = "function: 0x7f92cbe1f100",
          idx = 2,
          method = "all",
          name = "/#2.check_user.lua",
          type = "filter"
        },
        [3] = {
          fn = "function: 0x7f92cdd0bc40",
          idx = 3,
          method = "all",
          name = "/$user/#1.block_user.lua",
          type = "filter"
        },
        [4] = {
          fn = "function: 0x7f92cdd15280",
          idx = 4,
          method = "all",
          name = "/$user/posts/#1.extract_id.lua",
          type = "filter"
        },
        [5] = {
          fn = "function: 0x7f92cdd140a0",
          method = "any",
          name = "/$user/posts/@*id.lua",
          type = "handler"
        }
      },
      get = {
        [1] = {
          fn = "function: 0x7f92cbe21540",
          idx = 1,
          method = "all",
          name = "/#1.block_ip.lua",
          type = "filter"
        },
        [2] = {
          fn = "function: 0x7f92cbe1f100",
          idx = 2,
          method = "all",
          name = "/#2.check_user.lua",
          type = "filter"
        },
        [3] = {
          fn = "function: 0x7f92cdd0bc40",
          idx = 3,
          method = "all",
          name = "/$user/#1.block_user.lua",
          type = "filter"
        },
        [4] = {
          fn = "function: 0x7f92cdd15280",
          idx = 4,
          method = "all",
          name = "/$user/posts/#1.extract_id.lua",
          type = "filter"
        },
        [5] = {
          fn = "function: 0x7f92cdd14010",
          method = "get",
          name = "/$user/posts/@*id.lua",
          type = "handler"
        }
      }
    },
    name = "*id",
    rpath = "/:user/posts/*id"
  }
}
```

</details>
