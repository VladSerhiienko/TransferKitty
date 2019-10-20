#ifndef NV_SAMPLE_APP_GL_H
#define NV_SAMPLE_APP_GL_H

#include <NvSimpleTypes.h>

#include "NvAppBase/TKSampleApp.h"
#include "NvAppBase/gl/TKAppContextGL.h"

/// \file
/// GL-based Sample app base class.

/// Base class for GL sample apps.
class TKSampleAppGL : public TKSampleApp
{
public:
    /// Constructor
    /// Do NOT make rendering API calls in the constructor
    /// The rendering context is not bound until the entry into initRendering
    TKSampleAppGL();

    /// Destructor
    virtual ~TKSampleAppGL();

    /// Extension requirement declaration.
    /// Allow an app to declare an extension as "required".
    /// \param[in] ext the extension name to be required
    /// \param[in] exitOnFailure if true,
    /// then #errorExit is called to indicate the issue and exit
    /// \return true if the extension string is exported and false
    /// if it is not
    bool requireExtension(const char* ext, bool exitOnFailure = true);

    /// GL Minimum API requirement declaration.
    /// \param[in] minApi the minimum API that is required
    /// \param[in] exitOnFailure if true,
    /// then errorExit is called to indicate the issue and exit
    /// \return true if the platform's GL[ES] API version is at least
    /// as new as the given minApi.  Otherwise, returns false
    bool requireMinAPIVersion(const NvGLAPIVersion& minApi, bool exitOnFailure = true);

    /// GL configuration request callback.
    /// This function passes in the default set of GL configuration requests
    /// The app can override this function and change the defaults before
    /// returning.  These are still requests, and may not be met.  If the
    /// platform supports requesting GL options, this function will be called
    /// before initGL.  Optional.
    /// \param[in,out] config the default config to be used is passed in.  If the application
    /// wishes anything different in the GL configuration, it should change those values before
    /// returning from the function.  These are merely requests.
    virtual void configurationCallback(NvGLConfiguration& config) { }

	/// Return the GL-specific app context structure for easy use in the app
	/// \return Pointer to the GL-specific app context or NULL if not initialized
    TKAppContextGL* getGLContext() { return (TKAppContextGL*)mContext; }

    /// Retrieve the main "onscreen" framebuffer; this may actually
    /// be an offscreen FBO that the framework uses internally, and then
    /// resolves to the window.  Apps should ALWAYS use this value when
    /// binding the onscreen FBO and NOT use FBO ID 0 in order to ensure
    /// that they are compatible with test mode, etc.
    /// This should be queried on a per-frame basis.  It may change every frame
    /// \return the GL ID of the main, "onscreen" FBO
    GLuint getMainFBO() const { return ((TKAppContextGL*)mContext)->getMainFBO(); }

	/// \privatesection
	virtual int32_t getUniqueTypeID();
	static bool isType(TKAppBase* app);

	virtual bool initialize(const NvPlatformInfo& platform, int32_t width, int32_t height);

protected:
    /// \privatesection
    virtual bool platformInitRendering(void);

    virtual void platformInitUI(void);

    virtual void platformLogTestResults(float frameRate, int32_t frames);

private:
};

#endif
