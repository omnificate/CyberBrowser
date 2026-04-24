// Copyright 2025 CyberBrowser Authors
// AppDelegate.mm - App lifecycle + Chromium WebMain init

#import "AppDelegate.h"
#import "BrowserViewController.h"
#import "ChromiumInit.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Initialize Chromium engine
    if (![ChromiumInit startup]) {
        NSLog(@"[CyberBrowser] FATAL: Chromium WebMain failed to start");
        // Show error and exit
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Engine Error"
                                                                       message:@"Chromium engine failed to initialize. The app requires the Blink framework to be embedded."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.rootViewController = [[UIViewController alloc] init];
        [self.window makeKeyAndVisible];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        return YES;
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    BrowserViewController *browser = [[BrowserViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:browser];
    nav.navigationBarHidden = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [ChromiumInit shutdown];
}

@end