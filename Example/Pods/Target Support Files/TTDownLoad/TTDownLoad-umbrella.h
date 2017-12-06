#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "TTDownloadDataManager.h"
#import "TTDownloadDelegate.h"
#import "TTDownloadModel.h"
#import "TTListDownloadManager.h"
#import "TTM3u8DownloadManager.h"

FOUNDATION_EXPORT double TTDownLoadVersionNumber;
FOUNDATION_EXPORT const unsigned char TTDownLoadVersionString[];

