// ChromiumInit.h
// Initializes and manages the Chromium WebMain singleton
// Must be called before any web operations

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChromiumInit : NSObject

+ (BOOL)startup;
+ (void)shutdown;
+ (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
