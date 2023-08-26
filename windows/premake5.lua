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

    includedirs {"../3rd/lua", "../skynet-src"}

    files {"../3rd/lua/onelua.c"}

    defines {"MAKE_LIB"}

    filter { "system:windows" }
        disablewarnings { "4244","4018","4996",}

project "skynet"
    location "build/projects/%{prj.name}"
    objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
    targetdir "build/bin/%{cfg.buildcfg}"

    -- kind "ConsoleApp"
    kind "StaticLib"

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


local function add_service(name)
    project(name)
        location "build/projects/%{prj.name}"
        objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
        targetdir "build/bin/%{cfg.buildcfg}"
        kind "SharedLib"
        language "C"

        includedirs {
            "../skynet-src/",
            "../3rd/lua/",
            "../windows/posix/",
        }

    files {
        "../windows/vsdef/" .. name .. ".def",
        "../windows/posix/**.c",
        "../service-src/service_" .. name .. ".c",
    }

    links {"skynet",}

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

