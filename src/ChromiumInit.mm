// ChromiumInit.mm
// Objective-C++ implementation of Chromium WebMain initialization

#import "ChromiumInit.h"

#include <memory>

#include "ios/web/public/init/web_main.h"
#include "ios/web/shell/shell_main_delegate.h"

using namespace web;

static std::unique_ptr<WebMain> g_web_main;
static std::unique_ptr<ShellMainDelegate> g_shell_delegate;
static BOOL g_is_running = NO;

@implementation ChromiumInit

+ (BOOL)startup {
    if (g_is_running) return YES;
    
    @try {
        NSLog(@"[ChromiumInit] Starting WebMain...");
        
        g_shell_delegate.reset(new ShellMainDelegate());
        
        WebMainParams params(g_shell_delegate.get());
        g_web_main = std::make_unique<WebMain>(std::move(params));
        
        int result = g_web_main->Startup();
        if (result != 0) {
            NSLog(@"[ChromiumInit] WebMain startup failed with code: %d", result);
            g_web_main.reset();
            g_shell_delegate.reset();
            return NO;
        }
        
        g_is_running = YES;
        NSLog(@"[ChromiumInit] WebMain started successfully");
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"[ChromiumInit] Exception during startup: %@", exception);
        return NO;
    }
}

+ (void)shutdown {
    if (!g_is_running) return;
    
    NSLog(@"[ChromiumInit] Shutting down WebMain...");
    g_web_main.reset();
    g_shell_delegate.reset();
    g_is_running = NO;
    NSLog(@"[ChromiumInit] WebMain shut down");
}

+ (BOOL)isRunning {
    return g_is_running;
}

@end
