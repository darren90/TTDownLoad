//
//  TTListDownloadManager.h
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import <Foundation/Foundation.h>
#import "TTDownloadModel.h"

@protocol RRListDownloadDelegate <NSObject>
@optional
// 更新下载进度
- (void)listDownloadModel:(RRDownloadModel *)downloadModel didUpdateProgress:(RRDownloadProgress *)progress;

// 更新下载状态
- (void)listDownloadModel:(RRDownloadModel *)downloadModel didChangeState:(RRDownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

// 下载完毕
- (void)listDownloadDidCompleted:(RRDownloadModel *)downloadModel;

@end


@interface TTListDownloadManager : NSObject <NSURLSessionDataDelegate>

// 单例
+ (TTListDownloadManager *)manager;

//解析List --- -- 数组中装的是数组是： RRDownloadModel
-(void)praseList:(TTDownloadModel *)downloadModel;


// 下载代理
@property (nonatomic,weak) id<RRListDownloadDelegate> delegate;

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
