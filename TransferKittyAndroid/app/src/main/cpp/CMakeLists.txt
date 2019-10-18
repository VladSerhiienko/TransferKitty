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

        gameworks/src/main/cpp/gameworks/externals/include
        gameworks/src/main/cpp/gameworks/externals/include/GL
        gameworks/src/main/cpp/gameworks/externals/include/GLFW
        gameworks/src/main/cpp/gameworks/externals/include/GLFW/GL
        gameworks/src/main/cpp/gameworks/externals/include/GLFW/GLES2
        gameworks/src/main/cpp/gameworks/externals/include/GLFW/KHR
        gameworks/src/main/cpp/gameworks/include
        gameworks/src/main/cpp/gameworks/include/NV
        gameworks/src/main/cpp/gameworks/include/NvFoundation
        gameworks/src/main/cpp/gameworks/include/NsFoundation/unix
        gameworks/src/main/cpp/gameworks/include/NvGamepad
        gameworks/src/main/cpp/gameworks/include/NvGamepad/android
        gameworks/src/main/cpp/gameworks/include/NvGLESWrapper
        gameworks/src/main/cpp/gameworks/include/NvGLUtils
        gameworks/src/main/cpp/gameworks/include/NvImage
        gameworks/src/main/cpp/gameworks/include/NvModel
        gameworks/src/main/cpp/gameworks/include/NsFoundation
        gameworks/src/main/cpp/gameworks/src/NsFoundation/android
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix
        gameworks/src/main/cpp/gameworks/src
        gameworks/src/main/cpp/gameworks/include
        gameworks/src/main/cpp/gameworks/include/NsFoundation
        gameworks/src/main/cpp/gameworks/include/NsFoundation/unix
        gameworks/src/main/cpp/gameworks/include/NsFoundation/windows
        gameworks/src/main/cpp/gameworks/include/NV
        gameworks/src/main/cpp/gameworks/include/NvAppBase
        gameworks/src/main/cpp/gameworks/include/NvAppBase/gl
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android
        gameworks/src/main/cpp/gameworks/include/NvAssetLoader
        gameworks/src/main/cpp/gameworks/include/NvFoundation
        gameworks/src/main/cpp/gameworks/include/NvFoundation/unix
        gameworks/src/main/cpp/gameworks/include/NvFoundation/windows
        gameworks/src/main/cpp/gameworks/include/NvGamepad
        gameworks/src/main/cpp/gameworks/include/NvGLESWrapper
        gameworks/src/main/cpp/gameworks/include/NvGLUtils
        gameworks/src/main/cpp/gameworks/include/NvImage
        gameworks/src/main/cpp/gameworks/include/NvModel
        gameworks/src/main/cpp/gameworks/include/NvUI

        gameworks/src/main/cpp/gameworks/externals/src/freetype-2.4.9/include
        gameworks/src/main/cpp/gameworks/externals/src/freetype-2.4.9/include/freetype/config/
        gameworks/src/main/cpp/gameworks/externals/src/freetype-2.4.9/builds/unix/
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
        gameworks/src/main/cpp/gameworks/src/NsFoundation/NsAllocator.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/NsAssert.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/NsHeaderTest.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/NsTempAllocator.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/NsGlobals.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/NsString.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/android/cpu-features.c
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixAtomic.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixMutex.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixSocket.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixTime.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixCpu.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixPrintString.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixSync.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixFPU.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixSList.cpp
        gameworks/src/main/cpp/gameworks/src/NsFoundation/unix/NsUnixThread.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android/EngineAndroid.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android/NvFBOPool.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android/MainAndroid.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android/NvAndroidNativeAppGlue.c
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android/NvAndroidWinUtil.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/android/NvThreadAnd.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/gl/NvAppContextGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/gl/NvSampleAppGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/NvAppBase.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/NvFoundationInit.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/NvFramerateCounter.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/NvInputHandler_CameraFly.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/NvInputTransformer.cpp
        gameworks/src/main/cpp/gameworks/src/NvAppBase/NvSampleApp.cpp
        gameworks/src/main/cpp/gameworks/src/NvAssetLoader/android/NvAssetLoaderAndroid.cpp
        gameworks/src/main/cpp/gameworks/src/NvEGLUtil/NvEGLUtil.cpp
        gameworks/src/main/cpp/gameworks/src/NvGamepad/android/NvGamepadAndroid.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvBitFontGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvGLSLProgram.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvImageGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvLogsGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvShapesGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvTimers.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvUIGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvUIGraphicGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvUIGraphicFrameGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvUIShadersGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvGLUtils/NvUITextureRenderGL.cpp
        gameworks/src/main/cpp/gameworks/src/NvImage/BlockDXT.cpp
        gameworks/src/main/cpp/gameworks/src/NvImage/ColorBlock.cpp
        gameworks/src/main/cpp/gameworks/src/NvImage/NvFilePtr.cpp
        gameworks/src/main/cpp/gameworks/src/NvImage/NvImage.cpp
        gameworks/src/main/cpp/gameworks/src/NvImage/NvImageDDS.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvBitFont.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvEmbeddedAsset.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvGestureDetector.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUI.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIContainer.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIButton.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUISlider.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIText.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIPopup.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIGraphic.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIGraphicFrame.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvTweakBar.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvTweakVar.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIValueText.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIValueBar.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUIWindow.cpp
        gameworks/src/main/cpp/gameworks/src/NvUI/NvUITexture.cpp)


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