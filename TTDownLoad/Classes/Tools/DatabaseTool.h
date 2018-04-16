//
//  DatabaseTool.h
//  TTDownLoad
//
//  Created by Fengtf on 2018/3/18.
//

#import <Foundation/Foundation.h>
#import "TTDownloadModel.h"
#import "TTDownloadModel.h"

typedef NS_ENUM(NSInteger, DownloadState) {
    DownloadStateNotDownload,//没有下载
    DownloadStateDownloading  ,//进行中
    DownloadStateDownloadCompleted ,//已完成
};


@interface DatabaseTool : NSObject

+(BOOL)addDownModel:(TTDownloadModel *)model;

/**
 *  根据是否下载完毕取出所有的数据
 *
 *  @param isDowned YES：已经下载，NO：未下载
 *
 *  @return 装有FileModel的模型
 */
+(NSArray *)getDownModeArray:(BOOL)isHadDown;

/**
 *  这个剧是否在下载列表
 *
 *  @param uniquenName uniquenName ： MovieId+epsiode
 *
 *  @return YES：存在 ； NO：不存在
 */
+(BOOL)isFileModelInDB:(NSString *)uniquenName movieType:(MovieType)movieType;


@end
