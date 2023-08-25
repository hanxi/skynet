workspace "skynet"
    configurations { "Debug", "Release" }
    flags{"NoPCH","RelativeLinks"}
    cppdialect "C++17"
    location "./"
    architecture "x64"
    staticruntime "on"
    filter "configurations:Debug"
    defines { "DEBUG" }
    defines { "_AMD64_" }
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

    filter { "system:linux" }
    warnings "High"

    filter { "system:macosx" }
    warnings "High"

project "lua"
    location "build/projects/%{prj.name}"
    objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
    targetdir "build/bin/%{cfg.buildcfg}"
    kind "StaticLib"
    language "C"
    includedirs {"../3rd/lua"}
    includedirs {"../skynet-src"}
    files {"../3rd/lua/onelua.c"}
    defines {"MAKE_LIB"}
    filter { "system:windows" }
    disablewarnings { "4244","4018","4996",}

project "skynet"
    location "build/projects/%{prj.name}"
    objdir "build/obj/%{prj.name}/%{cfg.buildcfg}"
    targetdir "build/bin/%{cfg.buildcfg}"

    kind "ConsoleApp"

    language "C"

    includedirs {
                "../skynet-src",
                "../3rd/lua",
                "../windows/posix/",
                "../windows/wepoll",
            }

    files {
        "../skynet-src/**.c",
        "../windows/posix/**.c",
        "../windows/wepoll/**.c",
    }

    links{"lua"}

    defines {"NOUSE_JEMALLOC"}
    defines { "_AMD64_" }

    filter { "system:windows" }
        defines {"_WIN32_WINNT=0x0601"}
        linkoptions { '/STACK:"8388608"' }
        disablewarnings { "4244","4018","4996",}
    filter {"system:linux"}
        links{"dl","stdc++fs"}
        linkoptions {"-static-libstdc++ -static-libgcc", "-Wl,-rpath=./","-Wl,--as-needed"}
    filter {"system:macosx"}
        links{"dl",}
        linkoptions {"-Wl,-rpath,./"}
    filter "configurations:Debug"
        targetsuffix "-d"
    filter{"configurations:*"}
        postbuildcommands{"{COPY} %{cfg.buildtarget.abspath} %{wks.location}"}