# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Sets the minimum version of CMake required to build the native library.

cmake_minimum_required(VERSION 3.4.1)

add_definitions("-Wno-deprecated-register")
add_definitions("-Wno-parentheses")
add_definitions("-Wno-tautological-compare")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++1z -Wall -Wunused-variable")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -D_DEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -DNDEBUG")

include_directories( #
        apemode/
        nuklear/

        #
        # nvidia gameworks
        #

        gameworks/externals/include
        gameworks/externals/include/GL
        gameworks/externals/include/GLFW
        gameworks/externals/include/GLFW/GL
        gameworks/externals/include/GLFW/GLES2
        gameworks/externals/include/GLFW/KHR
        gameworks/src/NsFoundation/android
        gameworks/src/NsFoundation/unix
        gameworks/src/NvAppBase/android
        gameworks/src
        gameworks/include
        gameworks/include/NV
        gameworks/include/NvFoundation
        gameworks/include/NsFoundation/unix
        gameworks/include/NvGamepad
        gameworks/include/NvGamepad/android
        gameworks/include/NvGLESWrapper
        gameworks/include/NvGLUtils
        gameworks/include/NvImage
        gameworks/include/NvModel
        gameworks/include/NsFoundation
        gameworks/include
        gameworks/include/NsFoundation
        gameworks/include/NsFoundation/unix
        gameworks/include/NsFoundation/windows
        gameworks/include/NV
        gameworks/include/NvAppBase
        gameworks/include/NvAppBase/gl
        gameworks/include/NvAssetLoader
        gameworks/include/NvFoundation
        gameworks/include/NvFoundation/unix
        gameworks/include/NvFoundation/windows
        gameworks/include/NvGamepad
        gameworks/include/NvGLESWrapper
        gameworks/include/NvGLUtils
        gameworks/include/NvImage
        gameworks/include/NvModel
        gameworks/include/NvUI

        gameworks/externals/src/freetype-2.4.9/include
        gameworks/externals/src/freetype-2.4.9/include/freetype/config/
        gameworks/externals/src/freetype-2.4.9/builds/unix/
        )



# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds them for you.
# Gradle automatically packages shared libraries with your APK.

add_library(
        native-lib
        SHARED
        apemode/TKGL.h
        apemode/TKAppGL.cpp
        apemode/TKAppGL.h
        apemode/TKNuklearRendererGL.cpp
        apemode/TKNuklearRendererGL.h
        native-lib.cpp )

add_library(
        gameworks
        STATIC
        gameworks/src/NsFoundation/NsAllocator.cpp
        gameworks/src/NsFoundation/NsAssert.cpp
        gameworks/src/NsFoundation/NsHeaderTest.cpp
        gameworks/src/NsFoundation/NsTempAllocator.cpp
        gameworks/src/NsFoundation/NsGlobals.cpp
        gameworks/src/NsFoundation/NsString.cpp
        gameworks/src/NsFoundation/android/cpu-features.c
        gameworks/src/NsFoundation/unix/NsUnixAtomic.cpp
        gameworks/src/NsFoundation/unix/NsUnixMutex.cpp
        gameworks/src/NsFoundation/unix/NsUnixSocket.cpp
        gameworks/src/NsFoundation/unix/NsUnixTime.cpp
        gameworks/src/NsFoundation/unix/NsUnixCpu.cpp
        gameworks/src/NsFoundation/unix/NsUnixPrintString.cpp
        gameworks/src/NsFoundation/unix/NsUnixSync.cpp
        gameworks/src/NsFoundation/unix/NsUnixFPU.cpp
        gameworks/src/NsFoundation/unix/NsUnixSList.cpp
        gameworks/src/NsFoundation/unix/NsUnixThread.cpp
        gameworks/src/NvGamepad/android/NvGamepadAndroid.cpp
        gameworks/src/NvAssetLoader/android/NvAssetLoaderAndroid.cpp
        gameworks/src/NvAppBase/android/EngineAndroid.cpp
        gameworks/src/NvAppBase/android/NvFBOPool.cpp
        gameworks/src/NvAppBase/android/MainAndroid.cpp
        gameworks/src/NvAppBase/android/NvAndroidNativeAppGlue.c
        gameworks/src/NvAppBase/android/NvAndroidWinUtil.cpp
        gameworks/src/NvAppBase/android/NvThreadAnd.cpp
        gameworks/src/NvAppBase/TKAppBase.cpp
        gameworks/src/NvAppBase/TKSampleApp.cpp
        gameworks/src/NvAppBase/NvFoundationInit.cpp
        gameworks/src/NvAppBase/NvFramerateCounter.cpp
        gameworks/src/NvAppBase/gl/TKAppContextGL.cpp
        gameworks/src/NvAppBase/gl/TKSampleAppGL.cpp
        gameworks/src/NvEGLUtil/NvEGLUtil.cpp
        gameworks/src/NvGLUtils/NvTimers.cpp
        gameworks/src/NvGLUtils/NvLogsGL.cpp
        gameworks/src/NvGLUtils/NvGLSLProgram.cpp)


find_library( log-lib log )
find_library( dl-lib dl )
find_library( android-lib android )
find_library( EGL-lib EGL )
find_library( GLESv1_CM-lib GLESv1_CM )
find_library( GLESv2-lib GLESv2 )

target_link_libraries(
        native-lib
        gameworks

        ${log-lib}
        ${android-lib}
        ${dl-lib}
        ${EGL-lib}
        ${GLESv1_CM-lib}
        ${GLESv2-lib} )