//----------------------------------------------------------------------------------
// File:        TKAppBase/TKSampleApp.cpp
// SDK Version: v3.00
// Email:       gameworks@nvidia.com
// Site:        http://developer.nvidia.com/
//
// Copyright (c) 2014-2015, NVIDIA CORPORATION. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//  * Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//  * Neither the name of NVIDIA CORPORATION nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//----------------------------------------------------------------------------------
#include "NvAppBase/TKSampleApp.h"
#include "NV/NvLogs.h"
#include "NV/NvString.h"
#include "NV/NvTokenizer.h"
#include "NvAppBase/NvFramerateCounter.h"
#include "NvAppBase/NvInputHandler.h"
#include "NvAppBase/NvInputTransformer.h"
#include "NvImage/NvImage.h"
#include "NvUI/NvGestureDetector.h"
#include "NvUI/NvTweakBar.h"

#include <NsAllocator.h>
#include <NsIntrinsics.h>

#include <stdarg.h>
#include <sstream>

TKSampleApp::TKSampleApp()
    : TKAppBase()
    , mFramerate(0L)
    , mFrameDelta(0.0f)
    , mEnableFPS(true)
    , mDesiredWidth(0)
    , mDesiredHeight(0)
    , mEnableInputCallbacks(true)
    , mUseRenderThread(false)
    , mThread(nullptr)
    , mRenderThreadRunning(false)
    , mUseFBOPair(false)
    , mFBOWidth(0)
    , mFBOHeight(0)
    , mLogFPS(false)
    , mTimeSinceFPSLog(0.0f) {
    memset(mLastPadState, 0, sizeof(mLastPadState));

    mFrameTimer = createStopWatch();
    mEventTickTimer = createStopWatch();
    mAutoRepeatTimer = createStopWatch();
    mAutoRepeatButton = 0; // none yet! :)
    mAutoRepeatTriggered = false;

    const std::vector<std::string>& cmd = getCommandLine();
    std::vector<std::string>::const_iterator iter = cmd.begin();

    while (iter != cmd.end()) {
        if (0 == (*iter).compare("-w")) {
            iter++;
            std::stringstream(*iter) >> mDesiredWidth;
        } else if (0 == (*iter).compare("-h")) {
            iter++;
            std::stringstream(*iter) >> mDesiredHeight;
        // } else if (0 == (*iter).compare("-testmode")) {
        //     mTestMode = true;
        //     iter++;
        //     std::stringstream(*iter) >> mTestDuration;
        //     iter++;
        //     mTestName = (*iter); // both std::string
        // } else if (0 == (*iter).compare("-repeat")) {
        //     iter++;
        //     std::stringstream(*iter) >> mTestRepeatFrames;
        } else if (0 == (*iter).compare("-fbo")) {
            mUseFBOPair = true;
            iter++;
            std::stringstream(*iter) >> mFBOWidth;
            iter++;
            std::stringstream(*iter) >> mFBOHeight;
        } else if (0 == (*iter).compare("-logfps")) {
            mLogFPS = true;
        }

        iter++;
    }

    nvidia::shdfnd::initializeNamedAllocatorGlobals();
    mThread = nullptr;
    mRenderSync = new nvidia::shdfnd::Sync;
    mMainSync = new nvidia::shdfnd::Sync;
}

TKSampleApp::~TKSampleApp() {
    // clean up internal allocs
    delete mFrameTimer;
    delete mEventTickTimer;
    delete mAutoRepeatTimer;

    // delete m_transformer;
}

bool TKSampleApp::baseInitRendering() {
    if (mUseFBOPair)
        mUseFBOPair =
            getAppContext()->useOffscreenRendering(mFBOWidth, mFBOHeight);

    getAppContext()->contextInitRendering();

    if (!platformInitRendering())
        return false;
    initRendering();
    baseInitUI();

    return true;
}

void TKSampleApp::baseInitUI() {
    // safe to now pass through title to platform layer...
    if (!mAppTitle.empty()) {
        mPlatform->setAppTitle(mAppTitle.c_str());
    }
}

void TKSampleApp::baseReshape(int32_t w, int32_t h) {
    getAppContext()->platformReshape(w, h);

    if ((w == mWidth) && (h == mHeight))
        return;

    mWidth = w;
    mHeight = h;
    reshape(w, h);
}

