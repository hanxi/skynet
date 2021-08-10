# 如何在 skyent 中加入 lua-cjson 库

其实主要是演示如何编译出 `cjson.so` 文件，因为不能使用操作系统里的 lua 来编译，需要使用 skynet 配套的 `3rd/lua` 来编译。对于新手来说，可能无法理解或者处理这些版本差异带来的一系列报错，比如：

```
lua loader error : error loading module 'cjson' from file './luaclib/cjson.so':
    ./luaclib/cjson.so: undefined symbol: 1ua_newuserdata
```

## 添加 lua-cjson 源码

首先添加 lua-cjson 源码到 3rd/lua-cjson 目录

```bash
git submodule add https://github.com/cloudwu/lua-cjson.git 3rd/lua-cjson
```

然后修改 Makefile ，添加 cjson 的编译选项：

- `LUA_CLIB` 变量添加 `cjson`
- `cjson.so` 配置生成依赖：
```Makefile
$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH)
       $(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@
```

修改差异如下：

```diff
diff --git a/Makefile b/Makefile
index 337ed3e..fd7ce50 100644
--- a/Makefile
+++ b/Makefile
@@ -53,7 +53,7 @@ update3rd :
 CSERVICE = snlua logger gate harbor
 LUA_CLIB = skynet \
   client \
-  bson md5 sproto lpeg $(TLS_MODULE)
+  bson md5 sproto lpeg cjson $(TLS_MODULE)

 LUA_CLIB_SKYNET = \
   lua-skynet.c lua-seri.c \
@@ -118,6 +118,9 @@ $(LUA_CLIB_PATH)/ltls.so : lualib-src/ltls.c | $(LUA_CLIB_PATH)
 $(LUA_CLIB_PATH)/lpeg.so : 3rd/lpeg/lpcap.c 3rd/lpeg/lpcode.c 3rd/lpeg/lpprint.c 3rd/lpeg/lptree.c 3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
        $(CC) $(CFLAGS) $(SHARED) -I3rd/lpeg $^ -o $@

+$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH)
+       $(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@
+
 clean :
        rm -f $(SKYNET_BUILD_PATH)/skynet $(CSERVICE_PATH)/*.so $(LUA_CLIB_PATH)/*.so && \
   rm -rf $(SKYNET_BUILD_PATH)/*.dSYM $(CSERVICE_PATH)/*.dSYM $(LUA_CLIB_PATH)/*.dSYM
```

然后执行 `make linux` 就能编译出 `luaclib/cjson.so` 文件了。

## 测试

新建 `test/testcjson.lua` 文件：

```lua
package.cpath = package.cpath .. ";luaclib/?.so"
local cjson = require "cjson"
local tbl = {
    a = 1,
    b = { 3, 2, 3, 4 },
}
print(cjson.encode(tbl))
```

然后执行 `./3rd/lua/lua test/testcjson.lua` 就能看到下面的输出了：

```txt
{"a":1,"b":[3,2,3,4]}
```

接下来在 skynet 中测试下，新建 `examples/config.cjson` 文件：

```lua
thread = 8
logger = nil
harbor = 0
start = "testcjson"
bootstrap = "snlua bootstrap"	-- The service for bootstrap
luaservice = "./service/?.lua;./test/?.lua;./examples/?.lua"
```

然后执行 `./skynet examples/config.cjson` 就能看到下面的输出：

```txt
[:00000002] LAUNCH snlua bootstrap
[:00000003] LAUNCH snlua launcher
[:00000004] LAUNCH snlua cdummy
[:00000005] LAUNCH harbor 0 4
[:00000006] LAUNCH snlua datacenterd
[:00000007] LAUNCH snlua service_mgr
[:00000008] LAUNCH snlua testcjson
{"b":[3,2,3,4],"a":1}
```

