#ifndef NV_EGL_APP_CONTEXT_H
#define NV_EGL_APP_CONTEXT_H

// BEGIN_INCLUDE(all)
#include <NvSimpleTypes.h>

#include <errno.h>
#include <jni.h>
#include "../../NvEGLUtil/NvEGLUtil.h"
#include "NvAppBase/TKAppBase.h"
#include "NvAppBase/gl/TKAppContextGL.h"
#include "NvFBOPool.h"

#define EGL_STATUS_LOG(str) \
    LOGD("Success: %s (%s:%d)", str, __FUNCTION__, __LINE__)

#define EGL_ERROR_LOG(str)                      \
    LOGE("Failure: %s, error = 0x%08x (%s:%d)", \
         str,                                   \
         eglGetError(),                         \
         __FUNCTION__,                          \
         __LINE__)

class TKAppContextEGL : public TKAppContextGL {
public:
    TKAppContextEGL(NvEGLWinUtil* win)
        : TKAppContextGL(NvPlatformInfo(NvPlatformCategory::PLAT_MOBILE,
                                        NvPlatformOS::OS_ANDROID))
        , mWin(win) {
        win->getConfiguration(mConfig);
    }

    bool bindContext() {
        return mWin->bind();
    }

    bool unbindContext() {
        return mWin->unbind();
    }

    bool prepareThread() {
        return mWin->prepareThread();
    }

    bool swap() {
        return mWin->swap();
    }

    bool swapFBO() {
        NvSimpleFBO* fbo = mFBOPool->deque();
        mMainFBO = fbo->fbo;
        glBindFramebuffer(GL_FRAMEBUFFER, mMainFBO);
        mFBOPool->enque(fbo);
        return true;
    }

    bool setSwapInterval(int32_t) {
        return false;
    }

    int32_t width() {
        return mUseFBOPair ? mFBOWidth : mWin->getWidth();
    }

    int32_t height() {
        return mUseFBOPair ? mFBOHeight : mWin->getHeight();
    }

    bool isExtensionSupported(const char* ext);

    GLproc getGLProcAddress(const char* procname) {
        return mWin->getProcAddress(procname);
    }

    virtual bool requestResetContext() {
        return mWin->requestResetContext();
    }

    virtual void* getCurrentPlatformContext() {
        return mWin->getContext();
    }

    virtual void* getCurrentPlatformDisplay() {
        return mWin->getDisplay();
    }

    virtual bool useOffscreenRendering(int32_t w, int32_t h) {
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        mUseFBOPair = false;
        endFrame();
        mUseFBOPair = true;

        mFBOWidth = w;
        mFBOHeight = h;

        NvSimpleFBO::Desc desc;
        desc.width = mFBOWidth;
        desc.height = mFBOHeight;
        desc.color.format = GL_RGBA;
        desc.color.filter = GL_LINEAR;
        desc.color.type = GL_UNSIGNED_BYTE;
        desc.color.wrap = GL_CLAMP_TO_EDGE;

        if (getConfiguration().apiVer.api == NvGLAPI::GL ||
            getConfiguration().apiVer.majVersion >= 3 ||
            isExtensionSupported("GL_OES_packed_depth_stencil")) {
            desc.depthstencil.format = 0x88F0; // GL_DEPTH24_STENCIL8_EXT
        } else {
            desc.depth.format = GL_DEPTH_COMPONENT;
            desc.depth.type = GL_UNSIGNED_INT;
            desc.depth.filter = GL_NEAREST;
        }

        mFBOPool = new NvFBOPool(desc, mWin->getDisplay());
        if (!mFBOPool->initialized()) {
            mUseFBOPair = false;
        }

        endFrame();
        return mUseFBOPair;
    }

protected:
    NvEGLWinUtil* mWin;
    NvFBOPool* mFBOPool;
};

inline bool TKAppContextEGL::isExtensionSupported(const char* ext) {
    // Extension names should not have spaces.
    const GLubyte* where = (GLubyte*)strchr(ext, ' ');
    if (where || *ext == '\0') {
        return false;
    }

    const GLubyte* extensions = glGetString(GL_EXTENSIONS);
    if (!extensions) {
        // Is an OpenGL context not bound??
        return false;
    }
    // It takes a bit of care to be fool-proof about parsing the
    // OpenGL extensions string.  Don't be fooled by sub-strings,
    // etc.
    const GLubyte* start = extensions;
    for (;;) {
        where = (const GLubyte*)strstr((const char*)start, ext);
        if (!where) {
            break;
        }
        const GLubyte* terminator = where + strlen(ext);
        if (where == start || *(where - 1) == ' ') {
            if (*terminator == ' ' || *terminator == '\0') {
                return true;
            }
        }
        start = terminator;
    }
    return false;
}

#endif