void TKSampleApp::baseUpdate() {
    update();
}

void TKSampleApp::baseDraw() {
    draw();
}

void TKSampleApp::baseDrawUI() {
}

void TKSampleApp::baseHandleReaction() {
}

bool TKSampleApp::handleGestureEvents() {
    return false;
}

bool TKSampleApp::pointerInput(NvInputDeviceType::Enum device,
                               NvPointerActionType::Enum action,
                               uint32_t modifiers,
                               int32_t count,
                               NvPointerEvent* points,
                               int64_t timestamp) {
    // In on-demand rendering mode, we trigger a redraw on any input
    if (mPlatform->getRedrawMode() == NvRedrawMode::ON_DEMAND) {
        mPlatform->requestRedraw();
    }

    return handlePointerInput(device, action, modifiers, count, points);
}

void TKSampleApp::addTweakKeyBind(NvTweakVarBase* var,
                                  uint32_t incKey,
                                  uint32_t decKey /*=0*/) {
    // mKeyBinds[incKey] = NvTweakBind(NvTweakCmd::INCREMENT, var);
    // if (decKey)
    //     mKeyBinds[decKey] = NvTweakBind(NvTweakCmd::DECREMENT, var);
}

bool TKSampleApp::keyInput(uint32_t code, NvKeyActionType::Enum action) {
    if (mPlatform->getRedrawMode() == NvRedrawMode::ON_DEMAND) {
        mPlatform->requestRedraw();
    }

    if (handleKeyInput(code, action)) {
        return true;
    }

    // give last shot to transformer.
    // if (m_inputHandler) {
    //     return m_inputHandler->processKey(code, action);
    // } else {
    //     return m_transformer->processKey(code, action);
    // }

    return false;
}

bool TKSampleApp::characterInput(uint8_t c) {
    // In on-demand rendering mode, we trigger a redraw on any input
    if (mPlatform->getRedrawMode() == NvRedrawMode::ON_DEMAND) {
        mPlatform->requestRedraw();
    }

    return handleCharacterInput(c);
}

void TKSampleApp::addTweakButtonBind(NvTweakVarBase* var,
                                     uint32_t incBtn,
                                     uint32_t decBtn /*=0*/) {
    // mButtonBinds[incBtn] = NvTweakBind(NvTweakCmd::INCREMENT, var);
    // if (decBtn)
    //     mButtonBinds[decBtn] = NvTweakBind(NvTweakCmd::DECREMENT, var);
}

bool TKSampleApp::gamepadButtonChanged(uint32_t button, bool down) {
    if (mAutoRepeatButton == button && !down) {
        mAutoRepeatButton = 0;
        mAutoRepeatTriggered = false;
        mAutoRepeatTimer->stop();
    }

    // In on-demand rendering mode, we trigger a redraw on any input
    if (mPlatform->getRedrawMode() == NvRedrawMode::ON_DEMAND) {
        mPlatform->requestRedraw();
    }

    // let apps have a shot AFTER we intercept framework controls.
    return handleGamepadButtonChanged(button, down);
}

bool TKSampleApp::gamepadChanged(uint32_t changedPadFlags) {
    // In on-demand rendering mode, we trigger a redraw on any input
    if (mPlatform->getRedrawMode() == NvRedrawMode::ON_DEMAND) {
        mPlatform->requestRedraw();
    }

    if (handleGamepadChanged(changedPadFlags))
        return true;

    if (!changedPadFlags)
        return false;

    NvGamepad* pad = getPlatformContext()->getGamepad();
    if (!pad)
        return false;

    NvGamepad::State state{};
    uint32_t i, j;
    uint32_t button;
    bool buttonDown;
    for (i = 0; i < NvGamepad::MAX_GAMEPADS; i++) {
        if (changedPadFlags & (1 << i)) {
            pad->getState(i, state);
            if (state.mButtons != mLastPadState[i].mButtons) {
                // parse through the buttons and send events.
                for (j = 0; j < 32; j++) { // iterate button bits
                    button = 1 << j;
                    buttonDown = (button & state.mButtons) > 0;
                    if (buttonDown !=
                        ((button & mLastPadState[i].mButtons) > 0))
                        gamepadButtonChanged(button, buttonDown);
                }
            }
            // when done processing a gamepad, copy off the state.
            memcpy(mLastPadState + i, &state, sizeof(state));
        }
    }

    return false;
    // give last shot to transformer.  not sure how we 'consume' input though.
    // if (m_inputHandler) {
    //     return m_inputHandler->processGamepad(changedPadFlags, *pad);
    // } else {
    //     return m_transformer->processGamepad(changedPadFlags, *pad);
    // }
}

