#include "NvAppBase/TKAppBase.h"

#include "NV/NvLogs.h"
#include "NV/NvStopWatch.h"
#include "NvAppBase/NvCPUTimer.h"
#include "NvImage/NvImage.h"

#include <cstdio>

std::vector<std::string> TKAppBase::sCmdLine;
NvStopWatchFactory* NvCPUTimer::ms_factory = nullptr;

TKAppBase::TKAppBase()
    : mPlatform(nullptr)
    , mContext(nullptr)
    , mThreadManager(nullptr)
    , mWidth(0)
    , mHeight(0)
    , mRequestedExit(false) {
    NvCPUTimer::globalInit(this);
}

TKAppBase::~TKAppBase() {
    delete mPlatform;
}

void TKAppBase::appRequestExit() {
    getPlatformContext()->requestExit();
    mRequestedExit = true;
}
