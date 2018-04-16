//
//  TTDownloadModel.h
//  TTDownLoad
//
//  Created by fengtengfei on 2017/11/19.
//

#import <Foundation/Foundation.h>


// 下载状态
typedef NS_ENUM(NSUInteger, RRDownloadState) {
    RRDownloadStateNone,        // 未下载
    RRDownloadStateReadying,    // 等待下载
    RRDownloadStateRunning,     // 正在下载
    RRDownloadStateSuspended,   // 下载暂停
    RRDownloadStateCompleted,   // 下载完成
    RRDownloadStateFailed       // 下载失败
};
 
typedef enum{
    UrlM3u8 = 1,     // m3u8下载链接
    UrlHttp = 2,     // http下载链接
}UrlType;

//下载视频的类型
typedef NS_ENUM(NSInteger,MovieType) {
    MovieSeries,//美剧
    MovieVideo,//视频
    MovieSubject,//合辑 -- 本质上和视频一样
    MovieOther,//其他 - 目前无实际意义
};


@class TTDownloadProgress;
@class TTDownloadModel;

// 进度更新block
typedef void (^TTDownloadProgressBlock)(TTDownloadProgress *progress);
// 状态更新block
typedef void (^TTDownloadStateBlock)(RRDownloadState state,NSString *filePath, NSError *error);
typedef void (^TTDownloadUpdateBlock)(TTDownloadProgress *progress, RRDownloadState state,NSString *filePath, NSError *error);


#pragma mark -- TTDownloadModel

/**
 *  下载模型
 */
@interface TTDownloadModel : NSObject

// >>>>>>>>>>>>>>>>>>>>>>>>>>  download info - extra
@property (nonatomic, copy) NSString * uniquenName;//唯一, movieId+episode
@property (nonatomic, copy) NSString * movieId;//剧集id
@property (nonatomic,assign)int episode;//第几集
@property (nonatomic,copy)NSString * episodeSid;//对应episode的sid

@property (nonatomic,assign)UrlType urlType;//存储RRUrlType
@property (nonatomic,assign)MovieType movieType;//类型：视频/美剧/合辑
@property(nonatomic,copy)NSString *time;//加入下载列表的时间


//下载头信息 --
@property (nonatomic,strong)NSDictionary * downHeader;


@property (nonatomic,copy)NSString * webPlayUrl;/** WebPlayUrl地址 */
@property (nonatomic,copy)NSString * quality;/**  *  视频质量,eg：height ;  */
@property (nonatomic, copy)NSString * title;
@property (nonatomic,copy)NSString * iconUrl;//剧照
@property (nonatomic,assign)BOOL isHadDown;//是否已经下载完毕 - 下载完毕要更新为YES
@property (nonatomic,copy)NSString * fileSize;//总大小
@property (nonatomic,copy)NSString * fileReceivedSize;//已经接收到数据的大小


// QQ源的适配

// 视频地址列表
@property (nonatomic,strong)NSArray * urlArray;
// 总大小 -- 用于计算下载进度
@property (nonatomic,assign)NSUInteger total_filesize;
//


//@property(nonatomic,copy)NSString *targetPath;  //目标地址
@property(nonatomic,copy)NSString *tempPath;    //临时下载地址

#pragma mark - m3u8下载专有的片段
@property (nonatomic,assign)int segmentHadDown;//已经下载的片段


// >>>>>>>>>>>>>>>>>>>>>>>>>>  download info
// 下载地址
@property (nonatomic, strong) NSString *downloadURL;
// 文件名 默认nil 则为下载URL中的文件名
//@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileName;

// 缓存文件目录 默认nil 则为manger缓存目录
//@property (nonatomic, strong) NSString *downloadDirectory;

// >>>>>>>>>>>>>>>>>>>>>>>>>>  task info
// 下载状态
@property (nonatomic, assign) RRDownloadState state;
// 下载任务
@property (nonatomic, strong) NSURLSessionTask *task;
// 文件流
@property (nonatomic, strong) NSOutputStream *stream;
// 下载进度
@property (nonatomic, strong ) TTDownloadProgress *progress;
// 下载路径 如果设置了downloadDirectory，文件下载完成后会移动到这个目录，否则，在manager默认cache目录里
@property (nonatomic, strong) NSString *filePath;

// >>>>>>>>>>>>>>>>>>>>>>>>>>  download block
// 下载进度更新block
@property (nonatomic, copy) TTDownloadProgressBlock progressBlock;
// 下载状态更新block
@property (nonatomic, copy) TTDownloadStateBlock stateBlock;
//下载更新block = 进度+状态
@property (nonatomic, copy) TTDownloadUpdateBlock updateBlock;

// 下载时间
@property (nonatomic, strong) NSDate *downloadDate;
// 手动取消当做暂停
@property (nonatomic, assign) BOOL manualCancle;
// 断点续传需要设置这个数据
@property (nonatomic, strong) NSData *resumeData;

- (instancetype)initWithURLString:(NSString *)URLString;

/**
 *  初始化方法
 *
 *  @param URLString 下载地址
 *  @param filePath  缓存地址 当为nil 默认缓存到cache
 */
- (instancetype)initWithURLString:(NSString *)URLString filePath:(NSString *)filePath;



@property (nonatomic,assign) NSInteger row;//更新cell防止循环引用，其他无实际意义
@end



#pragma mark -- RRDownloadProgress

/**
 *  下载进度
 */
@interface TTDownloadProgress : NSObject

// 续传大小
@property (nonatomic, assign) int64_t resumeBytesWritten;
// 这次写入的数量
@property (nonatomic, assign) int64_t bytesWritten;
// 已下载的数量
@property (nonatomic, assign) int64_t totalBytesWritten;
// 文件的总大小
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;
// 下载进度
@property (nonatomic, assign) float progress;
// 下载速度
@property (nonatomic, assign) float speed;
// 下载剩余时间
@property (nonatomic, assign) int remainingTime;


@end



