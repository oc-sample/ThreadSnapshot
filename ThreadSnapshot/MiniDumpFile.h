//
//  MiniDumpFile.h
//  AppleMiniDumpApp
//
//  Created by mjzheng on 2019/6/28.
//  Copyright © 2019年 mjzheng. All rights reserved.
//

#import <Foundation/Foundation.h>

// lipo -create Release-iphoneos/libThreadSnapshot.a Release-iphonesimulator/libThreadSnapshot.a -output libThreadSnapshot.a

NS_ASSUME_NONNULL_BEGIN

@interface MiniDumpFile : NSObject

-(NSString*) generateMiniDump;

@end

NS_ASSUME_NONNULL_END
