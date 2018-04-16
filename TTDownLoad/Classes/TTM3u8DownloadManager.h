//
//  TTM3u8DownloadManager.h
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import <Foundation/Foundation.h>
#import "TTDownloadModel.h"

@protocol RRM3u8DownloadDelegate <NSObject>
@optional
// 更新下载进度
- (void)m3u8DownloadModel:(TTDownloadModel *)downloadModel didUpdateProgress:(TTDownloadProgress *)progress;

// 更新下载状态
- (void)m3u8DownloadModel:(TTDownloadModel *)downloadModel didChangeState:(RRDownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

// 下载完毕
- (void)m3u8DownloadDidCompleted:(TTDownloadModel *)downloadModel;

@end

@interface TTM3u8DownloadManager : NSObject <NSURLSessionDataDelegate>

// 单例
+ (TTM3u8DownloadManager *)manager;

//解析m3u8的配置文件
-(void)praseUrl:(TTDownloadModel *)downloadModel;

// 下载代理
@property (nonatomic,weak) id<RRM3u8DownloadDelegate> delegate;

// 下载中 + 等待中的模型 只读
@property (nonatomic, strong,readonly) NSMutableArray *downloadAllModels;

// 恢复下载（除非确定对这个model进行了suspend，否则使用start）
- (void)resumeWithDownloadModel:(TTDownloadModel *)downloadModel;

// 恢复全部的下载任务
- (void)resumeAllTasks;

// 暂停所有的下载
-(void)suspendAllTasks;

// 删除所有的下载
-(void)deleteAllTasks;
@end
