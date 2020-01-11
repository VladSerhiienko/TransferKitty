//#include <EzriOS.h>
#include <EABase/eabase.h>
#include <new>

#ifdef _WIN32
#include <Windows.h>
#endif

#include <time.h>
//#define MSPACES 1
//#define USE_DL_PREFIX 1
//#define ONLY_MSPACES 1
//#define MALLOC_ALIGNMENT (apemode::kDefaultAlignment)
//#include "malloc.c.h"

//static thread_local mspace tlms = create_mspace(0, 0);

namespace apemode {
    constexpr size_t kDefaultAlignment = sizeof(void*) << 1;

    void *malloc( size_t size, size_t alignment ) {
#ifdef _WIN32
        return _aligned_malloc( size, alignment );
#else
        void *p = nullptr;
        ::posix_memalign( &p, alignment, size );
        return p;
#endif
    }

    void free( void *p ) {
#ifdef _WIN32
        _aligned_free( p );
#else
        ::free( p );
#endif
    }

//    void * thread_local_malloc(size_t size, size_t alignment) {
//        return mspace_malloc2(tlms, size, alignment, 0);
//    }
//
//    void * thread_local_realloc(void *p, size_t size, size_t alignment) {
//        return mspace_realloc2(tlms, p, size, alignment, 0);
//    }
//
//    void thread_local_free(void *p) {
//        mspace_free(tlms, p);
//    }

}

void *operator new( size_t size ) {
    return apemode::malloc( size, apemode::kDefaultAlignment );
}

void *operator new[]( size_t size ) {
    return apemode::malloc( size, apemode::kDefaultAlignment );
}

void *operator new[]( size_t size, const char * /*name*/, int /*flags*/, unsigned /*debugFlags*/, const char * /*file*/, int /*line*/ ) {
    return apemode::malloc( size, apemode::kDefaultAlignment );
}

void *operator new[]( size_t size,
                      size_t alignment,
                      size_t /*alignmentOffset*/,
                      const char * /*name*/,
                      int /*flags*/,
                      unsigned /*debugFlags*/,
                      const char * /*file*/,
                      int /*line*/ ) {
    return apemode::malloc( size, alignment );
}

void *operator new( size_t size, size_t alignment ) {
    return apemode::malloc( size, alignment );
}

void *operator new( size_t size, size_t alignment, const std::nothrow_t & ) EA_THROW_SPEC_NEW_NONE( ) {
    return apemode::malloc( size, alignment );
}

void *operator new[]( size_t size, size_t alignment ) {
    return apemode::malloc( size, alignment );
}

void *operator new[]( size_t size, size_t alignment, const std::nothrow_t & ) EA_THROW_SPEC_NEW_NONE( ) {
    return apemode::malloc( size, alignment );
}

// C++14 deleter
void operator delete(void *p, std::size_t sz) EA_THROW_SPEC_DELETE_NONE( ) {
    apemode::free( p );
    EA_UNUSED( sz );
}

void operator delete[]( void *p, std::size_t sz ) EA_THROW_SPEC_DELETE_NONE( ) {
    apemode::free( p );
    EA_UNUSED( sz );
}

void operator delete( void *p ) EA_THROW_SPEC_DELETE_NONE( ) {
    apemode::free( p );
}

void operator delete[]( void *p ) EA_THROW_SPEC_DELETE_NONE( ) {
    apemode::free( p );
}
