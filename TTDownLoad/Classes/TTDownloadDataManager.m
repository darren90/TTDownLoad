//
//  TTDownloadDataManager.m
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import "TTDownloadDataManager.h"
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#import "TTM3u8DownloadManager.h"
#import "TTListDownloadManager.h"
#import "DatabaseTool.h"
#import "DownloadTool.h"
//#import "RRMJTool.h"
//#import "MainGetPlayUrl.h"

@interface TTDownloadDataManager () //<RRM3u8DownloadDelegate,RRListDownloadDelegate>
// >>>>>>>>>>>>>>>>>>>>>>>>>>  file info
// 文件管理
@property (nonatomic, strong) NSFileManager *fileManager;
// 缓存文件目录
//@property (nonatomic, strong) NSString *downloadDirectory;

// >>>>>>>>>>>>>>>>>>>>>>>>>>  session info
// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 下载中 + 等待中的模型 只读
@property (nonatomic, strong) NSMutableArray *downloadAllModels;
// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;

// 最大下载数
@property (nonatomic, assign) NSInteger maxDownloadCount;

// 全部并发 默认NO, 当YES时，忽略maxDownloadCount
@property (nonatomic, assign) BOOL isBatchDownload;

/* 用于计数 -- 不让进度调用的方法过于频繁 */
@property (nonatomic,assign)NSInteger timesCount;

@end


@implementation TTDownloadDataManager
{
    /**
     *  后台进程id
     */
    UIBackgroundTaskIdentifier  _backgroudTaskId;
}


#pragma mark - getter

+ (TTDownloadDataManager *)manager {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _maxDownloadCount = 1;
        _isBatchDownload = NO;
        _timesCount = 0;
        
        _backgroudTaskId = UIBackgroundTaskInvalid;
        //注册程序即将失去焦点的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
        //注册程序获得焦点的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskDidBecomActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}


- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc]init];
    }
    return _fileManager;
}

#define IS_IOS8ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)

- (NSURLSession *)session
{
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
    }
    return _session;
}


/**
 *  收到程序即将失去焦点的通知，开启后台运行
 *
 *  @param sender 通知
 */
-(void)downloadTaskWillResign:(NSNotification *)sender{
    
    if(self.downloadAllModels.count > 0){
        _backgroudTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        }];
    }
}
/**
 *  收到程序重新得到焦点的通知，关闭后台
 *
 *  @param sender 通知
 */
-(void)downloadTaskDidBecomActive:(NSNotification *)sender{
    
    if(_backgroudTaskId != UIBackgroundTaskInvalid){
        
        [[UIApplication sharedApplication] endBackgroundTask:_backgroudTaskId];
        _backgroudTaskId = UIBackgroundTaskInvalid;
    }
}

