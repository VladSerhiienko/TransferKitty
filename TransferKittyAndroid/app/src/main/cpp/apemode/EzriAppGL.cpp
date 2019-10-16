#include "EzriAppGL.h"

#ifdef ANDROID
//#include <GLES/gl.h>
//#include <GLES2/gl2.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <EngineAndroid.h>
#include <NvAndroidNativeAppGlue.h>
#endif

//#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include <random>
#include <ctime>

#include "NV/NvLogs.h"
#include "NvAppBase/NvInputTransformer.h"
#include <NvFramerateCounter.h>
#include <NvGLSLProgram.h>

#include <NuklearGL.h>
#include <NvAssetLoader.h>

#ifndef GL_UNPACK_ROW_LENGTH
#define GL_UNPACK_ROW_LENGTH GL_UNPACK_ROW_LENGTH_EXT
#endif

#ifndef GL_UNPACK_SKIP_ROWS
#define GL_UNPACK_SKIP_ROWS GL_UNPACK_SKIP_ROWS_EXT
#endif

#ifndef GL_UNPACK_SKIP_PIXELS
#define GL_UNPACK_SKIP_PIXELS GL_UNPACK_SKIP_PIXELS_EXT
#endif

#ifndef GL_RED
#define GL_RED GL_RED_EXT
#endif

#ifndef GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR
#define GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR 0x9630
#define GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR 0x9632
#endif

#ifndef GL_TEXTURE_2D_ARRAY_EXT
#define GL_TEXTURE_2D_ARRAY_EXT 0x8C1A
#endif

#ifndef GL_DRAW_FRAMEBUFFER
#define GL_DRAW_FRAMEBUFFER 0x8CA9
#endif

#ifndef GL_DEBUG_OUTPUT_SYNCHRONOUS_KHR
#define GL_DEBUG_OUTPUT_SYNCHRONOUS_KHR 0x8242
#endif

#ifndef GL_MAX_VIEWS_OVR
#define GL_MAX_VIEWS_OVR 0x9631
#endif

#include <NvImage.h>
#include <NvImageGL.h>

nk_context* nk_apemode_init( );
void        nk_apemode_shutdown( );
void nk_apemode_font_stash_begin( struct nk_font_atlas** atlas );
void nk_apemode_font_stash_end( );
void nk_apemode_new_frame( float width, float height, float display_width, float display_height );
void nk_apemode_render( enum nk_anti_aliasing, int max_vertex_buffer, int max_element_buffer );

using namespace apemode;

float generateRandomFloat( float lower = 0.0f, float upper = 1.0f ) {
    static std::default_random_engine       e;
    static std::uniform_real_distribution<> dis( 0, 1 ); // range 0 - 1
    return dis( e ) * ( upper - lower ) + lower;
}

namespace {
    void debugMessageCallback(
        GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam ) {

        std::string s( message, length );
        LOGE( "-------------------------------------" );
        LOGE( "------------ GL Callback ------------" );
        LOGE( "-------------------------------------" );
        LOGE( "source: %u, type: %u, severity: %u", source, type, severity );
        LOGE( "message: %s", s.c_str( ) );
        LOGE( "-------------------------------------" );
    }

} // namespace

EzriAppGL::EzriAppGL( ) {
    m_transformer->setTranslationVec( nv::vec3f( 0.0f, 0.0f, -2.2f ) );
    m_transformer->setRotationVec( nv::vec3f( NV_PI * 0.35f, 0.0f, 0.0f ) );

    // Required in all subclasses to avoid silent link issues
    forceLinkHack( );
}

EzriAppGL::~EzriAppGL( ) {
    LOGI( "EzriAppGL: destroyed\n" );
}

void EzriAppGL::configurationCallback( NvGLConfiguration& config ) {
    config.depthBits   = 24;
    config.stencilBits = 8;
    config.apiVer      = NvGLAPIVersionES3_1( );
    // config.apiVer      = NvGLAPIVersionES2( );
}

void EzriAppGL::initRendering( ) {
    CHECK_GL_ERROR( );
    setAppTitle( "EzriAppGL" );

    NvAssetLoaderAddSearchPath( "../app-ezri/src/main/" );
    NvAssetLoaderAddSearchPath( "../../app-ezri/src/main/" );
    NvAssetLoaderAddSearchPath( "../../../app-ezri/src/main/" );

    mNk = CHECKED_GL( nk_apemode_init( ) );
}

void EzriAppGL::shutdownRendering( ) {
    // destroy other resources here
    nk_apemode_shutdown( );
}

void EzriAppGL::reshape( int32_t width, int32_t height ) {
    NvSampleAppGL::reshape( width, height );
    glViewport( 0, 0, (GLint) width, (GLint) height );
}


