#pragma once

#include <jni.h>
#include "KHR/khrplatform.h"
#include "NV/NvMath.h"
#include "NvAppBase/gl/NvSampleAppGL.h"
#include "NvGamepad/NvGamepad.h"

class NvStopWatch;
class NvGLSLProgram;
class NvFramerateCounter;

#pragma region Missing OpenGL ES
typedef void ( *PFNGLFRAMEBUFFERTEXTUREMULTIVIEWOVR )( GLenum, GLenum, GLuint, GLint, GLint, GLsizei );
typedef void ( *PFNGLFRAMEBUFFERTEXTUREMULTISAMPLEMULTIVIEWOVR )( GLenum, GLenum, GLuint, GLint, GLint, GLsizei );
typedef void ( *PFNGLDEBUGMESSAGECALLBACKKHRPROC )( GLDEBUGPROCKHR callback, const void* userParam );
typedef void ( *PFNGLDEBUGMESSAGECONTROLKHRPROC )( GLenum source, GLenum type, GLenum severity, GLsizei count, const GLuint* ids, GLboolean enabled );
#pragma endregion

namespace apemode {
    class EzriAppGL : public NvSampleAppGL {
    public:
        EzriAppGL( );
        virtual ~EzriAppGL( );

        void initRendering( ) override;
        void shutdownRendering( ) override;
        void draw( ) override;
        void reshape( int32_t width, int32_t height ) override;
        void configurationCallback( NvGLConfiguration& config ) override;

        bool handlePointerInput( NvInputDeviceType::Enum   device,
                                 NvPointerActionType::Enum action,
                                 uint32_t                  modifiers,
                                 int32_t                   count,
                                 NvPointerEvent*           points,
                                 int64_t                   timestamp = 0 ) override;
        bool handleKeyInput( uint32_t code, NvKeyActionType::Enum action ) override;
        bool handleCharacterInput( uint8_t c ) override;
        bool handleGamepadChanged( uint32_t changedPadFlags ) override;
        bool handleGamepadButtonChanged( uint32_t button, bool down ) override;
        void setPlatformContext( NvPlatformContext* platform ) override;

        void* mNk = nullptr;
    };
}
