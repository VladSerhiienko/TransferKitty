

#define NK_IMPLEMENTATION
#include "TKNuklearRendererGL.h"
#include <NvFoundation/NvIntrinsics.h>
#include <NvGLSLProgram.h>
#include <vector>

#ifndef _WIN32
#include <GLES2/gl2.h>
#endif

NK_API struct nk_context *nk_apemode_init();
NK_API void nk_apemode_shutdown(void);
NK_API void nk_apemode_font_stash_begin(struct nk_font_atlas **atlas);
NK_API void nk_apemode_font_stash_end(void);
NK_API void nk_apemode_new_frame(void);
NK_API void nk_apemode_render(enum nk_anti_aliasing,
                              int max_vertex_buffer,
                              int max_element_buffer);

NK_API void nk_apemode_setup_style();
NK_API void nk_apemode_device_destroy(void);
NK_API void nk_apemode_device_create(void);

NK_API void nk_apemode_char_callback(unsigned int codepoint);
NK_API void nk_gflw3_scroll_callback(double xoff, double yoff);

#ifndef NK_GLFW_TEXT_MAX
#define NK_GLFW_TEXT_MAX 256
#endif

struct nk_apemode_device {
    nk_buffer cmds;
    nk_draw_null_texture null;
    GLuint vbo, ebo;
    // GLuint                 prog;
    // GLuint                 vert_shdr;
    // GLuint                 frag_shdr;
    NvGLSLProgram *program;
    GLint attrib_pos;
    GLint attrib_uv;
    GLint attrib_col;
    GLint vertex_stride;
    GLint offset_pos;
    GLint offset_uv;
    GLint offset_col;
    GLint uniform_tex;
    GLint uniform_proj;
    GLuint font_tex;
    std::vector<uint8_t> buffer_pool;
};

struct nk_apemode_vertex {
    float position[2];
    float uv[2];
    nk_byte col[4];
};

struct nk_apemode {
    float width, height;
    float display_width, display_height;
    nk_apemode_device ogl;
    nk_context ctx;
    nk_font_atlas atlas;
    struct nk_vec2 fb_scale;
    unsigned int text[NK_GLFW_TEXT_MAX];
    int text_len;
    struct nk_vec2 scroll;
};

static nk_apemode nk_apemode_global_state;

#ifdef __APPLE__
#define NK_SHADER_VERSION "#version 150\n"
#else
#define NK_SHADER_VERSION "#version 300 es\n"
#endif