void EzriAppGL::draw( ) {
    CHECK_GL_ERROR( );

    float    width                = getGLContext( )->width( );
    float    height               = getGLContext( )->height( );
    float    halfWidth            = width * 0.5f;
    float    halfHeight           = height * 0.5f;
    bool     bIsVerticalView      = width < height;

    CHECKED_GL(glViewport(0, 0, width, height));
    CHECKED_GL(glClearColor(0.2, 0.2, 0.2, 1));
    CHECKED_GL(glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
    CHECKED_GL(glDisable(GL_BLEND));
    CHECKED_GL(glDisable(GL_CULL_FACE));
    CHECKED_GL(glDisable(GL_DEPTH_TEST));

    nk_apemode_new_frame(getGLContext( )->width( ), getGLContext( )->height( ), getGLContext( )->width( ), getGLContext( )->height( ) );

    auto ctx = static_cast< nk_context* >( mNk );
    if ( nk_begin( ctx, "FPS", nk_rect( getGLContext( )->width( ) - 161, getGLContext( )->height( ) - 51, 156, 46 ), NK_WINDOW_NO_SCROLLBAR ) ) {
        nk_layout_row_dynamic( ctx, 42, 1 );
        nk_labelf( ctx, NK_TEXT_LEFT, "FPS: %.2f", getFramerate( )->getMeanFramerate( ) );
    }
    nk_end( ctx );

    nk_apemode_render(NK_ANTI_ALIASING_ON, 65536 << 2, 65536 << 2);
    CHECK_GL_ERROR();
}

bool EzriAppGL::handlePointerInput( NvInputDeviceType::Enum   device,
                                    NvPointerActionType::Enum action,
                                    uint32_t                  modifiers,
                                    int32_t                   count,
                                    NvPointerEvent*           points,
                                    int64_t                   timestamp ) {
    LOGI("EzriAppGL::handlePointerInput: count: %i", count);

    if ( count > 0 && points ) {
        if ( auto pNkCtx = static_cast< nk_context* >( mNk ) ) {
            float position[ 2 ] = {points[ 0 ].m_x, points[ 0 ].m_y};
            switch ( action ) {
                case NvPointerActionType::DOWN: {
                    nk_input_begin( pNkCtx );
                    nk_input_motion( pNkCtx, position[ 0 ], position[ 1 ] );
                    nk_input_button( pNkCtx, NK_BUTTON_LEFT, position[ 0 ], position[ 1 ], 1 );
                    nk_input_end( pNkCtx );
                } break;
                case NvPointerActionType::UP: {
                    nk_input_begin( pNkCtx );
                    nk_input_button( pNkCtx, NK_BUTTON_LEFT, position[ 0 ], position[ 1 ], 0 );
                    nk_input_motion( pNkCtx, 0, 0 );
                    nk_input_end( pNkCtx );
                } break;
                case NvPointerActionType::MOTION: {
                    nk_input_begin( pNkCtx );
                    nk_input_motion( pNkCtx, position[ 0 ], position[ 1 ] );
                    nk_input_end( pNkCtx );
                } break;
            }
        }
    }

    return false;
}

bool EzriAppGL::handleKeyInput( uint32_t code, NvKeyActionType::Enum action ) {
    if (action == NvKeyActionType::Enum::DOWN) {
        LOGI( "EzriAppGL::handleKeyInput: code=%u (%lc)", code, (uint16_t) code );
    }

    // LOGI( "EzriAppGL::handleKeyInput: action=%u", action );
    return false;
}

bool EzriAppGL::handleCharacterInput( uint8_t c ) {
    LOGI( "EzriAppGL::handleCharacterInput: c=%u (x%04x) (%lc)", (uint32_t) c, (uint32_t) c, (uint16_t) c );
    return false;
}

bool EzriAppGL::handleGamepadChanged( uint32_t changedPadFlags ) {
    LOGI( "EzriAppGL::handleGamepadChanged: changedPadFlags=%u", changedPadFlags );
    return false;
}

bool EzriAppGL::handleGamepadButtonChanged( uint32_t button, bool down ) {
    LOGI( "EzriAppGL::handleGamepadButtonChanged: button=%u", button );
    LOGI( "EzriAppGL::handleGamepadButtonChanged: down=%u", (uint32_t) down );
    return false;
}

void EzriAppGL::setPlatformContext( NvPlatformContext* platform ) {
    NvAppBase::setPlatformContext( platform );

    #if defined(ANDROID) && false
    Engine* engine = static_cast< Engine* >( getPlatformContext( ) );
    #endif

//    engine->mApp->activity->assetManager;
//    Engine* engine = static_cast< Engine* >( getPlatformContext( ) );
//    JNIEnv* env    = engine->mApp->appThreadEnv;

}

NvAppBase* NvAppFactory( ) {
    return new EzriAppGL( );
}
