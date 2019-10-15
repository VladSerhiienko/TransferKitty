#pragma once

void JNIHandleException(void* env, const char* file, int line);

template < typename R, typename F >
R JNICheckedCall_( void* env, F f, const char* file, int line ) {
    R result = f( );
    JNIHandleException(env, file, line);
    return result;
};

template < typename F >
void JNICheckedVoidCall_( void* env, F f, const char* file, int line ) {
    f( );
    JNIHandleException(env, file, line);
};

#define JNICheckedCall(t, env, ...) JNICheckedCall_<t>(env, [&] { return __VA_ARGS__; }, __FILE__, __LINE__)
#define JNICheckedVoidCall(env, ...) JNICheckedVoidCall_(env, [&] { __VA_ARGS__; }, __FILE__, __LINE__)
