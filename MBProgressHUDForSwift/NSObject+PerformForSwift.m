//
//  NSObject+PerformForSwift.m
//  MBProgressHUDForSwift
//
//  Created by hzs on 15/7/17.
//  Copyright (c) 2015年 powfulhong. All rights reserved.
//

#import "NSObject+PerformForSwift.h"

@implementation NSObject (PerformForSwift)

- (void)swift_performSelector:(SEL)selector {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selector];
#pragma clang diagnostic pop
}

- (void)swift_performSelector:(SEL)selector withObject:(id)object
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selector withObject:object];
#pragma clang diagnostic pop
}

- (void)swift_performSelector:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selector withObject:object afterDelay:delay];
#pragma clang diagnostic pop
}

- (void)swift_performSelectorOnMainThread:(SEL)selector withObject:(id)arg waitUntilDone:(BOOL)wait
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelectorOnMainThread:selector withObject:arg waitUntilDone:wait];
#pragma clang diagnostic pop
}

- (id)swiftClassFromString:(NSString *)className {
    id myclass = [[NSClassFromString(className) alloc] init];
    return myclass;
}

@end
