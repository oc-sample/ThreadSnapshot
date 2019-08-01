//
//  MiniDumpFile.m
//  AppleMiniDumpApp
//
//  Created by mjzheng on 2019/6/28.
//  Copyright © 2019年 mjzheng. All rights reserved.
//

#import "MiniDumpFile.h"
#import "ThreadInfo.h"
#import "KSDynamicLinker.h"
#import "SysUtil.h"
#import <UIKit/UIDevice.h>

@implementation MiniDumpFile

-(NSString*) generateMiniDump
{
    NSLog(@"begin generate live report");

    // header
    NSMutableString* pData = [self writeAppleFmtHeader];

    // thread backtrace
    NSString* threads = [self writeThreadStatck];
    [pData appendFormat:@"%@", threads];
    
    // binary images
    NSString* images = [self writeAppleFmtBinaryImages];
    [pData appendFormat:@"%@", images];
    
    [self createFileDirectories];
    [self saveToFile:pData];
    
    return [pData copy];
}

- (NSMutableString*) writeAppleFmtHeader
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSDictionary* infoDict = [mainBundle infoDictionary];
    NSString* bundlePath = [mainBundle bundlePath];
    NSString* executableName = infoDict[@"CFBundleExecutable"];
    NSString* fullPath = [bundlePath stringByAppendingPathComponent:executableName];
    NSMutableString* str = [NSMutableString string];
    [str appendFormat:@"Incident Identifier: %@\n", [SysUtil stringWithUUID]]; // guid
    [str appendFormat:@"CrashReporter Key: %@\n", [SysUtil getIDFA]]; // idfa
    [str appendFormat:@"Hardware Model: %@\n", [SysUtil GetDevicePlatform]]; // 设备名称
    [str appendFormat:@"Process: %@ [%d]\n",[NSProcessInfo processInfo].processName, [NSProcessInfo processInfo].processIdentifier]; // 进程名[pid]
    [str appendFormat:@"Path: %@\n", fullPath]; // 进程路径
    [str appendFormat:@"Identifier: %@\n", infoDict[@"CFBundleIdentifier"]]; // 证书签名
    [str appendFormat:@"Version: %@(%@)\n", infoDict[@"CFBundleVersion"], infoDict[@"CFBundleShortVersionString"]];
    [str appendFormat:@"Code Type: %@\n", [SysUtil getCPUArch]];
    [str appendFormat:@"Parent Process: [%d]\n", getppid()];
    [str appendFormat:@"\n"];
    [str appendFormat:@"Date/Time: %@\n", [SysUtil getDate]];
    [str appendFormat:@"OS Version: %@ %@ (%@)\n", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion], [SysUtil getOSVersion]];
    [str appendFormat:@"Report Version:  104\n\n"];
    return str;
}

-(NSString*) writeThreadStatck
{
    float totalCpu = 0;
    return [ThreadInfo getAllThreadStack:&totalCpu];
}

-(NSString*) writeAppleFmtBinaryImages
{
    NSMutableString* str = [NSMutableString string];
    [str appendString:@"\nBinary Images:\n"];

    int count = ksdl_imageCount();
    for (int index=0; index<count; index++)
    {
        KSBinaryImage image = {0};
        if(!ksdl_getBinaryImage(index, &image))
        {
            continue;
        }

        NSString* fullPath = [[NSString alloc] initWithFormat:@"%s",image.name];
        NSString* binary_name = [fullPath lastPathComponent];
        NSString* strUUID = @"";
        CFUUIDRef uuidRef = CFUUIDCreateFromUUIDBytes(NULL, *((CFUUIDBytes*)image.uuid));
        if (uuidRef != NULL)
        {
            strUUID = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, uuidRef);
            CFRelease(uuidRef);
        }

        strUUID = [strUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];

        if (@available(iOS 9.0, *))
        {
            strUUID = [ strUUID localizedLowercaseString];
        }

        NSString* strCpuArch = [SysUtil getCpuType: image.cpuType minor:image.cpuSubType];
        NSString* pStr = [[NSString alloc] initWithFormat:@"0x%llx - 0x%llx %@ %@ <%@> %@\n", image.address, image.address+image.size-1, binary_name, strCpuArch, strUUID, fullPath];
        [str appendFormat:@"%@", pStr];
    }
    return str;
}

-(void) saveToFile:(NSString*) pData
{
    NSString* tmpPath = NSTemporaryDirectory();
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyMMddHHmmssSSS"];
    NSString* dateTime = [formatter stringFromDate:[NSDate date]];
    
    NSString* fileName = [NSString stringWithFormat:@"%@manual_stack/%@_ori.crash", tmpPath, dateTime];
    
    [pData writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)createFileDirectories
{
    NSString* tmpPath = NSTemporaryDirectory();
    NSString *picPath = [tmpPath stringByAppendingPathComponent:@"manual_stack"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:picPath isDirectory:&isDir];
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath: picPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir)
        {
            NSLog(@"fail to create manual_stack direction");
        }
        
    }
}

@end