void TKSampleApp::initRenderLoopObjects() {
    mTotalTime = -1e6f; // don't exit during startup

    mFramerate = new NvFramerateCounter(this);

    mFrameTimer->start();

    mSumDrawTime = 0.0f;
    mDrawTimeFrames = 0;
    mDrawRate = 0.0f;
    mDrawTime = createStopWatch();
}

void TKSampleApp::shutdownRenderLoopObjects() {
    if (mHasInitializedRendering) {
        baseShutdownRendering();
        mHasInitializedRendering = false;
    }

    delete mFramerate;
    mFramerate = nullptr;
}

void TKSampleApp::renderLoopRenderFrame() {
    mFrameTimer->stop();

    //if (mTestMode) {
    //    // Simulate 60fps
    //    mFrameDelta = 1.0f / 60.0f;
    //    // just an estimate
    //    mTotalTime += mFrameTimer->getTime();
    //} else {
    {
        mFrameDelta = mFrameTimer->getTime();
        // just an estimate
        mTotalTime += mFrameDelta;
    }

    // if (m_inputHandler) {
    //     m_inputHandler->update(mFrameDelta);
    // } else {
    //     m_transformer->update(mFrameDelta);
    // }

    mFrameTimer->reset();

    if (mWidth == 0 || mHeight == 0) {
        NvThreadManager *thread = getThreadManagerInstance();

        if (thread) {
            thread->sleepThread(200);
        }

        return;
    }

    // initialization may cause the app to want to exit
    if (isExiting()) { return; }

    mFrameTimer->start();

    if (mEventTickTimer->getTime() >= 0.05f) {
        mEventTickTimer->start(); // reset and continue...
        // if (NvGestureTick(NvTimeGetTime()))
        //     handleGestureEvents();
    }

    // Handle automatic repeating buttons.
    if (mAutoRepeatButton) {
        const float elapsed = mAutoRepeatTimer->getTime();
        if ((!mAutoRepeatTriggered && elapsed >= 0.5f) ||
            (mAutoRepeatTriggered && elapsed >= 0.04f)) { // 25hz repeat
            mAutoRepeatTriggered = true;
            gamepadButtonChanged(mAutoRepeatButton, true);
        }
    }

    mDrawTime->start();

    getAppContext()->beginFrame();
    getAppContext()->beginScene();

    baseDraw();

    getAppContext()->endScene();
    getAppContext()->endFrame();

    mDrawTime->stop();
    mSumDrawTime += mDrawTime->getTime();
    mDrawTime->reset();

    mDrawTimeFrames++;
    if (mDrawTimeFrames > 10) {
        mDrawRate = mDrawTimeFrames / mSumDrawTime;
        mDrawTimeFrames = 0;
        mSumDrawTime = 0.0f;
    }

    mFramerate->nextFrame();

    if (mLogFPS) {
        // wall time - not (possibly) simulated time
        mTimeSinceFPSLog += mFrameTimer->getTime();

        if (mTimeSinceFPSLog > 1.0f) {
            LOGI("fps: %.2f", mFramerate->getMeanFramerate());
            mTimeSinceFPSLog = 0.0f;
        }
    }
}

bool TKSampleApp::haltRenderingThread() {
    // DO NOT test whether we WANT threading - the app may have just requested
    // threaded rendering to be disabled.
    // If threaded:
    // 1) Signal the rendering thread to exit
    if (mThread) {
        mRenderSync->set();
        mThread->signalQuit();
        // 2) Wait for the thread to complete (it will unbind the context), if
        // it is running
        if (mThread->waitForQuit()) {
            // 3) Bind the context (unless it is lost?)
            getAppContext()->bindContext();
        }
        NV_DELETE_AND_RESET(mThread);
    }

    return true;
}

void* TKSampleApp::renderThreadThunk(void* thiz) {
    ((TKSampleApp*)thiz)->renderThreadFunc();
    return NULL;
}

