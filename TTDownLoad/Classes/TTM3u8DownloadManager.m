//
//  TTM3u8DownloadManager.m
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import "TTM3u8DownloadManager.h"

//#import "RegexKitLite.h"
#import <CommonCrypto/CommonDigest.h>
#import "DownLoadTools.h"
#import "WdCleanCaches.h"

#pragma mark --- RRM3u8DownloadManager

@interface TTM3u8DownloadManager()


// >>>>>>>>>>>>>>>>>>>>>>>>>>  file info
// 文件管理
@property (nonatomic, strong) NSFileManager *fileManager;
//// 缓存文件目录
//@property (nonatomic, strong) NSString *downloadDirectory;

// >>>>>>>>>>>>>>>>>>>>>>>>>>  session info
// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url, value = model
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 下载中 + 等待中的模型 只读
@property (nonatomic, strong) NSMutableArray *downloadAllModels;

// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;

//总共有多少片段
@property (nonatomic,assign)NSInteger totalCount;

//用于下载m3u8的对象的task
@property (nonatomic,strong)NSURLSessionDataTask *m3u8Task;

@property (nonatomic,strong)TTDownloadModel * downloaingModel;

// 最大下载数
@property (nonatomic, assign) NSInteger maxDownloadCount;

// 全部并发 默认NO, 当YES时，忽略maxDownloadCount
@property (nonatomic, assign) BOOL isBatchDownload;

/* 用于计数 -- 不让进度调用的方法过于频繁 */
@property (nonatomic,assign)NSInteger timesCount;

@end

#define IS_IOS8ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)


@implementation TTM3u8DownloadManager
{
    /**
     *  后台进程id
     */
    UIBackgroundTaskIdentifier  _backgroudTaskId;
}


+ (RRM3u8DownloadManager *)manager
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - m3u8的下载

//解析m3u8的内容
-(void)praseUrl:(TTDownloadModel *)downloadModel
{
    [self.waitingDownloadModels removeAllObjects];
    [self.downloadAllModels removeAllObjects];
    [self.downloadingModelDic removeAllObjects];
    [self.downloadingModels removeAllObjects];
    self.totalCount = 0;
    
    self.downloaingModel = downloadModel;
    NSString *urlstr = downloadModel.downloadURL;
    if (urlstr == nil || urlstr.length == 0) return;
    
    NSURL *url = [NSURL URLWithString:urlstr];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12.0];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSString *aString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [self returenDataOk:aString oUrl:urlstr downloadModel:downloadModel];
        }else{//下载失败
            dispatch_async(dispatch_get_main_queue(), ^(){
                downloadModel.state = RRDownloadStateFailed;
                [self downloadModel:downloadModel didChangeState:RRDownloadStateFailed filePath:nil error:error];
            });
            return ;
        }
    }];
    self.m3u8Task = task;
    [task resume];
}