NK_API void nk_apemode_device_create(void) {
    GLint status;
    static const GLchar *vertex_shader =
        "#version 100\n"
        "precision mediump float;\n"
        "uniform highp mat4 ProjMtx;\n"
        "attribute highp vec2 Position;\n"
        "attribute mediump vec2 TexCoord;\n"
        "attribute lowp vec4 Color;\n"
        "varying mediump vec2 Frag_UV;\n"
        "varying lowp vec4 Frag_Color;\n"
        "void main() {\n"
        "   Frag_UV = TexCoord;\n"
        "   Frag_Color = Color;\n"
        "   gl_Position = ProjMtx * vec4(Position.xy, 0, 1);\n"
        "}\n";
    static const GLchar *fragment_shader =
        "#version 100\n"
        "precision mediump float;\n"
        "uniform lowp sampler2D Texture;\n"
        "varying mediump vec2 Frag_UV;\n"
        "varying lowp vec4 Frag_Color;\n"
        "void main(){\n"
        "   gl_FragColor = Frag_Color * texture2D(Texture, Frag_UV.st);\n"
        "}\n";

    struct nk_apemode_device *dev = &nk_apemode_global_state.ogl;
    nk_buffer_init_default(&dev->cmds);
    dev->program =
        NvGLSLProgram::createFromStrings(vertex_shader, fragment_shader, 0);

    // dev->prog      = glCreateProgram( );
    // dev->vert_shdr = glCreateShader( GL_VERTEX_SHADER );
    // dev->frag_shdr = glCreateShader( GL_FRAGMENT_SHADER );
    //    glShaderSource( dev->vert_shdr, 1, &vertex_shader, 0 );
    //    glShaderSource( dev->frag_shdr, 1, &fragment_shader, 0 );
    //    glCompileShader( dev->vert_shdr );
    //    glCompileShader( dev->frag_shdr );
    //    glGetShaderiv( dev->vert_shdr, GL_COMPILE_STATUS, &status );
    //    assert( status == GL_TRUE );
    //    glGetShaderiv( dev->frag_shdr, GL_COMPILE_STATUS, &status );
    //    assert( status == GL_TRUE );
    //    glAttachShader( dev->prog, dev->vert_shdr );
    //    glAttachShader( dev->prog, dev->frag_shdr );
    //    glLinkProgram( dev->prog );
    //    glGetProgramiv( dev->prog, GL_LINK_STATUS, &status );
    //    assert( status == GL_TRUE );

    dev->uniform_tex =
        glGetUniformLocation(dev->program->getProgram(), "Texture");
    dev->uniform_proj =
        glGetUniformLocation(dev->program->getProgram(), "ProjMtx");
    dev->attrib_pos =
        glGetAttribLocation(dev->program->getProgram(), "Position");
    dev->attrib_uv =
        glGetAttribLocation(dev->program->getProgram(), "TexCoord");
    dev->attrib_col = glGetAttribLocation(dev->program->getProgram(), "Color");

    dev->vertex_stride = sizeof(struct nk_apemode_vertex);
    dev->offset_pos = NV_OFFSET_OF(struct nk_apemode_vertex, position);
    dev->offset_uv = NV_OFFSET_OF(struct nk_apemode_vertex, uv);
    dev->offset_col = NV_OFFSET_OF(struct nk_apemode_vertex, col);

    glGenBuffers(1, &dev->vbo);
    glGenBuffers(1, &dev->ebo);

    //        glBindBuffer( GL_ARRAY_BUFFER, dev->vbo );
    //        glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, dev->ebo );
    //
    //        glEnableVertexAttribArray( (GLuint) dev->attrib_pos );
    //        glEnableVertexAttribArray( (GLuint) dev->attrib_uv );
    //        glEnableVertexAttribArray( (GLuint) dev->attrib_col );
    //
    //        glVertexAttribPointer( (GLuint) dev->attrib_pos, 2, GL_FLOAT,
    //        GL_FALSE, vs, (void *) vp );
    //        glVertexAttribPointer( (GLuint) dev->attrib_uv, 2, GL_FLOAT,
    //        GL_FALSE, vs, (void *) vt );
    //        glVertexAttribPointer( (GLuint) dev->attrib_col, 4,
    //        GL_UNSIGNED_BYTE, GL_TRUE, vs, (void *) vc );

    nk_apemode_setup_style();

    glBindTexture(GL_TEXTURE_2D, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

NK_INTERN void nk_apemode_device_upload_atlas(const void *image,
                                              int width,
                                              int height) {
    struct nk_apemode_device *dev = &nk_apemode_global_state.ogl;
    glGenTextures(1, &dev->font_tex);
    glBindTexture(GL_TEXTURE_2D, dev->font_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGBA,
                 (GLsizei)width,
                 (GLsizei)height,
                 0,
                 GL_RGBA,
                 GL_UNSIGNED_BYTE,
                 image);
}

NK_API void nk_apemode_device_destroy(void) {
    struct nk_apemode_device *dev = &nk_apemode_global_state.ogl;

    delete dev->program;
    dev->program = nullptr;

    //    glDetachShader( dev->prog, dev->vert_shdr );
    //    glDetachShader( dev->prog, dev->frag_shdr );
    //    glDeleteShader( dev->vert_shdr );
    //    glDeleteShader( dev->frag_shdr );
    //    glDeleteProgram( dev->prog );
    glDeleteTextures(1, &dev->font_tex);
    glDeleteBuffers(1, &dev->vbo);
    glDeleteBuffers(1, &dev->ebo);
    nk_buffer_free(&dev->cmds);
}

NK_API void nk_apemode_render(enum nk_anti_aliasing AA,
                              int max_vertex_buffer,
                              int max_element_buffer) {
    struct nk_apemode_device *dev = &nk_apemode_global_state.ogl;

    const int total_buffer_size = max_vertex_buffer + max_element_buffer;
    if (nk_apemode_global_state.ogl.buffer_pool.size() < total_buffer_size)
        nk_apemode_global_state.ogl.buffer_pool.resize(total_buffer_size);

    GLfloat ortho[4][4] = {
        {2.0f, 0.0f, 0.0f, 0.0f},  //
        {0.0f, -2.0f, 0.0f, 0.0f}, //
        {0.0f, 0.0f, -1.0f, 0.0f}, //
        {-1.0f, 1.0f, 0.0f, 1.0f}, //
    };
    ortho[0][0] /= (GLfloat)nk_apemode_global_state.width;
    ortho[1][1] /= (GLfloat)nk_apemode_global_state.height;

    /* setup global state */
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glActiveTexture(GL_TEXTURE0);

    /* setup program */
    dev->program->enable();
    //    glUseProgram( dev->prog );
    glUniform1i(dev->uniform_tex, 0);
    glUniformMatrix4fv(dev->uniform_proj, 1, GL_FALSE, &ortho[0][0]);
    glViewport(0,
               0,
               (GLsizei)nk_apemode_global_state.display_width,
               (GLsizei)nk_apemode_global_state.display_height);
    {
        /* convert from command queue into draw list and draw to screen */
        const nk_draw_command *cmd = nullptr;
        void *vertices = nullptr;
        void *elements = nullptr;
        const nk_draw_index *offset = nullptr;

        /* load draw vertices & elements directly into vertex + element buffer
         */
        vertices = nk_apemode_global_state.ogl.buffer_pool.data();
        elements =
            nk_apemode_global_state.ogl.buffer_pool.data() + max_vertex_buffer;

        /* fill convert configuration */
        struct nk_convert_config config;
        static const struct nk_draw_vertex_layout_element vertex_layout[] = {
            {NK_VERTEX_POSITION,
             NK_FORMAT_FLOAT,
             NK_OFFSETOF(struct nk_apemode_vertex, position)},
            {NK_VERTEX_TEXCOORD,
             NK_FORMAT_FLOAT,
             NK_OFFSETOF(struct nk_apemode_vertex, uv)},
            {NK_VERTEX_COLOR,
             NK_FORMAT_R8G8B8A8,
             NK_OFFSETOF(struct nk_apemode_vertex, col)},
            {NK_VERTEX_LAYOUT_END}};

        NK_MEMSET(&config, 0, sizeof(config));
        config.vertex_layout = vertex_layout;
        config.vertex_size = sizeof(struct nk_apemode_vertex);
        config.vertex_alignment = NK_ALIGNOF(struct nk_apemode_vertex);
        config.null = dev->null;
        config.circle_segment_count = 22;
        config.curve_segment_count = 22;
        config.arc_segment_count = 22;
        config.global_alpha = 1.0f;
        config.shape_AA = AA;
        config.line_AA = AA;

        /* setup buffers to load vertices and elements */
        struct nk_buffer vbuf, ebuf;
        nk_buffer_init_fixed(&vbuf, vertices, (size_t)max_vertex_buffer);
        nk_buffer_init_fixed(&ebuf, elements, (size_t)max_element_buffer);
        nk_convert(
            &nk_apemode_global_state.ctx, &dev->cmds, &vbuf, &ebuf, &config);

        /* allocate vertex and element buffer */
        glBindBuffer(GL_ARRAY_BUFFER, dev->vbo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, dev->ebo);
        glBufferData(GL_ARRAY_BUFFER, vbuf.size, vertices, GL_STREAM_DRAW);
        glBufferData(
            GL_ELEMENT_ARRAY_BUFFER, ebuf.size, elements, GL_STREAM_DRAW);

        glEnableVertexAttribArray((GLuint)dev->attrib_pos);
        glEnableVertexAttribArray((GLuint)dev->attrib_uv);
        glEnableVertexAttribArray((GLuint)dev->attrib_col);

        glVertexAttribPointer((GLuint)dev->attrib_pos,
                              2,
                              GL_FLOAT,
                              GL_FALSE,
                              dev->vertex_stride,
                              (void *)dev->offset_pos);
        glVertexAttribPointer((GLuint)dev->attrib_uv,
                              2,
                              GL_FLOAT,
                              GL_FALSE,
                              dev->vertex_stride,
                              (void *)dev->offset_uv);
        glVertexAttribPointer((GLuint)dev->attrib_col,
                              4,
                              GL_UNSIGNED_BYTE,
                              GL_TRUE,
                              dev->vertex_stride,
                              (void *)dev->offset_col);

        /* iterate over and execute each draw command */
        nk_draw_foreach(cmd, &nk_apemode_global_state.ctx, &dev->cmds) {
            if (!cmd->elem_count)
                continue;
            glBindTexture(GL_TEXTURE_2D, (GLuint)cmd->texture.id);
            glScissor(
                (GLint)(cmd->clip_rect.x * nk_apemode_global_state.fb_scale.x),
                (GLint)((nk_apemode_global_state.height -
                         (GLint)(cmd->clip_rect.y + cmd->clip_rect.h)) *
                        nk_apemode_global_state.fb_scale.y),
                (GLint)(cmd->clip_rect.w * nk_apemode_global_state.fb_scale.x),
                (GLint)(cmd->clip_rect.h * nk_apemode_global_state.fb_scale.y));
            glDrawElements(GL_TRIANGLES,
                           (GLsizei)cmd->elem_count,
                           GL_UNSIGNED_SHORT,
                           offset);
            offset += cmd->elem_count;
        }
        nk_clear(&nk_apemode_global_state.ctx);
    }

    /* default OpenGL state */
    //    glUseProgram( 0 );
    dev->program->disable();
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glDisable(GL_BLEND);
    glDisable(GL_SCISSOR_TEST);
}

NK_API void nk_apemode_char_callback(unsigned int codepoint) {
    if (nk_apemode_global_state.text_len < NK_GLFW_TEXT_MAX)
        nk_apemode_global_state.text[nk_apemode_global_state.text_len++] =
            codepoint;
}

NK_API void nk_gflw3_scroll_callback(double xoff, double yoff) {
    (void)xoff;
    nk_apemode_global_state.scroll.x += (float)xoff;
    nk_apemode_global_state.scroll.y += (float)yoff;
}

NK_INTERN void nk_apemode_clipbard_paste(nk_handle usr,
                                         struct nk_text_edit *edit) {
    //    const char *text = glfwGetClipboardString( nk_apemode_global_state.win
    //    ); if ( text )
    //        nk_textedit_paste( edit, text, nk_strlen( text ) );
    //    (void) usr;
}

NK_INTERN void nk_apemode_clipbard_copy(nk_handle usr,
                                        const char *text,
                                        int len) {
    //    char *str = 0;
    //    (void) usr;
    //    if ( !len )
    //        return;
    //    str = (char *) malloc( (size_t) len + 1 );
    //    if ( !str )
    //        return;
    //    memcpy( str, text, (size_t) len );
    //    str[ len ] = '\0';
    //    glfwSetClipboardString( nk_apemode_global_state.win, str );
    //    free( str );
}

NK_API struct nk_context *nk_apemode_init() {
    //    nk_apemode_global_state.win = win;
    //    if ( init_state == NK_GLFW3_INSTALL_CALLBACKS ) {
    //        glfwSetScrollCallback( win, nk_gflw3_scroll_callback );
    //        glfwSetCharCallback( win, nk_apemode_char_callback );
    //    }

    nk_init_default(&nk_apemode_global_state.ctx, 0);
    nk_apemode_global_state.ctx.clip.copy = nk_apemode_clipbard_copy;
    nk_apemode_global_state.ctx.clip.paste = nk_apemode_clipbard_paste;
    nk_apemode_global_state.ctx.clip.userdata = nk_handle_ptr(0);
    nk_apemode_device_create();
    return &nk_apemode_global_state.ctx;
}

NK_API void nk_apemode_font_stash_begin(struct nk_font_atlas **atlas) {
    nk_font_atlas_init_default(&nk_apemode_global_state.atlas);
    nk_font_atlas_begin(&nk_apemode_global_state.atlas);
    *atlas = &nk_apemode_global_state.atlas;
}

NK_API void nk_apemode_font_stash_end(void) {
    const void *image;
    int w, h;
    image = nk_font_atlas_bake(
        &nk_apemode_global_state.atlas, &w, &h, NK_FONT_ATLAS_RGBA32);
    nk_apemode_device_upload_atlas(image, w, h);
    nk_font_atlas_end(&nk_apemode_global_state.atlas,
                      nk_handle_id((int)nk_apemode_global_state.ogl.font_tex),
                      &nk_apemode_global_state.ogl.null);
    if (nk_apemode_global_state.atlas.default_font)
        nk_style_set_font(&nk_apemode_global_state.ctx,
                          &nk_apemode_global_state.atlas.default_font->handle);
}

NK_API void nk_apemode_new_frame(float width,
                                 float height,
                                 float display_width,
                                 float display_height) {
    int i;
    double x, y;
    struct nk_context *ctx = &nk_apemode_global_state.ctx;
    nk_apemode_global_state.width = width;
    nk_apemode_global_state.height = height;
    nk_apemode_global_state.display_width = display_width;
    nk_apemode_global_state.display_height = display_height;
    nk_apemode_global_state.fb_scale.x = display_width / width;
    nk_apemode_global_state.fb_scale.y = display_height / height;

    // nk_input_begin( ctx );
    //    for ( i = 0; i < nk_apemode_global_state.text_len; ++i )
    //        nk_input_unicode( ctx, nk_apemode_global_state.text[ i ] );
    //
    //    /* optional grabbing behavior */
    //    if ( ctx->input.mouse.grab )
    //        glfwSetInputMode( nk_apemode_global_state.win, GLFW_CURSOR,
    //        GLFW_CURSOR_HIDDEN );
    //    else if ( ctx->input.mouse.ungrab )
    //        glfwSetInputMode( nk_apemode_global_state.win, GLFW_CURSOR,
    //        GLFW_CURSOR_NORMAL );
    //
    //    nk_input_key( ctx, NK_KEY_DEL, glfwGetKey( win, GLFW_KEY_DELETE ) ==
    //    GLFW_PRESS ); nk_input_key( ctx, NK_KEY_ENTER, glfwGetKey( win,
    //    GLFW_KEY_ENTER ) == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_TAB,
    //    glfwGetKey( win, GLFW_KEY_TAB ) == GLFW_PRESS ); nk_input_key( ctx,
    //    NK_KEY_BACKSPACE, glfwGetKey( win, GLFW_KEY_BACKSPACE ) == GLFW_PRESS
    //    ); nk_input_key( ctx, NK_KEY_UP, glfwGetKey( win, GLFW_KEY_UP ) ==
    //    GLFW_PRESS ); nk_input_key( ctx, NK_KEY_DOWN, glfwGetKey( win,
    //    GLFW_KEY_DOWN ) == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_TEXT_START,
    //    glfwGetKey( win, GLFW_KEY_HOME ) == GLFW_PRESS ); nk_input_key( ctx,
    //    NK_KEY_TEXT_END, glfwGetKey( win, GLFW_KEY_END ) == GLFW_PRESS );
    //    nk_input_key( ctx, NK_KEY_SCROLL_START, glfwGetKey( win, GLFW_KEY_HOME
    //    ) == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_SCROLL_END, glfwGetKey(
    //    win, GLFW_KEY_END ) == GLFW_PRESS ); nk_input_key( ctx,
    //    NK_KEY_SCROLL_DOWN, glfwGetKey( win, GLFW_KEY_PAGE_DOWN ) ==
    //    GLFW_PRESS ); nk_input_key( ctx, NK_KEY_SCROLL_UP, glfwGetKey( win,
    //    GLFW_KEY_PAGE_UP ) == GLFW_PRESS ); nk_input_key(
    //        ctx,
    //        NK_KEY_SHIFT,
    //        glfwGetKey( win, GLFW_KEY_LEFT_SHIFT ) == GLFW_PRESS ||
    //        glfwGetKey( win, GLFW_KEY_RIGHT_SHIFT ) == GLFW_PRESS );
    //
    //    if ( glfwGetKey( win, GLFW_KEY_LEFT_CONTROL ) == GLFW_PRESS ||
    //    glfwGetKey( win, GLFW_KEY_RIGHT_CONTROL ) == GLFW_PRESS ) {
    //        nk_input_key( ctx, NK_KEY_COPY, glfwGetKey( win, GLFW_KEY_C ) ==
    //        GLFW_PRESS ); nk_input_key( ctx, NK_KEY_PASTE, glfwGetKey( win,
    //        GLFW_KEY_V ) == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_CUT,
    //        glfwGetKey( win, GLFW_KEY_X ) == GLFW_PRESS ); nk_input_key( ctx,
    //        NK_KEY_TEXT_UNDO, glfwGetKey( win, GLFW_KEY_Z ) == GLFW_PRESS );
    //        nk_input_key( ctx, NK_KEY_TEXT_REDO, glfwGetKey( win, GLFW_KEY_R )
    //        == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_TEXT_WORD_LEFT,
    //        glfwGetKey( win, GLFW_KEY_LEFT ) == GLFW_PRESS ); nk_input_key(
    //        ctx, NK_KEY_TEXT_WORD_RIGHT, glfwGetKey( win, GLFW_KEY_RIGHT ) ==
    //        GLFW_PRESS ); nk_input_key( ctx, NK_KEY_TEXT_LINE_START,
    //        glfwGetKey( win, GLFW_KEY_B ) == GLFW_PRESS ); nk_input_key( ctx,
    //        NK_KEY_TEXT_LINE_END, glfwGetKey( win, GLFW_KEY_E ) == GLFW_PRESS
    //        );
    //    } else {
    //        nk_input_key( ctx, NK_KEY_LEFT, glfwGetKey( win, GLFW_KEY_LEFT )
    //        == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_RIGHT, glfwGetKey( win,
    //        GLFW_KEY_RIGHT ) == GLFW_PRESS ); nk_input_key( ctx, NK_KEY_COPY,
    //        0 ); nk_input_key( ctx, NK_KEY_PASTE, 0 ); nk_input_key( ctx,
    //        NK_KEY_CUT, 0 ); nk_input_key( ctx, NK_KEY_SHIFT, 0 );
    //    }
    //
    //    glfwGetCursorPos( win, &x, &y );
    //    nk_input_motion( ctx, (int) x, (int) y );
    //    if ( ctx->input.mouse.grabbed ) {
    //        glfwSetCursorPos( nk_apemode_global_state.win,
    //        ctx->input.mouse.prev.x, ctx->input.mouse.prev.y );
    //        ctx->input.mouse.pos.x = ctx->input.mouse.prev.x;
    //        ctx->input.mouse.pos.y = ctx->input.mouse.prev.y;
    //    }
    //
    //    nk_input_button( ctx, NK_BUTTON_LEFT, (int) x, (int) y,
    //    glfwGetMouseButton( win, GLFW_MOUSE_BUTTON_LEFT ) == GLFW_PRESS );
    //    nk_input_button(
    //        ctx, NK_BUTTON_MIDDLE, (int) x, (int) y, glfwGetMouseButton( win,
    //        GLFW_MOUSE_BUTTON_MIDDLE ) == GLFW_PRESS );
    //    nk_input_button( ctx, NK_BUTTON_RIGHT, (int) x, (int) y,
    //    glfwGetMouseButton( win, GLFW_MOUSE_BUTTON_RIGHT ) == GLFW_PRESS );
    //    nk_input_scroll( ctx, nk_apemode_global_state.scroll );
    // nk_input_end( &nk_apemode_global_state.ctx );

    nk_apemode_global_state.text_len = 0;
    nk_apemode_global_state.scroll = nk_vec2(0, 0);
}

NK_API
void nk_apemode_shutdown(void) {
    nk_font_atlas_clear(&nk_apemode_global_state.atlas);
    nk_free(&nk_apemode_global_state.ctx);
    nk_apemode_device_destroy();

    // memset(&nk_apemode_global_state, 0, sizeof(nk_apemode_global_state));
    // nk_apemode_global_state.ogl.buffer_pool = std::vector<uint8_t>();
}
void nk_set_style(struct nk_context *ctx, enum nk_theme theme) {
    struct nk_color table[NK_COLOR_COUNT];
    if (theme == NK_THEME_WHITE) {
        table[NK_COLOR_TEXT] = nk_rgba(70, 70, 70, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_HEADER] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_BORDER] = nk_rgba(0, 0, 0, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(185, 185, 185, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(170, 170, 170, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(120, 120, 120, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_SELECT] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(80, 80, 80, 255);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(70, 70, 70, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(60, 60, 60, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_EDIT] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(0, 0, 0, 255);
        table[NK_COLOR_COMBO] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_CHART] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(45, 45, 45, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(180, 180, 180, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(140, 140, 140, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(180, 180, 180, 255);
        nk_style_from_table(ctx, table);
    } else if (theme == NK_THEME_RED) {
        table[NK_COLOR_TEXT] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(30, 33, 40, 215);
        table[NK_COLOR_HEADER] = nk_rgba(181, 45, 69, 220);
        table[NK_COLOR_BORDER] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(190, 50, 70, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(195, 55, 75, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(45, 60, 60, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SELECT] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(186, 50, 74, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(191, 55, 79, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_EDIT] = nk_rgba(51, 55, 67, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_COMBO] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_CHART] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(170, 40, 60, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(30, 33, 40, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(64, 84, 95, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(70, 90, 100, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(75, 95, 105, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(181, 45, 69, 220);
        nk_style_from_table(ctx, table);
    } else if (theme == NK_THEME_BLUE) {
        table[NK_COLOR_TEXT] = nk_rgba(20, 20, 20, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(202, 212, 214, 215);
        table[NK_COLOR_HEADER] = nk_rgba(137, 182, 224, 220);
        table[NK_COLOR_BORDER] = nk_rgba(140, 159, 173, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(142, 187, 229, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(147, 192, 234, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(182, 215, 215, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_SELECT] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(137, 182, 224, 245);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(142, 188, 229, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(147, 193, 234, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_EDIT] = nk_rgba(210, 210, 210, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(20, 20, 20, 255);
        table[NK_COLOR_COMBO] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_CHART] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(190, 200, 200, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(64, 84, 95, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(70, 90, 100, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(75, 95, 105, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(156, 193, 220, 255);
        nk_style_from_table(ctx, table);
    } else if (theme == NK_THEME_DARK) {
        table[NK_COLOR_TEXT] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(57, 67, 71, 215);
        table[NK_COLOR_HEADER] = nk_rgba(51, 51, 56, 220);
        table[NK_COLOR_BORDER] = nk_rgba(46, 46, 46, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(63, 98, 126, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(45, 53, 56, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SELECT] = nk_rgba(57, 67, 61, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(48, 83, 111, 245);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(53, 88, 116, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_EDIT] = nk_rgba(50, 58, 61, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_COMBO] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_CHART] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(53, 88, 116, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(48, 83, 111, 255);
        nk_style_from_table(ctx, table);
    } else {
        nk_style_default(ctx);
    }
}

#include <droidsans.ttf.h>

void nk_apemode_setup_style() {
    struct nk_apemode_device *dev = &nk_apemode_global_state.ogl;

    struct nk_font_atlas *atlas;
    nk_apemode_font_stash_begin(&atlas);
    auto defaultFont = nk_font_atlas_add_from_memory(
        atlas, (void *)s_droidSansTtf, sizeof(s_droidSansTtf), 48, 0);
    //    defaultFont->scale *= 4.0;
    nk_apemode_font_stash_end();

    nk_set_style(&nk_apemode_global_state.ctx, nk_theme::NK_THEME_DARK);
    nk_apemode_global_state.ctx.style.font = &defaultFont->handle;
    nk_apemode_global_state.atlas.default_font = defaultFont;
    nk_style_set_font(&nk_apemode_global_state.ctx, &defaultFont->handle);
}