//
//  SysUtil.m
//  ThreadSnapshot
//
//  Created by mjzheng on 2019/7/17.
//  Copyright © 2019年 郑俊明. All rights reserved.
//

#import "SysUtil.h"
#import <sys/sysctl.h>
#import <AdSupport/AdSupport.h>

@implementation SysUtil

+(NSString*) stringWithUUID
{
    CFUUIDRef uuidObj = CFUUIDCreate(nil);//create a new UUID
    //get the string representation of the UUID
    NSString* uuidString = (__bridge NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    NSLog(@"%@", uuidString);
    return uuidString;
}

+(NSString*) getIDFA
{
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSLog(@"%@", idfa);
    return idfa;
}

+(NSString *)GetDevicePlatform
{
    static NSString* platform = nil;
    if (platform == nil) {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = (char *)malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        if(machine == NULL){
            platform = @"i386";
        }else {
            platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
        }
        free(machine);
    }
    return platform;
}

+(NSString*) getOSVersion
{
    size_t size = 0;
    sysctlbyname("kern.osversion", NULL, &size, NULL, 0);
    char* osversion = (char*)malloc(size);
    sysctlbyname("kern.osversion", osversion, &size, NULL, 0);
    NSString* version = [NSString stringWithUTF8String:osversion];
    free(osversion);
    return version;
}

+(NSString*) getDate
{
    NSDateFormatter* g_dateFormatter = [[NSDateFormatter alloc] init];
    [g_dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [g_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS ZZZ"];
    NSDate* currentDate = [NSDate date];
    return [g_dateFormatter stringFromDate:currentDate];
}

+(NSString*) getCPUArch
{
    // ARM-64, ARM, x86-64, or x86.
    cpu_type_t cpuType = 0;
    size_t size = sizeof(cpuType);
    sysctlbyname("hw.cputype", &cpuType, &size, NULL, 0);
    NSString* strCpuArch = @"unknown";
    switch(cpuType)
    {
        case CPU_TYPE_ARM:
            strCpuArch = @"ARM";
            break;
#ifdef CPU_TYPE_ARM64
        case CPU_TYPE_ARM64:
            strCpuArch =  @"ARM-64";
            break;
#endif
        case CPU_TYPE_X86:
            strCpuArch = @"X86";
            break;
        case CPU_TYPE_X86_64:
            strCpuArch = @"X86_64";
            break;
        default:
            break;
    }
    
    return strCpuArch;
}

+(NSString*) getCpuType:(cpu_type_t) majorCode minor:(cpu_subtype_t) minorCode
{
    switch(majorCode)
    {
        case CPU_TYPE_ARM:
        {
            switch (minorCode)
            {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return @"armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return @"armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
                case CPU_SUBTYPE_ARM_V7S:
                    return @"armv7s";
#endif
            }
            return @"arm";
        }
#ifdef CPU_TYPE_ARM64
        case CPU_TYPE_ARM64:
            return @"arm64";
#endif
        case CPU_TYPE_X86:
            return @"i386";
        case CPU_TYPE_X86_64:
            return @"x86_64";
    }
    return [NSString stringWithFormat:@"unknown(%d,%d)", majorCode, minorCode];
}


@end