-(void)returenDataOk:(NSString *)data oUrl:(NSString *)oUrl downloadModel:(RRDownloadModel *)downloadModel{
    if(data == nil) return;
    
    __block int i = 0;
    
    [self saveM3u8Plist:downloadModel data:data];//存储视频总长度
#pragma - mark  到数据库中查找是否有片段没有下载完毕
    int segmentHadDown = [DatabaseTool getMovieHadDownSegment:downloadModel.uniquenName];
    
    //正序取
    NSArray *arr = [oUrl componentsSeparatedByString:@"/"];
    NSString *firstStr = oUrl;
    if (arr.count > 4) {
        firstStr = arr[3];
        NSRange range = [oUrl rangeOfString:firstStr options:NSCaseInsensitiveSearch];
        NSRange backRange = NSMakeRange(0, range.location+range.length);
        firstStr = [oUrl substringWithRange:backRange];
    }
    
    //倒序取
    NSRange range = [oUrl rangeOfString:@"/" options:NSBackwardsSearch];
    NSRange backRange = NSMakeRange(range.location+1, oUrl.length-range.location-1);
    //倒数的最后一个“/”的字符串
    NSString *backLastStr = [oUrl substringWithRange:backRange];
    
    //换行后，以#开头
    NSString *httpPattern = @"[\n](/)?[a-zA-z1-9]+[^\\s]*";//@"[a-zA-z]+://[^\\s]*";//匹配http地址
    // 遍历所有的匹配结果
    [data enumerateStringsMatchedByRegex:httpPattern usingBlock:^(NSInteger captureCount, NSString *const __unsafe_unretained *capturedStrings, const NSRange *capturedRanges, volatile BOOL *const stop) {
        
        NSString *urlStr = *capturedStrings;
        urlStr =  [urlStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        
        if ([urlStr containsString:@"http://"]) {
            //什么也不用做
        }else if([urlStr containsString:@"/"]){//包含但斜杠的
            urlStr = [firstStr stringByAppendingPathComponent:urlStr];
        }else{  //什么都不包含的。
            urlStr = [oUrl stringByReplacingOccurrencesOfString:backLastStr withString:urlStr];
        }
        
        //        DLog(@"--part-url:%@",urlStr);
        NSString *tsName = [NSString stringWithFormat:@"id%d.ts",i];
        
        if (i >= segmentHadDown) {//必须用新模型
            RRDownloadModel *model = [self getNewModel:downloadModel];
            model.downloadURL = urlStr;
            model.fileName = tsName;
            //
            NSString *name = [NSString stringWithFormat:@"%@",downloadModel.uniquenName];//存储硬盘上的的名字
            NSString *baseTargetPath = [DownLoadTools getCrTargetPath:name];
            model.filePath = baseTargetPath;
            NSString *baseTempPath = [DownLoadTools getCrTempPath:name];
            model.tempPath = baseTempPath;
            
            //
            model.filePath = [NSString stringWithFormat:@"%@/%@",model.filePath,tsName] ;
            model.tempPath =[NSString stringWithFormat:@"%@/%@",model.tempPath,tsName] ;
            [self startWithDownloadModel:model];
        }
        
        i++;
    }];
    
    self.totalCount = i > 0 ? MAX(i - segmentHadDown, 0) : 0;
    DLog(@"\n \n \n ---------------------total count:%d",i);
    if (self.totalCount == 0 || self.waitingDownloadModels.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = RRDownloadStateFailed;
            NSError *errr = [NSError errorWithDomain:NSURLErrorDomain code:-999 userInfo:@{NSURLErrorFailingURLStringErrorKey : @"m3u8没有可用的子链接"}];
            [self downloadModel:self.downloaingModel didChangeState:RRDownloadStateFailed filePath:nil error:errr];
        });
    }
}

