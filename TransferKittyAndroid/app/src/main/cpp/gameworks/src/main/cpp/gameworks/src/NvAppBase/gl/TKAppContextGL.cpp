#include "NvAppBase/gl/TKAppContextGL.h"
#include "NvGLUtils/NvImageGL.h"
#include "NvGLUtils/NvSimpleFBO.h"

#include "NV/NvLogs.h"

TKAppContextGL::TKAppContextGL(NvPlatformInfo info)
    : NvAppContext(info)
    , mWindowWidth(0)
    , mWindowHeight(0)
    , mMainFBO(0)
    , mUseFBOPair(false)
    , mCurrentFBOIndex(0)
    , mFBOWidth(0)
    , mFBOHeight(0) {
    mFBOPair[0] = nullptr;
    mFBOPair[1] = nullptr;
}

TKAppContextGL::~TKAppContextGL() {
    delete mFBOPair[0];
    delete mFBOPair[1];
    mFBOPair[0] = nullptr;
    mFBOPair[1] = nullptr;
}

bool TKAppContextGL::useOffscreenRendering(int32_t w, int32_t h) {
    // clear the main framebuffer to black for later testing
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

    mFBOPair[0] = new NvSimpleFBO(desc);
    mFBOPair[1] = new NvSimpleFBO(desc);

    endFrame();

    return true;
}

bool TKAppContextGL::isRenderingToMainScreen() {
    if (mUseFBOPair) {
        // Check if the app bound FBO 0 in FBO mode
        GLuint currFBO = 0;
        // Enum has MANY names based on extension/version
        // but they all map to 0x8CA6
        glGetIntegerv(0x8CA6, (GLint*)&currFBO);

        return (currFBO == 0);
    } else {
        return true;
    }
}

void TKAppContextGL::platformReshape(int32_t& w, int32_t& h) {
    mWindowWidth = w;
    mWindowHeight = h;

    if (mUseFBOPair) {
        w = mFBOWidth;
        h = mFBOHeight;
    }
}

void TKAppContextGL::beginFrame() {
}

void TKAppContextGL::beginScene() {
}

void TKAppContextGL::endScene() {
}

bool TKAppContextGL::swapFBO() {
    mCurrentFBOIndex = mCurrentFBOIndex ? 0 : 1;
    mMainFBO = mFBOPair[mCurrentFBOIndex]->fbo;
    glBindFramebuffer(GL_FRAMEBUFFER, mMainFBO);
    return true;
}

void TKAppContextGL::endFrame() {
    if (mUseFBOPair) {
        swapFBO();
    } else {
        swap();
    }
}

void TKAppContextGL::contextInitRendering() {
    // NvImageGL::SupportsFormatConversion(getConfiguration().apiVer.api !=
    // NvGLAPI::GLES); NvImage::setSupportsBGR(getConfiguration().apiVer.api !=
    // NvGLAPI::GLES);
}

void TKAppContextGL::initUI() {
    // extern void NvUIUseGL();
    // NvUIUseGL();
}

bool TKAppContextGL::readFramebufferRGBX32(uint8_t* dest,
                                           int32_t& w,
                                           int32_t& h) {
    // This above TEST_MODE_FBO_ISSUE only checks the flag from the end of each
    // frame; it only detects if the app left FBO 0 bound at the end of the
    // frame.  We could still miss a mid-frame binding of FBO 0.  The best way
    // to test for that is to read back FBO 0 at the end of the app and test if
    // any pixel is non-zero:
    if (mUseFBOPair && dest) {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        const int32_t size = 4 * mWindowWidth * mWindowHeight;
        const uint8_t* onscreenData = new uint8_t[size];

        glReadPixels(0,
                     0,
                     mWindowWidth,
                     mWindowHeight,
                     GL_RGBA,
                     GL_UNSIGNED_BYTE,
                     (GLvoid*)onscreenData);

        const uint8_t* ptr = onscreenData;
        for (int i = 0; i < size; i++) {
            if (*(ptr++)) {
                return false;
            }
        }

        delete[] onscreenData;

        glBindFramebuffer(GL_FRAMEBUFFER, getMainFBO());
    }

    w = mUseFBOPair ? mFBOWidth : mWindowWidth;
    h = mUseFBOPair ? mFBOHeight : mWindowHeight;

    if (dest) {
        glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)dest);
    }

    return true;
}
