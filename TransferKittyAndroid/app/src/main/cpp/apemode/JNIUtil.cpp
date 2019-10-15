#include <JNIUtil.h>

#if defined(ANDROID)
#include <jni.h>
#include <NvLogs.h>
#include <cassert>
//#include <EASTL/internal/config.h>

void JNIHandleException( void* env_, const char* file, int32_t line ) {
    if ( JNIEnv* env = static_cast< JNIEnv* >( env_ ) )
        if ( env->ExceptionOccurred( ) ) {
            LOGE( "JNICheckedCall: Exception occured in \"%s\"[%d]:", file, line );
            env->ExceptionDescribe( );
            env->ExceptionClear( );
            assert(false); // EASTL_DEBUG_BREAK();
        }
}
#endif