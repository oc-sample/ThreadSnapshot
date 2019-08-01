//
//  ThreadInfo.h
//  AppleMiniDumpApp
//
//  Created by mjzheng on 2019/6/28.
//  Copyright © 2019年 mjzheng. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThreadInfo : NSObject

+(NSString*) getAllThreadStack:(float*) appCpu;

@end

NS_ASSUME_NONNULL_END
