//
//  TTDownloadDataManager.h
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import <Foundation/Foundation.h>
#import "TTDownloadDelegate.h"
#import "TTDownloadModel.h"

@interface TTDownloadDataManager : NSObject <NSURLSessionDataDelegate>

// 下载中 + 等待中的模型 只读
@property (nonatomic, strong,readonly) NSMutableArray *downloadAllModels;

// 下载代理
@property (nonatomic,weak) id <TTDownloadDelegate> delegate;

// 单例
+ (TTDownloadDataManager *)manager;

// 开始下载
- (void)startWithDownloadModel:(TTDownloadModel *)downloadModel;

// 恢复下载（除非确定对这个model进行了suspend，否则使用start）
- (void)resumeWithDownloadModel:(TTDownloadModel *)downloadModel;

// 恢复全部的下载任务
- (void)resumeAllTasks;

// 暂停下载
- (void)suspendWithDownloadModel:(TTDownloadModel *)downloadModel;

// 暂停所有的下载
-(void)suspendAllTasks;

// 等待下载
- (void)waitWithDownloadModel:(TTDownloadModel *)downloadModel;

// 删除下载
- (void)deleteFileWithDownloadModel:(TTDownloadModel *)downloadModel;

// 批量删除
- (void)deleteFileWithDownloadModels:(NSArray *)array;

// 删除所有的下载
-(void)deleteAllTasks;

//开启下载引擎
-(void)startEngine;


@end
