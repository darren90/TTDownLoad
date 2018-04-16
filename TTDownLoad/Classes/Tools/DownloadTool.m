//
//  DownloadTool.m
//  TTDownLoad
//
//  Created by Fengtf on 2018/3/18.
//

#import "DownloadTool.h"
//#import "Reachability.h"

@implementation DownloadTool

+ (RRNetStatus)getCacheNetStatusWhenAppStart{
//    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
//    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
//
//    RRNetStatus status = RRNetViaWifi;
//    //查看是否使用3G的开关
//    BOOL isUse3G = [DownloadTool cache3GState];//yes 可以使用3G下载
//
//    if (networkStatus == ReachableViaWiFi) { //wifi
//        status = RRNetViaWifi;
//    } else if(networkStatus == ReachableViaWWAN) {//3G
//        status = RRNetVia3GDownNot; // 3G网络下，不允许下载
//        //        if (isUse3G) { //当前是3G，且系统允许了使用3G进行 下载
//        //            status = RRNetVia3GDown;
//        //        }else{  //当前是3G，但是系统却不允许 下载
//        //            status = RRNetVia3GDownNot;
//        //        }
//    }else{//没有网
//        status = RRNoNet;
//    }
//
//    return status;
    return RRNetViaWifi;
}

+ (BOOL)cache3GState{
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL cache3G = [defaults boolForKey:kSettingCache3G];//yes 可以使用3G下载
    return cache3G;
}











+(NSString *)getM3u8PlayUrl:(NSString *)uniquenName
{
    NSString *url = [NSString stringWithFormat:@"%@%@/Video/%@/movie.m3u8",KLocaPlaylUrl,kDownDomanPath,uniquenName];
    return url;
}

+(NSString *)getListPlayUrl:(NSString *)uniquenName ts:(NSString *)tsName
{
    NSString *url = [NSString stringWithFormat:@"%@%@/Video/%@/%@.mp4",KLocaPlaylUrl,kDownDomanPath,uniquenName,tsName];
    return url;
}
//获取Str类型的日期类型
+(NSString *)dateStr{
    NSDate *date = [NSDate date];
    NSDateFormatter *df=[[NSDateFormatter alloc] init];
    
    [df setDateFormat:@"MM-dd HH:mm:ss"];//[df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *datestr = [df stringFromDate:date];
    return datestr;
}


+(NSString *)dateToString:(NSDate*)date{
    NSDateFormatter *df=[[NSDateFormatter alloc] init];
    
    [df setDateFormat:@"MM-dd HH:mm:ss"];//[df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *datestr = [df stringFromDate:date];
    return datestr;
}


+(float)getProgress:(float)totalSize currentSize:(float)currentSize
{
    if (totalSize == 0.0){
        return 0.0;
    }
    return currentSize/totalSize;
}


+(NSString *)getFileSizeString:(NSString *)size
{
    long long floatSize = [size longLongValue];
    if(floatSize >= 1024*1024){//大于1M，则转化成M单位的字符串
        return [NSString stringWithFormat:@"%.1fM",floatSize/1024.0/1024];
    }
    else if(floatSize >= 1024 && floatSize < 1024*1024){ //不到1M,但是超过了1KB，则转化成KB单位
        return [NSString stringWithFormat:@"%lldK",floatSize/1024];
    }
    else{//剩下的都是小于1K的，则转化成B单位
        return [NSString stringWithFormat:@"%lldB",floatSize];
    }
}


//name：m3u8：是文件夹。mp4是文件名
+(NSString *)getCrTargetPath:(NSString *)name
{
    NSString *pathstr = [self getDownBasePath];
    pathstr =  [pathstr stringByAppendingPathComponent:kDownTargetPath];
    pathstr =  [pathstr stringByAppendingPathComponent:name];
    
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    if(![fileManager fileExistsAtPath:pathstr]) {
        [fileManager createDirectoryAtPath:pathstr withIntermediateDirectories:YES attributes:nil error:&error];
        if(!error)  {
            NSLog(@"%@",[error description]);
        }
    }
    return pathstr;
}

//name：m3u8：是文件夹。mp4是文件名
+(NSString *)getCrTempPath:(NSString *)name
{
    NSString *pathstr = [self getDownBasePath];
    pathstr =  [pathstr stringByAppendingPathComponent:kDownTempPath];
    pathstr =  [pathstr stringByAppendingPathComponent:name];
    
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    if(![fileManager fileExistsAtPath:pathstr]) {
        [fileManager createDirectoryAtPath:pathstr withIntermediateDirectories:YES attributes:nil error:&error];
        if(!error){
            NSLog(@"%@",[error description]);
        }
    }
    return pathstr;
}


//name：m3u8：是文件夹。mp4是文件名
+(NSString *)getTargetPath:(NSString *)name
{
    if(!name || name.length == 0){
        return nil;
    }
    NSString *pathstr = [self getDownBasePath];
    pathstr =  [pathstr stringByAppendingPathComponent:kDownTargetPath];
    pathstr =  [pathstr stringByAppendingPathComponent:name];
    return pathstr;
}

//name：m3u8：是文件夹。mp4是文件名
+(NSString *)getTempPath:(NSString *)name
{
    if(!name || name.length == 0){
        return nil;
    }
    NSString *pathstr = [self getDownBasePath];
    pathstr =  [pathstr stringByAppendingPathComponent:kDownTempPath];
    pathstr =  [pathstr stringByAppendingPathComponent:name];
    return pathstr;
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
+(NSString *)getDownBasePath{
    NSString *pathstr = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    pathstr = [pathstr stringByAppendingPathComponent:kDownDomanPath];
    return pathstr;
}


@end
