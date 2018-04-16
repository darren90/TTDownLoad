//
//  DownloadTool.h
//  TTDownLoad
//
//  Created by Fengtf on 2018/3/18.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RRNetStatus) {
    RRNoNet,//没网
    RRNetViaWifi,//当前是wifi
    
    
    RRNetVia3GWatch ,//当前是3G，且系统允许了使用3G进行 观看
    RRNetVia3GWatchNot ,//当前是3G，但是系统却不允许 观看
    
    RRNetVia3GDown ,//当前是3G，且系统允许了使用3G进行 下载
    RRNetVia3GDownNot ,//当前是3G，但是系统却不允许 下载
};

#define kSettingCache3G         @"缓存提示"     //非wifi 下缓存

#define kDownDomanPath @"/Downloads"  //下载的地址 //  /Downloads
#define kDownTargetPath @"Video"//下载的所在的文件夹
#define kDownTempPath @"Temp"//下载的所在的文件夹
#define kDownJoinStr @"{|R|}"//腾讯源的数组下载的分隔符
#define kPlayJoinStr @"RR"//腾讯源的数组下载的分隔符 -- 针对已经下载完毕的，不然组成NSUrl
#define KLocaPlaylUrl @"http://127.0.0.1:12345"



@interface DownloadTool : NSObject

+ (RRNetStatus)getCacheNetStatusWhenAppStart;




+(NSString *)getM3u8PlayUrl:(NSString *)uniquenName;

+(NSString *)getListPlayUrl:(NSString *)uniquenName ts:(NSString *)tsName;

/**
 * 获取String类型的日期
 */
+(NSString *)dateStr;

+(NSString *)dateToString:(NSDate*)date;


+(float)getProgress:(float)totalSize currentSize:(float)currentSize;


+(NSString *)getFileSizeString:(NSString *)size;


/**
 *  取得下载的目标路径，不存在会创建
 *
 *  @param name 名字不要包含.
 *
 *  @return 全部路径
 */
+(NSString *)getCrTargetPath:(NSString *)name;

/**
 *  取得下载的临时路径，不存在会创建
 *
 *  @param name 名字不要包含.
 *
 *  @return 全部路径
 */
+(NSString *)getCrTempPath:(NSString *)name;



//单纯的取出下载文件的目标路径
+(NSString *)getTargetPath:(NSString *)name;
//单纯的取出下载文件的临时路径
+(NSString *)getTempPath:(NSString *)name;


+(NSString *)getDownBasePath;





@end