-(void)dealloc{
    [_session invalidateAndCancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSOperationQueue *)queue {
    if (!_queue) {
        _queue = [[NSOperationQueue alloc]init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

//开启下载引擎
#pragma mark -- 程序启动，自动开启下载任务
-(void)startEngine{
    NSArray *array = [DatabaseTool getDownModeArray:NO];//拿到未下载的数据
    if (!array.count)  return;
#warning TODO - 待做
//    RRNetStatus netStatus = [RRMJTool getCacheNetStatusWhenAppStart];
//
//
//    if(netStatus == RRNetViaWifi) {     // 开始下载
//        for (TTDownloadModel *model in array) {
//            [self resumeWithDownloadModel:model];
//        }
//    } else {                            //加入列表
//        [self.downloadingModels addObjectsFromArray:array];
//        [self.downloadAllModels addObjectsFromArray:array];
//    }
}

// 下载model字典
- (NSMutableDictionary *)downloadingModelDic
{
    if (!_downloadingModelDic) {
        _downloadingModelDic = [NSMutableDictionary dictionary];
    }
    return _downloadingModelDic;
}

// 等待下载model队列
- (NSMutableArray *)waitingDownloadModels
{
    if (!_waitingDownloadModels) {
        _waitingDownloadModels = [NSMutableArray array];
    }
    return _waitingDownloadModels;
}

// 正在下载model队列
- (NSMutableArray *)downloadingModels
{
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray array];
    }
    return _downloadingModels;
}

// 正在下载model队列
- (NSMutableArray *)downloadAllModels
{
    if (!_downloadAllModels) {
        _downloadAllModels = [NSMutableArray array];
    }
    return _downloadAllModels;
}

#pragma mark - downlaod

// 开始下载
- (TTDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(TTDownloadProgressBlock)progress state:(TTDownloadStateBlock)state
{
    // 验证下载地址
    if (!URLString) {
        NSLog(@"dwonloadURL can't nil");
        return nil;
    }
    
    TTDownloadModel *downloadModel = [self downLoadingModelForURLString:URLString];
    
    if (!downloadModel || ![downloadModel.filePath isEqualToString:destinationPath]) {
        downloadModel = [[TTDownloadModel alloc]initWithURLString:URLString filePath:destinationPath];
    }
    
    [self startWithDownloadModel:downloadModel progress:progress state:state];
    
    return downloadModel;
}

- (void)startWithDownloadModel:(TTDownloadModel *)downloadModel progress:(TTDownloadProgressBlock)progress state:(TTDownloadStateBlock)state
{
    downloadModel.progressBlock = progress;
    downloadModel.stateBlock = state;
    
    [self startWithDownloadModel:downloadModel];
}

- (void)startWithDownloadModel:(TTDownloadModel *)downloadModel
{
    if (!downloadModel) return;
    
    BOOL result = [DatabaseTool isFileModelInDB:downloadModel.uniquenName movieType:downloadModel.movieType];///已经下载过一次
    if(result){//已经下载过一次该音乐
        NSLog(@"--该文件已下载，是否重新下载？--");
        return;
    }
    
    //制作模型
    if (downloadModel.state == RRDownloadStateReadying) {
        [self downloadModel:downloadModel didChangeState:RRDownloadStateReadying filePath:nil error:nil];
        return;
    }
    
    // 验证是否已经下载文件
    if ([self isDownloadCompletedWithDownloadModel:downloadModel]) {
        downloadModel.state = RRDownloadStateCompleted;
        [self downloadModel:downloadModel didChangeState:RRDownloadStateCompleted filePath:downloadModel.filePath error:nil];
        return;
    }
    
    // 验证是否存在
    if (downloadModel.task && downloadModel.task.state == NSURLSessionTaskStateRunning) {
        downloadModel.state = RRDownloadStateRunning;
        [self downloadModel:downloadModel didChangeState:RRDownloadStateRunning filePath:nil error:nil];
        return;
    }
    
    downloadModel.title = [downloadModel.title stringByReplacingOccurrencesOfString:@" " withString:@""];
#pragma mark -- 加入下载列表
    [DatabaseTool addDownModel:downloadModel];
    
    [self resumeWithDownloadModel:downloadModel];
}

// 自动下载下一个等待队列任务
- (void)willResumeNextWithDowloadModel:(TTDownloadModel *)downloadModel
{
    if (_isBatchDownload)  return;
    
    @synchronized (self) {//暂定时不能移除，不知道下载完成后，能不能移除？？？
        [self.downloadingModels removeObject:downloadModel];
        // 还有未下载的
        if (self.waitingDownloadModels.count > 0) {
            TTDownloadModel *model =  [self.waitingDownloadModels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", RRDownloadStateReadying]].firstObject;
            [self resumeWithDownloadModel:model];
        }
    }
}

// 是否开启下载等待队列任务
- (BOOL)canResumeDownlaodModel:(TTDownloadModel *)downloadModel
{
    if (_isBatchDownload) {
        return YES;
    }
    
    @synchronized (self) {
        if (self.downloadingModels.count >= _maxDownloadCount ) {
            if ([self.waitingDownloadModels indexOfObject:downloadModel] == NSNotFound) {
                [self.waitingDownloadModels addObject:downloadModel];
                if ([self.downloadAllModels indexOfObject:downloadModel] == NSNotFound) {
                    [self.downloadAllModels addObject:downloadModel];
                }
                if(downloadModel.downloadURL != nil){
                    self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
                }
            }
            downloadModel.state = RRDownloadStateReadying;
            [self downloadModel:downloadModel didChangeState:RRDownloadStateReadying filePath:nil error:nil];
            return NO;
        }
        
        if ([self.waitingDownloadModels indexOfObject:downloadModel] != NSNotFound) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        
        if ([self.downloadingModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadingModels addObject:downloadModel];
        }
        
        if ([self.downloadAllModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadAllModels addObject:downloadModel];
        }
        return YES;
    }
}

// 恢复下载
- (void)resumeWithDownloadModel:(TTDownloadModel *)downloadModel
{
    if (downloadModel == nil) return;
    
    if (![self canResumeDownlaodModel:downloadModel])   return;
    
    if(downloadModel.downloadURL.length !=0 || downloadModel.urlArray.count != 0){//有url就不去重新请求了
        [self resumeRealDownloadModel:downloadModel];
    }else{
        __weak __typeof(self)weakSelf = self;
//        [MainGetPlayUrl getUrlWithSeasonId:downloadModel.movieId episodeSid:downloadModel.episodeSid quality:downloadModel.quality movieType:downloadModel.movieType isLocal:YES andBlock:^(urlDataModel *data, NSError *error) {
//            //            data.listModel.m3u8.url = @"http://pl.youku.com/playlist/m3u8?ctype=12&ep=cCaVGE6OUc8H4ircjj8bMiuwdH8KXJZ0vESH%2f7YbAMZuNaHQmjbTwg%3d%3d&ev=1&keyframe=1&oip=996949050&sid=241273717793612e7b085&token=3825&type=hd2&vid=XNzk2NTI0MzMy";
//            NSString *m3u8Url = data.listModel.m3u8.url;
//            NSLog(@"--获取下载地址OK--m3u8--%@--error:%@",m3u8Url,error);
//            if (!error && data.listModel) {
//                NSString *name  = @"";
//                if ([m3u8Url.lowercaseString rangeOfString:@"m3u8"].location != NSNotFound || [m3u8Url.lowercaseString rangeOfString:@"tss=ios"].location != NSNotFound) {
//                    downloadModel.urlType = UrlM3u8;
//                    name = [NSString stringWithFormat:@"%@",downloadModel.uniquenName];//存储硬盘上的的名字
//                }else{
//                    downloadModel.urlType = UrlHttp;
//                    name = [NSString stringWithFormat:@"%@.mp4",downloadModel.uniquenName];//存储硬盘上的的名字
//                }
//
//
//                //头信息
//                [self adddownHeader:downloadModel data:data];
//
//#pragma mark --- List 的下载
//                if(data.listModel.m3u8.qqPlayArr.count > 0 && data.listModel.m3u8.url.length == 0){//list
//                    downloadModel.urlArray = data.listModel.m3u8.qqPlayArr;
//                    downloadModel.total_filesize = data.listModel.m3u8.total_filesize;
//                }else{
//                    downloadModel.downloadURL = data.listModel.m3u8.url;
//                }
//                //制作模型
//                downloadModel.title = [downloadModel.title stringByReplacingOccurrencesOfString:@" " withString:@""];//替换空格
//                downloadModel.fileName = name;
//                [DatabaseTool updateRealUrl:downloadModel];//更新最新的下载地址
//                [weakSelf resumeRealDownloadModel:downloadModel];
//            }else{
//                NSLog(@"没有下载地址");
//                // 下载失败
//                dispatch_async(dispatch_get_main_queue(), ^(){
//                    downloadModel.state = RRDownloadStateFailed;
//                    [self downloadModel:downloadModel didChangeState:RRDownloadStateFailed filePath:nil error:error];
//                    [self willResumeNextWithDowloadModel:downloadModel];
//                });
//            }
//        }];
    }
}

#pragma mark 字符串转json
- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString{
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err){
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

-(void)resumeRealDownloadModel:(TTDownloadModel *)downloadModel
{
#pragma mark - 下载 3.0
    NSString *name  = downloadModel.fileName;
    downloadModel.time = [DownloadTool dateStr];
    NSString *baseTargetPath = [DownloadTool getCrTargetPath:@""];
    downloadModel.filePath = [baseTargetPath stringByAppendingPathComponent:name];;
    NSString *baseTempPath = [DownloadTool getCrTempPath:@""];
    downloadModel.tempPath = [baseTempPath stringByAppendingPathComponent:name];
    
    // 如果task 不存在 或者 取消了
    if (!downloadModel.task || downloadModel.task.state == NSURLSessionTaskStateCanceling) {
        if(downloadModel.urlArray.count){
            downloadModel.downloadURL = downloadModel.urlArray.firstObject;
        }
        if (downloadModel.downloadURL.length == 0) {  return; }
        // 创建请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:downloadModel.downloadURL]];
        //        request.timeoutInterval = 320.0;
        
        
        //添加头信息
        if (downloadModel.downHeader) {
            NSArray * keys = [downloadModel.downHeader allKeys];
            for (NSString * key in keys) {
                NSString * value = downloadModel.downHeader[key];
                
                NSLog(@"--key:%@,value:%@",key,value);
                if (key.length && value.length) {
                    [request setValue:value forHTTPHeaderField:key];
                }
            }
        }
        
        // 不使用缓存，避免断点续传出现问题
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
        
        NSLog(@"---name:%@,episode:%d-sizeHadDown:%lld---",downloadModel.title,downloadModel.episode,[self fileSizeWithDownloadModel:downloadModel]);
        // 设置请求头
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-", [self fileSizeWithDownloadModel:downloadModel]];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        // 创建流
        downloadModel.stream = [NSOutputStream outputStreamToFileAtPath:downloadModel.tempPath append:YES];
        
        downloadModel.downloadDate = [NSDate date];
        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
        // 创建一个Data任务
        downloadModel.task = [self.session dataTaskWithRequest:request];
        downloadModel.task.taskDescription = downloadModel.downloadURL;
    }
    
#pragma mark --- list的下载
    if (downloadModel.urlArray.count) {//list的下载
        TTListDownloadManager *mgr = [TTListDownloadManager manager];
        mgr.delegate = self;
        downloadModel.state = RRDownloadStateRunning;
        [mgr praseList:downloadModel];
        [self downloadModel:downloadModel didChangeState:RRDownloadStateRunning filePath:nil error:nil];
        return;
    }
    
    if (downloadModel.urlType == UrlM3u8){//m3u8下载开始
        TTM3u8DownloadManager *mgr = [TTM3u8DownloadManager manager];
        mgr.delegate = self;
        downloadModel.state = RRDownloadStateRunning;
        [mgr praseUrl:downloadModel];
        [self downloadModel:downloadModel didChangeState:RRDownloadStateRunning filePath:nil error:nil];
        return;
    }
    
    downloadModel.downloadDate = [NSDate date];//这个时间需要设为最新值
    [downloadModel.task resume];
    
    downloadModel.state = RRDownloadStateRunning;
    [self downloadModel:downloadModel didChangeState:RRDownloadStateRunning filePath:nil error:nil];
}


-(void)resumeAllTasks
{
    if (!self.downloadAllModels) return;
    
    NSMutableArray *all = [NSMutableArray arrayWithArray:self.downloadAllModels];
    [all removeObjectsInArray:self.downloadingModels];
    [all removeObjectsInArray:self.waitingDownloadModels];
    [self.waitingDownloadModels addObjectsFromArray:all];
    
    for (RRDownloadModel *m in self.waitingDownloadModels) {
        m.state = RRDownloadStateReadying;
        [self downloadModel:m didChangeState:RRDownloadStateReadying filePath:nil error:nil];
    }
    if (self.downloadingModels.count == 1) return;
    
    for (RRDownloadModel *model in self.downloadAllModels) {
        [self resumeWithDownloadModel:model];
    }
}

// 暂停下载
- (void)suspendWithDownloadModel:(TTDownloadModel *)downloadModel
{
    if(downloadModel.urlArray.count){//List 下载
        downloadModel.state = RRDownloadStateSuspended;
        [[RRListDownloadManager manager] suspendAllTasks];
        [self downloadModel:downloadModel didChangeState:RRDownloadStateSuspended filePath:nil error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^(){//开启下一个的下载
            [self willResumeNextWithDowloadModel:downloadModel];
        });
        return;
    }
    
    if(downloadModel.urlArray.count){//list的下载
        downloadModel.state = RRDownloadStateSuspended;
        [[RRListDownloadManager manager] suspendAllTasks];
        [self downloadModel:downloadModel didChangeState:RRDownloadStateSuspended filePath:nil error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^(){//开启下一个的下载
            [self willResumeNextWithDowloadModel:downloadModel];
        });
        return;
    }
    
    if(downloadModel.urlType == UrlM3u8){
        downloadModel.state = RRDownloadStateSuspended;
        [[RRM3u8DownloadManager manager] suspendAllTasks];
        [self downloadModel:downloadModel didChangeState:RRDownloadStateSuspended filePath:nil error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^(){//开启下一个的下载
            [self willResumeNextWithDowloadModel:downloadModel];
        });
        return;
    }
    
    if(!downloadModel.task) return;
    
    if (!downloadModel.manualCancle) {
        downloadModel.manualCancle = YES;
        [downloadModel.task cancel];
        [DatabaseTool updateDownTotalSize:downloadModel];//暂停时，记录进度值
    }
}

-(void)waitWithDownloadModel:(TTDownloadModel *)downloadModel
{
    if(self.downloadingModels.count >= 1) return;
    //    if (self.waitingDownloadModels.count < 1) return;
    
    [self resumeWithDownloadModel:downloadModel];
}

-(void)suspendAllTasks
{
    if (!self.downloadAllModels) return;
    if (!_downloadingModels || self.downloadingModels.count == 0) return;
    
    
    self.isBatchDownload = YES;
    [self.downloadingModels removeAllObjects];
    
    for (RRDownloadModel *downloadModel in self.downloadAllModels) {
        if(downloadModel.urlArray.count){//list的下载
            [[RRListDownloadManager manager] suspendAllTasks];
        }else{
            if(downloadModel.urlType == UrlM3u8){
                [[RRM3u8DownloadManager manager] suspendAllTasks];
            }else{
                [downloadModel.task suspend];
                if (downloadModel.task) {
                    [DatabaseTool updateDownTotalSize:downloadModel];
                }
            }
        }
        
        downloadModel.state = RRDownloadStateSuspended;
        [self downloadModel:downloadModel didChangeState:RRDownloadStateSuspended filePath:downloadModel.filePath error:nil];
    }
    self.isBatchDownload = NO;
}

// 取消所有完成或失败后台task
-(void)cancleAllTasks
{
    if (!self.downloadingModels.count) return;
    [self.downloadingModels removeAllObjects];
    
    self.isBatchDownload = YES;
    for (RRDownloadModel *downloadModel in self.downloadingModels) {
        if (downloadModel.state != RRDownloadStateCompleted && downloadModel.state != RRDownloadStateFailed){
            [downloadModel.task cancel];
        }
    }
    self.isBatchDownload = NO;
}

#pragma mark -- 删除全部的任务
-(void)deleteAllTasks
{
    if (!self.downloadingModels.count) return;
    
    for (RRDownloadModel *downloadModel in self.downloadingModels) {
        if (downloadModel.state != RRDownloadStateCompleted && downloadModel.state != RRDownloadStateFailed){
            [downloadModel.task cancel];
        }
    }
    
    [self.downloadAllModels removeAllObjects];
    [self.downloadingModels removeAllObjects];
    [self.waitingDownloadModels removeAllObjects];
    
    //删除数据库
    [DatabaseTool delALLNotDownComplete];
}


#pragma mark - delete file
//批量删除
- (void)deleteFileWithDownloadModels:(NSArray *)array
{
    if (!array.count) return;
    
    for (RRDownloadModel *model in array) {
        [self deleteFileWithDownloadModel:model];
    }
    
    //开始未下载的
    if (self.waitingDownloadModels.count > 0) {
        RRDownloadModel *model =  [self.waitingDownloadModels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", RRDownloadStateReadying]].firstObject;
        [self resumeWithDownloadModel:model];
    }
}


- (void)deleteFileWithDownloadModel:(TTDownloadModel *)downloadModel
{
    if (!downloadModel)  return;
    
    downloadModel.task ? [self.downloadingModels removeAllObjects] : nil;
    [self.waitingDownloadModels removeObject:downloadModel];
    
    if (downloadModel.urlArray.count) {
        [[RRListDownloadManager manager] deleteAllTasks];
    }else{
        //如果还没有开始下载，是不能知道是不是m3u8的，所以这里进不来,并且这里不能return，否则删除不了沙盒
        if (downloadModel.urlType == UrlM3u8) {
            [[RRM3u8DownloadManager manager] deleteAllTasks];
        }
    }
    
    // 删除任务
    downloadModel.task.taskDescription = nil;
    [downloadModel.task cancel];
    downloadModel.task = nil;
    
    // 删除流
    if (downloadModel.stream.streamStatus > NSStreamStatusNotOpen && downloadModel.stream.streamStatus < NSStreamStatusClosed) {
        [downloadModel.stream close];
    }
    downloadModel.stream = nil;
    // 删除沙盒中的资源
    NSError *error = nil;
    
    if([self.fileManager fileExistsAtPath:downloadModel.tempPath] && ![downloadModel.filePath.lastPathComponent isEqualToString:@"Temp"]){
        [self.fileManager removeItemAtPath:downloadModel.tempPath error:&error];
    }
    if([self.fileManager fileExistsAtPath:downloadModel.filePath] && ![downloadModel.filePath.lastPathComponent isEqualToString:@"Video"]){
        [self.fileManager removeItemAtPath:downloadModel.filePath error:&error];
    }
    if (error) {
        NSLog(@"delete file error %@",error);
    }
    
    [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
    // 删除资源总长度
    @synchronized (self) {
        //删除数据库
        [DatabaseTool delFileModelWithUniquenName:downloadModel.uniquenName];
    }
    
    NSLog(@"-waitingDownloadModels-:%lu",(unsigned long)self.waitingDownloadModels.count);
}

#pragma mark - public

// 获取下载模型
- (TTDownloadModel *)downLoadingModelForURLString:(NSString *)URLString
{
    if (URLString == nil || URLString.length == 0 ) return nil;
    return [self.downloadingModelDic objectForKey:URLString];
}

// 是否已经下载
- (BOOL)isDownloadCompletedWithDownloadModel:(TTDownloadModel *)downloadModel
{
    long long fileSize = downloadModel.progress.totalBytesExpectedToWrite;//[self fileSizeInCachePlistWithDownloadModel:downloadModel];
    if (fileSize > 0 && fileSize == [self fileSizeWithDownloadModel:downloadModel]) {
        return YES;
    }
    return NO;
}

#pragma mark - private

- (void)downloadModel:(TTDownloadModel *)downloadModel didChangeState:(RRDownloadState)state filePath:(NSString *)filePath error:(NSError *)error
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {
        [_delegate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];
    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state,filePath,error);
    }
}

- (void)downloadModel:(TTDownloadModel *)downloadModel updateProgress:(TTDownloadProgress *)progress
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
        [_delegate downloadModel:downloadModel didUpdateProgress:progress];
    }
    
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}


// 获取文件大小 -- 获取已缓存的文件大小，如果已经存在已缓存的文件，就追加，没有就从头开始下载
- (long long)fileSizeWithDownloadModel:(TTDownloadModel *)downloadModel{
    NSString *filePath = downloadModel.tempPath;
    if (![self.fileManager fileExistsAtPath:filePath]) return 0;
    return [[self.fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
}

- (void)removeDownLoadingModelForURLString:(NSString *)URLString
{
    if (URLString == nil || URLString.length == 0) return;
    [self.downloadingModelDic removeObjectForKey:URLString];
}

#pragma mark -- 真正的开始下载

#pragma mark - NSURLSessionDelegate

#pragma mark - 接收到响应

/**
 * 接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel) {
        return;
    }
    
    NSString *codeStr = [NSString stringWithFormat:@"%ld",(long)response.statusCode];
    if (response.statusCode == 403 || response.statusCode == 424 || response.statusCode == 404 || [codeStr hasPrefix:@"4"] || [codeStr hasPrefix:@"5"]){
        NSLog(@"--response error 403--");
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = RRDownloadStateFailed;
            NSError *errr = [NSError errorWithDomain:NSURLErrorDomain code:-999 userInfo:@{NSURLErrorFailingURLStringErrorKey : @"请求地址失败403"}];
            [self downloadModel:downloadModel didChangeState:RRDownloadStateFailed filePath:nil error:errr];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
        
        return;
    }
    // 打开流
    [downloadModel.stream open];
    
    // 获得服务器这次请求 返回数据的总长度
    long long totalBytesWritten =  [self fileSizeWithDownloadModel:downloadModel];
    long long totalBytesExpectedToWrite = totalBytesWritten + dataTask.countOfBytesExpectedToReceive;
    
    downloadModel.progress.resumeBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    downloadModel.fileSize =[NSString stringWithFormat:@"%lld",totalBytesExpectedToWrite];
    downloadModel.fileReceivedSize = [NSString stringWithFormat:@"%lld",totalBytesWritten];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

#pragma mark - 接收到服务器返回的数据

/**
 * 接收到服务器返回的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel || downloadModel.state == RRDownloadStateSuspended) {
        return;
    }
    // 写入数据
    [downloadModel.stream write:data.bytes maxLength:data.length];
    
    // 下载进度
    downloadModel.progress.bytesWritten = data.length;
    downloadModel.progress.totalBytesWritten += downloadModel.progress.bytesWritten;
    downloadModel.progress.progress  = MIN(1.0, 1.0*downloadModel.progress.totalBytesWritten/downloadModel.progress.totalBytesExpectedToWrite);
    
    // 时间
    NSTimeInterval downloadTime = -1 * [downloadModel.downloadDate timeIntervalSinceNow];
    
    downloadModel.progress.speed = (downloadModel.progress.totalBytesWritten - downloadModel.progress.resumeBytesWritten) / downloadTime;
    
    int64_t remainingContentLength = downloadModel.progress.totalBytesExpectedToWrite - downloadModel.progress.totalBytesWritten;
    downloadModel.progress.remainingTime = ceilf(remainingContentLength / downloadModel.progress.speed);
    
    //防止进度调用过多的保护措施
    if (self.timesCount ++ <= 30) return;
    NSLog(@"--http-%@-%d , progress: %f",downloadModel.title,downloadModel.episode,downloadModel.progress.progress);
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });
    self.timesCount = 0;
}

#pragma mark - 请求完毕（成功|失败） -- 取消下载后也会调用，这时error不为空
/**
 * 请求完毕（成功|失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:task.taskDescription];
    NSLog(@"---下载失败/成功---name:%@,episode:%d,error:%@--",downloadModel.title,downloadModel.episode,error);
    
    if (!downloadModel) {   return;  }
    
    // 关闭流
    [downloadModel.stream close];
    downloadModel.stream = nil;
    downloadModel.task = nil;
    
    [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
    
    if (downloadModel.manualCancle) { // 暂定下载
        // 暂停下载
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.manualCancle = NO;
            downloadModel.state = RRDownloadStateSuspended;
            [self downloadModel:downloadModel didChangeState:RRDownloadStateSuspended filePath:nil error:nil];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else if (error){
        // 下载失败
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = RRDownloadStateFailed;
            [self downloadModel:downloadModel didChangeState:RRDownloadStateFailed filePath:nil error:error];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else if ([self isDownloadCompletedWithDownloadModel:downloadModel]) {
        // 下载完成
        [self downloadcomplate:downloadModel];
    }else {
        // 下载完成
        [self downloadcomplate:downloadModel];
    }
}

#pragma mark -- 下载完成
//下载完成后的一些处理方法
-(void)downloadcomplate:(TTDownloadModel *)downloadModel {
    if(downloadModel.state == RRDownloadStateFailed){
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.timesCount = 0;//制零，重新计数
        // 下载完成
        [DatabaseTool updateDownModeWhenDownFinish:downloadModel];
        
        [self moveFileAtURL:downloadModel.tempPath toPath:downloadModel.filePath];
        
        downloadModel.state = RRDownloadStateCompleted;
        
#pragma mark -- 下载完成
        if (self.waitingDownloadModels.count == 0) {
            if ([self.delegate respondsToSelector:@selector(downloadDidCompleted:)]) {
                [self.delegate downloadDidCompleted:downloadModel];
            }
        }
        [self.downloadingModels removeObject:downloadModel];
        [self.downloadAllModels removeObject:downloadModel];//下载完毕后，移除总数组，
        
        downloadModel.state = RRDownloadStateCompleted;
        [self m3u8DownloadModel:downloadModel didUpdateProgress:downloadModel.progress];
        [self downloadModel:downloadModel didChangeState:RRDownloadStateCompleted filePath:downloadModel.filePath error:nil];
        [self willResumeNextWithDowloadModel:downloadModel];
    });
}

- (void)moveFileAtURL:(NSString *)srcURL toPath:(NSString *)dstPath {
    if (!dstPath) {
        NSLog(@"error filePath is nil!");
        return;
    }
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:dstPath] ) {
        [self.fileManager removeItemAtPath:dstPath error:&error];
        if (error) {
            NSLog(@"removeItem error %@",error);
        }
    }
    
    [self.fileManager moveItemAtPath:srcURL toPath:dstPath error:&error];
    if (error){
        NSLog(@"moveItem error:%@",error);
    }
}


#pragma mark -- m3u8的下载代理

// 更新下载进度
- (void)m3u8DownloadModel:(TTDownloadModel *)downloadModel didUpdateProgress:(TTDownloadProgress *)progress {
    downloadModel.progress = progress;
    
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
        [_delegate downloadModel:downloadModel didUpdateProgress:progress];
    }
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}

// 更新下载状态
- (void)m3u8DownloadModel:(TTDownloadModel *)downloadModel didChangeState:(TTDownloadState)state filePath:(NSString *)filePath error:(NSError *)error {
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {
        [_delegate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];
    }
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state,filePath,error);
    }
    if (downloadModel.state == RRDownloadStateFailed) {//下载失败，开启下一个的下载
        [self willResumeNextWithDowloadModel:downloadModel];
    }
}

// 下载完毕
- (void)m3u8DownloadDidCompleted:(TTDownloadModel *)downloadModel {
    [self.downloadAllModels removeObject:downloadModel];//下载完毕后，移除总数组，
    [self m3u8DownloadModel:downloadModel didUpdateProgress:downloadModel.progress];
    [self.downloadingModels removeObject:downloadModel];
    
    [self willResumeNextWithDowloadModel:downloadModel];
}

#pragma mark -- list的下载代理

// 更新下载进度
- (void)listDownloadModel:(TTDownloadModel *)downloadModel didUpdateProgress:(TTDownloadProgress *)progress {
    [self m3u8DownloadModel:downloadModel didUpdateProgress:progress];
}

// 更新下载状态
- (void)listDownloadModel:(TTDownloadModel *)downloadModel didChangeState:(RRDownloadState)state filePath:(NSString *)filePath error:(NSError *)error {
    [self m3u8DownloadModel:downloadModel didChangeState:state filePath:filePath error:error];
}

// 下载完毕
- (void)listDownloadDidCompleted:(TTDownloadModel *)downloadModel {
    [self m3u8DownloadDidCompleted:downloadModel];
}
@end
