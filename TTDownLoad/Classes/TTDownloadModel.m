//
//  TTDownloadModel.m
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import "TTDownloadModel.h"

@interface TTDownloadProgress ()
// 续传大小
//@property (nonatomic, assign) int64_t resumeBytesWritten;
//// 这次写入的数量
//@property (nonatomic, assign) int64_t bytesWritten;
//// 已下载的数量
//@property (nonatomic, assign) int64_t totalBytesWritten;
//// 文件的总大小
//@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;
//// 下载进度
//@property (nonatomic, assign) float progress;
//// 下载速度
//@property (nonatomic, assign) float speed;
//// 下载剩余时间
//@property (nonatomic, assign) int remainingTime;

@end


@implementation TTDownloadModel

- (instancetype)init
{
    if (self = [super init]) {
        _progress = [[TTDownloadProgress alloc]init];
    }
    return self;
}

- (instancetype)initWithURLString:(NSString *)URLString
{
    return [self initWithURLString:URLString filePath:nil];
}

- (instancetype)initWithURLString:(NSString *)URLString filePath:(NSString *)filePath
{
    if (self = [self init]) {
        _downloadURL = URLString;
        _fileName = filePath.lastPathComponent;
        //_downloadDirectory = filePath.stringByDeletingLastPathComponent;
        _filePath = filePath;
    }
    return self;
}

-(NSString *)fileName
{
    if (!_fileName) {
        _fileName = _downloadURL.lastPathComponent;
    }
    return _fileName;
}

@end

@implementation TTDownloadProgress

@end