void TKSampleApp::renderThreadFunc() {
    getAppContext()->prepThreadForRender();
    getAppContext()->bindContext();

    nvidia::shdfnd::memoryBarrier();
    mMainSync->set();

    while (mThread && !mThread->quitIsSignalled()) {
        renderLoopRenderFrame();

        // if we are not in full-bore rendering mode, wait to be triggered
        if (getPlatformContext()->getRedrawMode() != NvRedrawMode::UNBOUNDED) {
            mRenderSync->wait();
            mRenderSync->reset();
        }
    }

    getAppContext()->unbindContext();
    mRenderThreadRunning = false;
}

bool TKSampleApp::conditionalLaunchRenderingThread() {
    if (mUseRenderThread) {
        if (!mRenderThreadRunning) {
            // If threaded and the render thread is not running:
            // 1) Unbind the context
            getAppContext()->unbindContext();
            // 2) Call the thread launch function (which will bind the context)
            mRenderThreadRunning = true;
            mThread = NV_NEW(nvidia::shdfnd::Thread)(renderThreadThunk, this);

            // 3) WAIT for the rendering thread to bind or fail
            mMainSync->wait();
            mMainSync->reset();
        }

        // In any of the "triggered" modes, trigger the rendering thread loop
        if (getPlatformContext()->getRedrawMode() != NvRedrawMode::UNBOUNDED) {
            mRenderSync->set();
        }
        return true;
    } else {
        haltRenderingThread();

        // return false if we are not running in threaded mode or
        // _CANNOT_ support threading
        return false;
    }
}

void TKSampleApp::mainThreadRenderStep() {
    NvPlatformContext* ctx = getPlatformContext();
    bool needsReshape = false;

    // If the context has been lost and graphics resources are still around,
    // signal for them to be deleted
    if (ctx->isContextLost()) {
        if (mHasInitializedRendering) {
            haltRenderingThread();
            baseShutdownRendering();
            mHasInitializedRendering = false;
        }
    }

    // If we're ready to render (i.e. the GL is ready and we're focused), then
    // go ahead
    if (ctx->shouldRender()) {
        // If we've not (re-)initialized the resources, do it
        if (!mHasInitializedRendering && !isExiting()) {
            mHasInitializedRendering = baseInitRendering();
            needsReshape = true;
        } else if (ctx->hasWindowResized()) {
            haltRenderingThread();
            needsReshape = true;
        }

        // initialization may cause the app to want to exit, so test exiting
        if (needsReshape && !isExiting()) {
            baseReshape(getAppContext()->width(), getAppContext()->height());
        }

        // if we're not threaded or if the thread failed to launch - render here
        if (!conditionalLaunchRenderingThread())
            renderLoopRenderFrame();
    }
}

void TKSampleApp::requestThreadedRendering(bool threaded) {
    mUseRenderThread = threaded;
}

bool TKSampleApp::isRenderThreadRunning() {
    return mRenderThreadRunning;
}

void TKSampleApp::mainLoop() {
    mHasInitializedRendering = false;

    initRenderLoopObjects();

    // TBD - WAR for Android lifecycle change; this will be reorganized in the
    // next release
#ifdef ANDROID
    while (getPlatformContext()->isAppRunning()) {
#else
    while (getPlatformContext()->isAppRunning() && !isExiting()) {
#endif
        getPlatformContext()->pollEvents(isAppInputHandlingEnabled() ? this
                                                                     : NULL);

        baseUpdate();

        mainThreadRenderStep();
    }

    haltRenderingThread();

    shutdownRenderLoopObjects();

    // mainloop exiting, clean up things created in mainloop lifespan.
}

void TKSampleApp::errorExit(const char* errorString) {
    // we set the flag here manually.  The exit will not happen until
    // the user closes the dialog.  But we want to act as if we are
    // already exiting (which we are), so we do not render
    mRequestedExit = true;
    showDialog("Fatal Error", errorString, true);
}

bool TKSampleApp::getRequestedWindowSize(int32_t& width, int32_t& height) {
    bool changed = false;
    if (mDesiredWidth != 0) {
        width = mDesiredWidth;
        changed = true;
    }

    if (mDesiredHeight != 0) {
        height = mDesiredHeight;
        changed = true;
    }

    return changed;
}

void TKSampleApp::baseShutdownRendering(void) {
    platformShutdownRendering();
    shutdownRendering();
}

void TKSampleApp::logTestResults(float frameRate, int32_t frames) {
}
