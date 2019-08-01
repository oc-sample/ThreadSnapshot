//
//  SysUtil.h
//  ThreadSnapshot
//
//  Created by mjzheng on 2019/7/17.
//  Copyright © 2019年 郑俊明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/machine.h>

NS_ASSUME_NONNULL_BEGIN

@interface SysUtil : NSObject

+(NSString*) stringWithUUID;

+(NSString*) getIDFA;

+(NSString *)GetDevicePlatform;

+(NSString*) getOSVersion;

+(NSString*) getDate;

+(NSString*) getCPUArch;

+(NSString*) getCpuType:(cpu_type_t) majorCode minor:(cpu_subtype_t) minorCode;

@end

NS_ASSUME_NONNULL_END