-(void)saveM3u8Plist:(RRDownloadModel *)model data:(NSString *)data
{
    //写m3u8文件   不能手动更改本地m3u8文件格式，以原来的文件为基础进行替换，否则下载好，无法读取
    NSString *pathPrefix = [DownLoadTools getDownBasePath];
    NSString *tempTo = [[pathPrefix stringByAppendingPathComponent:@"Temp"] stringByAppendingPathComponent:model.uniquenName];
    
    NSString *fullpath = [tempTo stringByAppendingPathComponent:@"movie.m3u8"];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir2 = NO;
    if(!([fm fileExistsAtPath:tempTo isDirectory:&isDir2] && isDir2))  {
        [fm createDirectoryAtPath:tempTo withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSError *werror = nil;
    BOOL bSucc = [data writeToFile:fullpath atomically:YES encoding:NSUTF8StringEncoding error:&werror];
    
    if(bSucc) {
        DLog(@"create original m3u8file succeed; fullpath:%@, content:",fullpath);
    } else  {
        DLog(@"create original m3u8file failed:%@",werror);
    }
}

-(RRDownloadModel *)getNewModel:(RRDownloadModel *)oldModel
{
    RRDownloadModel *model = [[RRDownloadModel alloc]init];
    model.uniquenName = oldModel.uniquenName;
    model.movieId = oldModel.movieId;
    model.episode = oldModel.episode;
    model.urlType = oldModel.urlType;
    model.movieType = oldModel.movieType;
    model.time = oldModel.time;
    model.quality = oldModel.quality;
    model.title = oldModel.title;
    model.iconUrl = oldModel.iconUrl;
    model.downloadURL = oldModel.downloadURL;
    model.fileName = oldModel.fileName;
    model.downHeader = oldModel.downHeader;
    return model;
}

#pragma mark - 修改已经下载好的m3u8文件
- (void)createLocalM3U8file:(RRDownloadModel *)model
{
    NSString *pathPrefix = [DownLoadTools getDownBasePath];
    NSString *saveTo = [[pathPrefix stringByAppendingPathComponent:@"Temp"] stringByAppendingPathComponent:model.uniquenName];
    
    NSString *fullpath = [saveTo stringByAppendingPathComponent:@"movie.m3u8"];
    //UTF-8编码
    __block NSString *str = [NSString stringWithContentsOfFile:fullpath encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableArray *httpArray = [NSMutableArray array];
    NSString* segmentPrefix = [NSString stringWithFormat:@"%@/%@/",KLocaPlaylUrl,model.uniquenName];
    //填充片段数据
    for(int i = 0;i< self.totalCount;i++) {
        NSString* filename = [NSString stringWithFormat:@"id%d.ts",i];
        NSString* url = [segmentPrefix stringByAppendingString:filename];
        [httpArray addObject:url];
    }
    
    NSString *httpPattern =  @"[\n](/)?[a-zA-z1-9]+[^\\s]*";//@"[a-zA-z]+://[^\\s]*";//匹配http地址
    // 遍历所有的匹配结果
    __block int index = 0;
    [str enumerateStringsMatchedByRegex:httpPattern usingBlock:^(NSInteger captureCount, NSString *const __unsafe_unretained *capturedStrings, const NSRange *capturedRanges, volatile BOOL *const stop) {
        NSString* segmentPrefix = [NSString stringWithFormat:@"%@%@/%@/%@/",KLocaPlaylUrl,kDownDomanPath,kDownTargetPath,model.uniquenName];
        //        NSString* filename = [segmentPrefix stringByAppendingPathComponent:[NSString stringWithFormat:@"id%d.ts",index]];//这个会把http://置换为http:/  what fuck this
        NSString* filename = [segmentPrefix stringByAppendingString:[NSString stringWithFormat:@"id%d.ts",index]];
        NSString *ourl = *capturedStrings ;
        if ([ourl hasPrefix:@"\n"]) {
            filename = [NSString stringWithFormat:@"\n%@",filename];
        }
        str = [str stringByReplacingOccurrencesOfString:ourl withString:filename];
        index ++;
    }];
    BOOL bSucc =[str writeToFile:fullpath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if(bSucc) {
        DLog(@"chang local movie.m3u8 file succeed; fullpath:%@;",fullpath);
    }
    else  {
        DLog(@"chang local m3u8file failed");
    }
}


#pragma mark ----
#pragma mark --- 开始下载
#pragma mark ----


- (instancetype)init
{
    if (self = [super init]) {
        _maxDownloadCount = 1;
        _isBatchDownload = NO;
        _timesCount = 0;
        
        _backgroudTaskId = UIBackgroundTaskInvalid;
        //注册程序即将失去焦点的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskWillResignM3u8:) name:UIApplicationWillResignActiveNotification object:nil];
        //注册程序获得焦点的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskDidBecomActiveM3u8:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

/**
 *  收到程序即将失去焦点的通知，开启后台运行
 *
 *  @param sender 通知
 */
-(void)downloadTaskWillResignM3u8:(NSNotification *)sender{
    
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
-(void)downloadTaskDidBecomActiveM3u8:(NSNotification *)sender{
    
    if(_backgroudTaskId != UIBackgroundTaskInvalid){
        
        [[UIApplication sharedApplication] endBackgroundTask:_backgroudTaskId];
        _backgroudTaskId=UIBackgroundTaskInvalid;
    }
}

-(void)dealloc{
    [_session invalidateAndCancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc]init];
    }
    return _fileManager;
}

- (NSURLSession *)session
{
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
    }
    return _session;
}

- (NSOperationQueue *)queue
{
    if (!_queue) {
        _queue = [[NSOperationQueue alloc]init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
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
- (RRDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(RRDownloadProgressBlock)progress state:(RRDownloadStateBlock)state
{
    // 验证下载地址
    if (!URLString) {
        DLog(@"dwonloadURL can't nil");
        return nil;
    }
    
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:URLString];
    
    if (!downloadModel || ![downloadModel.filePath isEqualToString:destinationPath]) {
        downloadModel = [[RRDownloadModel alloc]initWithURLString:URLString filePath:destinationPath];
    }
    
    [self startWithDownloadModel:downloadModel progress:progress state:state];
    
    return downloadModel;
}

- (void)startWithDownloadModel:(RRDownloadModel *)downloadModel progress:(RRDownloadProgressBlock)progress state:(RRDownloadStateBlock)state
{
    downloadModel.progressBlock = progress;
    downloadModel.stateBlock = state;
    
    [self startWithDownloadModel:downloadModel];
}

- (void)startWithDownloadModel:(RRDownloadModel *)downloadModel
{
    if (!downloadModel) {
        return;
    }
#pragma mark - 下载 3.0
    //制作模型
    NSString *name  = @"";
    if (downloadModel.urlType == UrlM3u8) {
        name = [NSString stringWithFormat:@"%@",downloadModel.uniquenName];//存储硬盘上的的名字
    }else{
        name = [NSString stringWithFormat:@"%@.mp4",downloadModel.uniquenName];//存储硬盘上的的名字
    }
    downloadModel.title = [downloadModel.title stringByReplacingOccurrencesOfString:@" " withString:@""];//替换空格
    
    downloadModel.fileName = name;
    downloadModel.time = [DownLoadTools dateStr];
    
    
    if (downloadModel.state == RRDownloadStateReadying) {
        downloadModel.state = RRDownloadStateRunning;
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
    
#pragma mark -- 加入下载列表
    
    [self resumeWithDownloadModel:downloadModel];
}

// 自动下载下一个等待队列任务
- (void)willResumeNextWithDowloadModel:(RRDownloadModel *)downloadModel
{
    if (_isBatchDownload)  return;
    
    @synchronized (self) {//暂定时不能移除，不知道下载完成后，能不能移除？？？
        [self.downloadingModels removeObject:downloadModel];
        //        [self.downloadAllModels removeObject:downloadModel];
        // 还有未下载的
        if (self.waitingDownloadModels.count > 0) {
            [self resumeWithDownloadModel:self.waitingDownloadModels.firstObject];
        }
    }
}

// 是否开启下载等待队列任务
- (BOOL)canResumeDownlaodModel:(RRDownloadModel *)downloadModel
{
    if (_isBatchDownload)   return YES;
    
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
- (void)resumeWithDownloadModel:(RRDownloadModel *)downloadModel
{
    if (!downloadModel) {
        return;
    }
    
    if (![self canResumeDownlaodModel:downloadModel]) {
        return;
    }
    
    // 如果task 不存在 或者 取消了
    if (!downloadModel.task || downloadModel.task.state == NSURLSessionTaskStateCanceling) {
        NSString *URLString = downloadModel.downloadURL;
        
        // 创建请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        request.timeoutInterval = 320.0;
        
        // 不使用缓存，避免断点续传出现问题
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
        
        // 设置请求头
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-", 0];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        //添加头信息
        if (downloadModel.downHeader) {
            NSArray * keys = [downloadModel.downHeader allKeys];
            for (NSString * key in keys) {
                NSString * value = downloadModel.downHeader[key];
                
                DLog(@"--key:%@,value:%@", key, value);
                if (key.length && value.length) {
                    [request setValue:value forHTTPHeaderField:key];
                }
            }
        }
        
        // 创建流
        downloadModel.stream = [NSOutputStream outputStreamToFileAtPath:downloadModel.tempPath append:YES];
        
        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
        // 创建一个Data任务
        downloadModel.task = [self.session dataTaskWithRequest:request];
        downloadModel.task.taskDescription = URLString;
    }
    
    downloadModel.downloadDate = [NSDate date];
    [downloadModel.task resume];
    
    downloadModel.state = RRDownloadStateRunning;
    [self downloadModel:downloadModel didChangeState:RRDownloadStateRunning filePath:nil error:nil];
}

-(void)resumeAllTasks
{
    if (!self.downloadAllModels) return;
    if (self.downloadingModels.count == 1) return;
    
    for (RRDownloadModel *model in self.downloadAllModels) {
        [self resumeWithDownloadModel:model];
    }
}

-(void)suspendAllTasks
{
    if (!self.downloadingModels.count) return;
    self.downloaingModel.manualCancle = YES;
    self.isBatchDownload = YES;
    for (RRDownloadModel *downloadModel in self.downloadingModels) {
        if (downloadModel.state != RRDownloadStateCompleted && downloadModel.state != RRDownloadStateFailed){
            [downloadModel.task cancel];
        }
    }
    //保存已下载的片段到数据库
    [DatabaseTool updatePartWhenDownStoWithPprogress:self.downloaingModel.progress.progress segmentHadDown:(int)(self.totalCount- self.waitingDownloadModels.count) uniqueName:self.downloaingModel.uniquenName];
    
    [self.downloadingModels removeAllObjects];
    self.downloaingModel.state = RRDownloadStateSuspended;
    [self downloadModel:self.downloaingModel didChangeState:RRDownloadStateSuspended filePath:nil error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isBatchDownload = NO;
    });
}

#pragma mark -- 删除全部的任务
-(void)deleteAllTasks
{
    if (!self.downloadingModels.count) return;
    
    if (self.m3u8Task) {//取消正在下载m3u8的配置文件的，否则就会导致任务是取消了，但是m3u8下载还会继续
        [self.m3u8Task cancel];
    }
    
    for (RRDownloadModel *downloadModel in self.downloadingModels) {
        [downloadModel.task cancel];
    }
    
    [self.downloadAllModels removeAllObjects];
    [self.downloadingModels removeAllObjects];
    [self.waitingDownloadModels removeAllObjects];
}

#pragma mark - public

// 获取下载模型
- (RRDownloadModel *)downLoadingModelForURLString:(NSString *)URLString
{
    if (URLString == nil || URLString.length == 0) {
        return nil;
    }else{
        return [self.downloadingModelDic objectForKey:URLString];
    }
}

// 是否已经下载
- (BOOL)isDownloadCompletedWithDownloadModel:(RRDownloadModel *)downloadModel
{
    long long fileSize = downloadModel.progress.totalBytesExpectedToWrite;//[self fileSizeInCachePlistWithDownloadModel:downloadModel];
    if (fileSize > 0 && fileSize == [self fileSizeWithDownloadModel:downloadModel]) {
        return YES;
    }
    return NO;
}

#pragma mark - private

- (void)downloadModel:(RRDownloadModel *)downloadModel didChangeState:(RRDownloadState)state filePath:(NSString *)filePath error:(NSError *)error
{
    //这个速度只能是RRDownloadStateRunning，不然一会一个小片段下载完成，很烦人的，
    //    self.downloaingModel.state = RRDownloadStateRunning;
    
    if (_delegate && [_delegate respondsToSelector:@selector(m3u8DownloadModel:didChangeState:filePath:error:)]) {
        [_delegate m3u8DownloadModel:self.downloaingModel didChangeState:state filePath:filePath error:error];
    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state,filePath,error);
    }
}

- (void)downloadModel:(RRDownloadModel *)downloadModel updateProgress:(RRDownloadProgress *)progress
{
    if (_delegate && [_delegate respondsToSelector:@selector(m3u8DownloadModel:didUpdateProgress:)]) {
        [_delegate m3u8DownloadModel:self.downloaingModel didUpdateProgress:progress];
    }
    
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}

// 获取文件大小 -- 获取已缓存的文件大小，如果已经存在已缓存的文件，就追加，没有就从头开始下载
- (long long)fileSizeWithDownloadModel:(RRDownloadModel *)downloadModel{
    NSString *filePath = downloadModel.tempPath;
    if (![self.fileManager fileExistsAtPath:filePath]) return 0;
    return [[self.fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
}

- (void)removeDownLoadingModelForURLString:(NSString *)URLString
{
    if (URLString == nil || URLString.length == 0) {
        return;
    }
    [self.downloadingModelDic removeObjectForKey:URLString];
}

#pragma mark -- 真正的开始下载

#pragma mark - NSURLSessionDelegate

#pragma mark - 接收到响应

/**
 * 接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel)   return;
    
    //    NSString *codeStr = [NSString stringWithFormat:@"%ld",(long)response.statusCode];
    //    NSLog(@"---m3u8-response-code:%@",codeStr);
    
    // 打开流
    [downloadModel.stream open];
    
    // 获得服务器这次请求 返回数据的总长度
    long long totalBytesWritten =  [self fileSizeWithDownloadModel:downloadModel];
    long long totalBytesExpectedToWrite = totalBytesWritten + dataTask.countOfBytesExpectedToReceive;
    
    self.downloaingModel.progress.resumeBytesWritten = self.downloaingModel.progress.resumeBytesWritten == 0 ? totalBytesWritten : self.downloaingModel.progress.resumeBytesWritten;//==0的时候才进行赋值，
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
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel || downloadModel.state == RRDownloadStateSuspended) {
        return;
    }
    // 写入数据
    [downloadModel.stream write:data.bytes maxLength:data.length];
    
    //防止进度调用过多的保护措施
    if (self.timesCount ++ <= 120) return;
    
    // 下载进度
    downloadModel.progress.bytesWritten = data.length;
    downloadModel.progress.totalBytesWritten += downloadModel.progress.bytesWritten;
    float progress = self.totalCount == 0 ? 0.0 : 1.0 - (double)self.waitingDownloadModels.count / self.totalCount;
    downloadModel.progress.progress  = MIN(1.0, progress);
    
    DLog(@"--m3u8-%@-:%d-waitcount:%lu , progress: %f", downloadModel.title, downloadModel.episode, (unsigned long)self.waitingDownloadModels.count, downloadModel.progress.progress);
    
    // 时间
    //    NSTimeInterval downloadTime2 = -1 * [self.downloaingModel.downloadDate timeIntervalSinceNow];
    NSTimeInterval downloadTime = -1 * [downloadModel.downloadDate timeIntervalSinceNow];
    
    downloadModel.progress.speed = fabs((downloadModel.progress.totalBytesWritten - self.downloaingModel.progress.resumeBytesWritten) / downloadTime)*9;
    
    int64_t remainingContentLength = downloadModel.progress.totalBytesExpectedToWrite - downloadModel.progress.totalBytesWritten;
    downloadModel.progress.remainingTime = ceilf(remainingContentLength / downloadModel.progress.speed);
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });
    self.timesCount = 0;
}

#pragma mark - 请求完毕（成功|失败） -- 取消下载后也会调用，这时error不为空
/**
 * 请求完毕（成功|失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    RRDownloadModel *downloadModel = [self downLoadingModelForURLString:task.taskDescription];
    
    if (!downloadModel) return;
    
    // 关闭流
    [downloadModel.stream close];
    downloadModel.stream = nil;
    downloadModel.task = nil;
    
    [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
    
    if (self.downloaingModel.manualCancle) { // 暂定下载
        // 暂停下载
        dispatch_async(dispatch_get_main_queue(), ^(){
            self.downloaingModel.manualCancle = NO;
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
    //两个完成的方法，第一个先调用，第二个再调用，调用两次，，，？？？
}
//下载完成后的一些处理方法
-(void)downloadcomplate:(RRDownloadModel *)downloadModel
{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^(){
        downloadModel.state = RRDownloadStateRunning;
        [weakSelf downloadModel:downloadModel didChangeState:RRDownloadStateRunning filePath:downloadModel.filePath error:nil];
        [weakSelf willResumeNextWithDowloadModel:downloadModel];
    });
    
    if (self.waitingDownloadModels.count == 0) {//这才是正在的下载完毕
        self.timesCount = 0;//制零，重新计数
        //移动的文件
        NSString *pathPrefix = [DownLoadTools getDownBasePath];
        NSString *tempp = [[pathPrefix stringByAppendingPathComponent:@"Temp"] stringByAppendingPathComponent:self.downloaingModel.uniquenName];
        NSString *filep = [[pathPrefix stringByAppendingPathComponent:@"Video"] stringByAppendingPathComponent:self.downloaingModel.uniquenName];
        //如果没有了，说明已经移除完毕，则直接返回
        if (![self.fileManager fileExistsAtPath:tempp] )   return ;
        
#pragma mark - 下载完成的代理
        //这里的进度设置为1.1是由于，m3u8下载完毕后，需要移除，需要点时间，所以设置为1.1才是m3u8真正的下载完毕
        self.downloaingModel.progress.progress = 1.1;
        self.downloaingModel.segmentHadDown = (int)self.totalCount;
        double downedSize = [WdCleanCaches biteSizeWithPaht:[NSString getHttpDowningSize:downloadModel.uniquenName urlType:self.downloaingModel.urlType]];
        self.downloaingModel.state = RRDownloadStateCompleted;
        self.downloaingModel.fileSize = [NSString stringWithFormat:@"%f",downedSize];
        [DatabaseTool updateDownModeWhenDownFinish:self.downloaingModel];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self createLocalM3U8file:downloadModel];
            [self moveFileAtURL:tempp toPath:filep];
        });
        // 下载完成
        dispatch_async(dispatch_get_main_queue(), ^(){
#pragma mark -- 所有的待下载的片段下载完毕
            if ([self.delegate respondsToSelector:@selector(m3u8DownloadDidCompleted:)]) {
                [self.delegate m3u8DownloadDidCompleted:self.downloaingModel];
            }
        });
    }
}

- (void)moveFileAtURL:(NSString *)srcURL toPath:(NSString *)dstPath
{
    if (!dstPath) {
        DLog(@"error filePath is nil!");
        return;
    }
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:dstPath] ) {
        [self.fileManager removeItemAtPath:dstPath error:&error];
        if (error) {
            DLog(@"removeItem error %@",error);
        }
    }
    
    [self.fileManager moveItemAtPath:srcURL toPath:dstPath error:&error];
    if (error){
        DLog(@"moveItem error:%@",error);
    }
}

@end

