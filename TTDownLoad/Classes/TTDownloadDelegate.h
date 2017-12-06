//
//  TTDownloadDelegate.h
//  TTDownLoad
//
//  Created by Fengtf on 2017/11/19.
//


#import <Foundation/Foundation.h>
#import "TTDownloadModel.h"

// 下载代理
@protocol TTDownloadDelegate <NSObject>

// 更新下载进度
- (void)downloadModel:(TTDownloadModel *)downloadModel didUpdateProgress:(TTDownloadProgress *)progress;

// 更新下载状态
- (void)downloadModel:(TTDownloadModel *)downloadModel didChangeState:(TTDownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

// 下载完毕
- (void)downloadDidCompleted:(TTDownloadModel *)downloadModel;


@end


