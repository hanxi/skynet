workspace "skynet"
    configurations {"Release", "Debug",}
    flags{ "NoPCH", "RelativeLinks"}
    cppdialect "C++17"
    location "./"
    architecture "x64"
    staticruntime "on"
    defines { "_AMD64_" }

    filter "configurations:Debug"
        defines { "DEBUG" }
        symbols "On"

    filter "configurations:Release"
        defines { "NDEBUG" }
        optimize "On"
        symbols "On"

    filter {"system:windows"}
        characterset "MBCS"
        systemversion "latest"
        warnings "Extra"
        cdialect "C11"
        buildoptions{"/experimental:c11atomics"}

project "lua"
    location "build/projects/%{prj.name}"
    objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
    targetdir "build/bin/%{cfg.buildcfg}"
    kind "StaticLib"
    language "C"

    includedirs {
        "../3rd/lua",
        "../skynet-src",
    }

    files {"../3rd/lua/onelua.c"}

    defines {"MAKE_LIB"}

    filter { "system:windows" }
        disablewarnings { "4244","4018","4996",}


local function add_skynet(kindType, name)
    project(name)
        location "build/projects/%{prj.name}"
        objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
        targetdir "build/bin/%{cfg.buildcfg}"

        kind(kindType)

        language "C"

        includedirs {
                    "../windows/vsdef/skynet.def",
                    "../skynet-src/",
                    "../3rd/lua/",
                    "../windows/posix/",
                    "../windows/wepoll",
                }

        files {
            "../skynet-src/**.c",
            "../windows/posix/**.c",
            "../windows/wepoll/**.c",
        }

        links{ "lua", "ws2_32.lib"}

        defines {"NOUSE_JEMALLOC", "_CONSOLE", "_LIB"}

        linkoptions { '/STACK:"8388608"' }
        disablewarnings { "4244","4018","4996",}

        filter "configurations:Debug"
            targetsuffix "-d"
        filter{"configurations:*"}
            postbuildcommands{"{COPY} %{cfg.buildtarget.abspath} %{wks.location}"}
end

add_skynet("StaticLib", "skynetlib")
add_skynet("ConsoleApp", "skynet")

local function add_service(name)
    project(name)
        location "build/projects/%{prj.name}"
        objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
        targetdir "build/bin/%{cfg.buildcfg}/cservice"

        kind "SharedLib"
        language "C"

        includedirs {
            "../skynet-src/",
            "../3rd/lua/",
            "../windows/posix/",
        }

        files {
            "../windows/vsdef/cservice/" .. name .. ".def",
            "../windows/posix/**.c",
            "../service-src/service_" .. name .. ".c",
        }

        links {"skynetlib",}
        linkoptions { '/STACK:"8388608"' }
        disablewarnings { "4244","4018","4996",}

        filter "configurations:Debug"
            targetsuffix "-d"
        filter{"configurations:*"}
            postbuildcommands{"{COPY} %{cfg.buildtarget.abspath} %{wks.location}"}
end

add_service("snlua")
add_service("logger")
add_service("harbor")
add_service("gate")

-- local function add_skynet_lua(name)
--     project(name)
--         location "build/projects/%{prj.name}"
--         objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
--         targetdir "build/bin/%{cfg.buildcfg}/luaclib"

--         kind "SharedLib"
--         language "C"

--         includedirs {
--             "../skynet-src/",
--             "../3rd/lua/",
--             "../3rd/lualib-src/",
--             "../windows/posix/",
--         }

--         files {
--             "../windows/vsdef/luaclib/" .. name .. ".def",
                -- "../windows/posix/**.c",
--             "lua-skynet.c",
--             "lua-seri.c",
--             "lua-socket.c",
--             "lua-mongo.c",
--             "lua-netpack.c",
--             "lua-memory.c",
--             "lua-multicast.c",
--             "lua-cluster.c",
--             "lua-crypt.c",
--             "lsha1.c",
--             "lua-sharedata.c",
--             "lua-stm.c",
--             "lua-debugchannel.c",
--             "lua-datasheet.c",
--             "lua-sharetable.c",
--         }

--         links {"skynetlib",}
--         linkoptions { '/STACK:"8388608"' }
--         disablewarnings { "4244","4018","4996",}

--         filter "configurations:Debug"
--             targetsuffix "-d"
--         filter{"configurations:*"}
--             postbuildcommands{"{COPY} %{cfg.buildtarget.abspath} %{wks.location}"}
-- end

-- add_skynet_lua("skynet")