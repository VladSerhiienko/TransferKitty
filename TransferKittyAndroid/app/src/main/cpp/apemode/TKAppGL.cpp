#include "TKAppGL.h"

#include "TKGL.h"
#include "TKNuklearRendererGL.h"

#include <NvFramerateCounter.h>
#include <NvGLSLProgram.h>
#include <NvAssetLoader.h>
#include "NV/NvLogs.h"

nk_context *nk_apemode_init();
void nk_apemode_shutdown();
void nk_apemode_font_stash_begin(struct nk_font_atlas **atlas);
void nk_apemode_font_stash_end();

void nk_apemode_new_frame(float width,
                          float height,
                          float display_width,
                          float display_height);

void nk_apemode_render(enum nk_anti_aliasing,
                       int max_vertex_buffer,
                       int max_element_buffer);

using namespace apemode;

namespace {
//void debugMessageCallback(GLenum source,
//                          GLenum type,
//                          GLuint id,
//                          GLenum severity,
//                          GLsizei length,
//                          const GLchar *message,
//                          const void *userParam) {
//    std::string s(message, length);
//    LOGE("-------------------------------------");
//    LOGE("------------ GL Callback ------------");
//    LOGE("-------------------------------------");
//    LOGE("source: %u, type: %u, severity: %u", source, type, severity);
//    LOGE("message: %s", s.c_str());
//    LOGE("-------------------------------------");
//}
} // namespace

TKAppGL::TKAppGL() {
//    m_transformer->setTranslationVec(nv::vec3f(0.0f, 0.0f, -2.2f));
//    m_transformer->setRotationVec(nv::vec3f(NV_PI * 0.35f, 0.0f, 0.0f));

    // Required in all subclasses to avoid silent link issues
    forceLinkHack();
}

TKAppGL::~TKAppGL() {
    LOGI("TKAppGL: destroyed\n");
}

void TKAppGL::configurationCallback(NvGLConfiguration &config) {
    config.depthBits = 24;
    config.stencilBits = 8;

    // TODO: ES2 should be enough.
    // config.apiVer = NvGLAPIVersionES2();
    config.apiVer = NvGLAPIVersionES3_1();
}

void TKAppGL::initRendering() {
    CHECK_GL_ERROR();
    setAppTitle("TKAppGL");

    NvAssetLoaderAddSearchPath("../app-ezri/src/main/");
    NvAssetLoaderAddSearchPath("../../app-ezri/src/main/");
    NvAssetLoaderAddSearchPath("../../../app-ezri/src/main/");

    mNk = CHECKED_GL(nk_apemode_init());
}

void TKAppGL::shutdownRendering() {
    // destroy other resources here
    nk_apemode_shutdown();
}

void TKAppGL::reshape(int32_t width, int32_t height) {
    TKSampleAppGL::reshape(width, height);
    glViewport(0, 0, (GLint)width, (GLint)height);
}

void TKAppGL::draw() {
    CHECK_GL_ERROR();

    float width = getGLContext()->width();
    float height = getGLContext()->height();

    CHECKED_GL(glViewport(0, 0, width, height));
    CHECKED_GL(glClearColor(0.2, 0.2, 0.2, 1));
    CHECKED_GL(glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
    CHECKED_GL(glDisable(GL_BLEND));
    CHECKED_GL(glDisable(GL_CULL_FACE));
    CHECKED_GL(glDisable(GL_DEPTH_TEST));

    nk_apemode_new_frame(getGLContext()->width(),
                         getGLContext()->height(),
                         getGLContext()->width(),
                         getGLContext()->height());

    auto ctx = static_cast<nk_context *>(mNk);
    if (nk_begin(ctx,
                 "FPS",
                 nk_rect(getGLContext()->width() - 161,
                         getGLContext()->height() - 51,
                         156,
                         46),
                 NK_WINDOW_NO_SCROLLBAR)) {
        nk_layout_row_dynamic(ctx, 42, 1);
        nk_labelf(
            ctx, NK_TEXT_LEFT, "FPS: %.2f", getFramerate()->getMeanFramerate());
    }
    nk_end(ctx);

    nk_apemode_render(NK_ANTI_ALIASING_ON, 65536 << 2, 65536 << 2);
    CHECK_GL_ERROR();
}

bool TKAppGL::handlePointerInput(NvInputDeviceType::Enum device,
                                 NvPointerActionType::Enum action,
                                 uint32_t modifiers,
                                 int32_t count,
                                 NvPointerEvent *points,
                                 int64_t timestamp) {
    LOGI("TKAppGL::handlePointerInput: count: %i", count);

    if (count > 0 && points) {
        if (auto pNkCtx = static_cast<nk_context *>(mNk)) {
            float position[2] = {points[0].m_x, points[0].m_y};
            switch (action) {
                case NvPointerActionType::DOWN: {
                    nk_input_begin(pNkCtx);
                    nk_input_motion(pNkCtx, position[0], position[1]);
                    nk_input_button(
                        pNkCtx, NK_BUTTON_LEFT, position[0], position[1], 1);
                    nk_input_end(pNkCtx);
                } break;
                case NvPointerActionType::UP: {
                    nk_input_begin(pNkCtx);
                    nk_input_button(
                        pNkCtx, NK_BUTTON_LEFT, position[0], position[1], 0);
                    nk_input_motion(pNkCtx, 0, 0);
                    nk_input_end(pNkCtx);
                } break;
                case NvPointerActionType::MOTION: {
                    nk_input_begin(pNkCtx);
                    nk_input_motion(pNkCtx, position[0], position[1]);
                    nk_input_end(pNkCtx);
                } break;
            }
        }
    }

    return false;
}

bool TKAppGL::handleKeyInput(uint32_t code, NvKeyActionType::Enum action) {
    if (action == NvKeyActionType::Enum::DOWN) {
        LOGI("TKAppGL::handleKeyInput: code=%u (%lc)", code, (uint16_t)code);
    }

    // LOGI( "TKAppGL::handleKeyInput: action=%u", action );
    return false;
}

bool TKAppGL::handleCharacterInput(uint8_t c) {
    LOGI("TKAppGL::handleCharacterInput: c=%u (x%04x) (%lc)",
         (uint32_t)c,
         (uint32_t)c,
         (uint16_t)c);
    return false;
}

bool TKAppGL::handleGamepadChanged(uint32_t changedPadFlags) {
    LOGI("TKAppGL::handleGamepadChanged: changedPadFlags=%u", changedPadFlags);
    return false;
}

bool TKAppGL::handleGamepadButtonChanged(uint32_t button, bool down) {
    LOGI("TKAppGL::handleGamepadButtonChanged: button=%u", button);
    LOGI("TKAppGL::handleGamepadButtonChanged: down=%u", (uint32_t)down);
    return false;
}

void TKAppGL::setPlatformContext(NvPlatformContext *platform) {
    TKAppBase::setPlatformContext(platform);

#if defined(ANDROID) && false
    Engine *engine = static_cast<Engine *>(getPlatformContext());
#endif

    // engine->mApp->activity->assetManager;
    // Engine* engine = static_cast< Engine* >( getPlatformContext( ) );
    // JNIEnv* env    = engine->mApp->appThreadEnv;
}

TKAppBase *TKAppFactory() {
    return new TKAppGL();
}
