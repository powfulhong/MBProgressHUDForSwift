//
//  NSObject+PerformForSwift.h
//  MBProgressHUDForSwift
//
//  Created by hzs on 15/7/17.
//  Copyright (c) 2015年 powfulhong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (PerformForSwift)

/**
 *  Performs a selector on an NSObject class. IMPORTANT: Method must return a pointer! Ex. NSNumber will work, but Int will not.
 *
 *  @param selector The Selector to call
 *
 *  @return .
 */
- (void)swift_performSelector:(SEL)selector;
- (void)swift_performSelector:(SEL)selector withObject:(id)object;
- (void)swift_performSelector:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay;
- (void)swift_performSelectorOnMainThread:(SEL)selector withObject:(id)arg waitUntilDone:(BOOL)wait;

/**
 *  Create an NSObject class object
 *
 *  @param className The NSString of the class name
 *
 *  @return An instantiated class if it exists
 */
- (id)swiftClassFromString:(NSString *)className;

@end
