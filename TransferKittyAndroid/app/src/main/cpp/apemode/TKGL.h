//
// Created by Vlad Serhiienko on 2019-10-18.
//

#pragma once
#ifndef TRANSFERKITTY_TKGL_H
#define TRANSFERKITTY_TKGL_H

#include "KHR/khrplatform.h"
#include <GLES3/gl3.h>

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

typedef void (*PFNGLFRAMEBUFFERTEXTUREMULTIVIEWOVR)(
        GLenum, GLenum, GLuint, GLint, GLint, GLsizei);
typedef void (*PFNGLFRAMEBUFFERTEXTUREMULTISAMPLEMULTIVIEWOVR)(
        GLenum, GLenum, GLuint, GLint, GLint, GLsizei);
typedef void (*PFNGLDEBUGMESSAGECALLBACKKHRPROC)(GLDEBUGPROCKHR callback,
                                                 const void *userParam);
typedef void (*PFNGLDEBUGMESSAGECONTROLKHRPROC)(GLenum source,
                                                GLenum type,
                                                GLenum severity,
                                                GLsizei count,
                                                const GLuint *ids,
                                                GLboolean enabled);

#endif //TRANSFERKITTY_TKGL_H
