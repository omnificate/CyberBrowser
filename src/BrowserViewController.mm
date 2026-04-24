// Copyright 2025 CyberBrowser Authors
// BrowserViewController.mm - Real Chromium Blink engine browser with tabs, history, search

#import "BrowserViewController.h"

#include <memory>
#include <string>

#include "ios/web/shell/view_controller.h"
#include "ios/web/public/web_state.h"
#include "ios/web/public/navigation/navigation_manager.h"
#include "ios/web/public/navigation/referrer.h"
#include "ios/web/public/web_state_observer.h"
#include "ios/web/public/web_state_observer_bridge.h"
#include "ios/web/shell/shell_browser_state.h"
#include "ios/web/shell/shell_web_client.h"

#include "base/strings/sys_string_conversions.h"
#include "url/gurl.h"
#include "ui/base/page_transition_types.h"

using namespace web;

namespace {

// Store history item in NSUserDefaults
void StoreHistoryItem(NSString *url, NSString *title) {
    if (!url || url.length == 0 || [url isEqualToString:@"about:blank"]) return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *history = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"cyberbrowser_history"] ?: @[]];
    
    // Remove existing entry for this URL (deduplicate)
    NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < history.count; i++) {
        NSDictionary *item = history[i];
        if ([item[@"url"] isEqualToString:url]) [toRemove addIndex:i];
    }
    [history removeObjectsAtIndexes:toRemove];
    
    NSDictionary *item = @{
        @"url": url,
        @"title": title ?: url,
        @"date": [NSDate date]
    };
    [history insertObject:item atIndex:0];
    
    // Cap at 500 entries
    if (history.count > 500) [history removeObjectsInRange:NSMakeRange(500, history.count - 500)];
    
    [defaults setObject:history forKey:@"cyberbrowser_history"];
    [defaults synchronize];
}

} // namespace

@interface BrowserViewController () {
    NSMutableArray<ViewController *> *_tabs;
    NSInteger _selectedTab;
    NSTimer *_updateTimer;
}

@property (nonatomic, strong) UIView *toolbarView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UIBarButtonItem *backBtn;
@property (nonatomic, strong) UIBarButtonItem *fwdBtn;
@property (nonatomic, strong) UIBarButtonItem *reloadBtn;
@property (nonatomic, strong) UIBarButtonItem *tabsBtn;
@property (nonatomic, strong) UIBarButtonItem *historyBtn;

@end

@implementation BrowserViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    _tabs = [NSMutableArray array];
    _selectedTab = 0;
    
    [self setupUI];
    [self newTab:@"https://www.google.com"];
    
    // Poll Chromium state for updates (progress, title, URL)
    _updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                    target:self
                                                  selector:@selector(updateState)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_updateTimer invalidate];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Navigation bar (hidden, we use our own toolbar)
    self.navigationController.navigationBarHidden = YES;
    
    // Custom toolbar at top
    self.toolbarView = [[UIView alloc] init];
    self.toolbarView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.toolbarView];
    
    // Progress bar
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.tintColor = [UIColor systemBlueColor];
    self.progressView.hidden = YES;
    [self.toolbarView addSubview:self.progressView];
    
    // Address field
    self.addressField = [[UITextField alloc] init];
    self.addressField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    self.addressField.layer.cornerRadius = 8;
    self.addressField.font = [UIFont systemFontOfSize:15];
    self.addressField.placeholder = @"Search or enter address";
    self.addressField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.addressField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.addressField.keyboardType = UIKeyboardTypeURL;
    self.addressField.returnKeyType = UIReturnKeyGo;
    self.addressField.delegate = self;
    self.addressField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbarView addSubview:self.addressField];
    
    // Navigation buttons toolbar
    UIToolbar *navToolbar = [[UIToolbar alloc] init];
    navToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    navToolbar.barTintColor = [UIColor clearColor];
    [self.toolbarView addSubview:navToolbar];
    
    self.backBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.backward"]
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(goBack)];
    self.fwdBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]
                                                    style:UIBarButtonItemStylePlain
                                                   target:self
                                                   action:@selector(goForward)];
    self.reloadBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(doReload)];
    self.tabsBtn = [[UIBarButtonItem alloc] initWithTitle:@"1"
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(showTabs)];
    self.historyBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"clock"]
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(showHistory)];
    
    // Initially disable back/forward
    self.backBtn.enabled = NO;
    self.fwdBtn.enabled = NO;
    
    navToolbar.items = @[
        self.backBtn,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        self.fwdBtn,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        self.reloadBtn,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        self.tabsBtn,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        self.historyBtn
    ];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:90],
        
        [self.progressView.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor],
        [self.progressView.heightAnchor constraintEqualToConstant:2],
        
        [self.addressField.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:6],
        [self.addressField.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:10],
        [self.addressField.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-10],
        [self.addressField.heightAnchor constraintEqualToConstant:34],
        
        [navToolbar.topAnchor constraintEqualToAnchor:self.addressField.bottomAnchor constant:4],
        [navToolbar.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:8],
        [navToolbar.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-8],
        [navToolbar.bottomAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor constant:-4]
    ]];
}

#pragma mark - Tab Management

- (void)newTab:(NSString *)urlString {
    ViewController *vc = [[ViewController alloc] init];
    [_tabs addObject:vc];
    _selectedTab = _tabs.count - 1;
    [self showTab:_selectedTab];
    
    // Load URL using Chromium NavigationManager
    GURL url([urlString UTF8String]);
    if (url.is_valid()) {
        NavigationManager::WebLoadParams params(url);
        params.transition_type = ui::PAGE_TRANSITION_TYPED;
        NavigationManager *nav = vc.webState->GetNavigationManager();
        if (nav) nav->LoadURLWithParams(params);
    }
    
    [self updateTabCount];
}

- (void)showTab:(NSInteger)index {
    if (index >= _tabs.count) return;
    
    // Remove old web views (keep ViewControllers alive in _tabs)
    for (UIView *subview in self.view.subviews) {
        if (subview != self.toolbarView) [subview removeFromSuperview];
    }
    
    ViewController *vc = _tabs[index];
    UIView *webView = [vc view];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:webView];
    [self.view sendSubviewToBack:webView];
    
    [NSLayoutConstraint activateConstraints:@[
        [webView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor],
        [webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    _selectedTab = index;
    [self updateState];
}

- (void)closeTab:(NSInteger)index {
    if (_tabs.count <= 1) return;
    [_tabs removeObjectAtIndex:index];
    if (_selectedTab >= _tabs.count) _selectedTab = _tabs.count - 1;
    [self showTab:_selectedTab];
    [self updateTabCount];
}

- (void)updateTabCount {
    [self.tabsBtn setTitle:[NSString stringWithFormat:@"%lu", (unsigned long)_tabs.count]];
}

#pragma mark - Navigation Actions

- (void)goBack {
    if (_selectedTab >= _tabs.count) return;
    ViewController *vc = _tabs[_selectedTab];
    NavigationManager *nav = vc.webState->GetNavigationManager();
    if (nav && nav->CanGoBack()) nav->GoBack();
}

- (void)goForward {
    if (_selectedTab >= _tabs.count) return;
    ViewController *vc = _tabs[_selectedTab];
    NavigationManager *nav = vc.webState->GetNavigationManager();
    if (nav && nav->CanGoForward()) nav->GoForward();
}

- (void)doReload {
    if (_selectedTab >= _tabs.count) return;
    ViewController *vc = _tabs[_selectedTab];
    NavigationManager *nav = vc.webState->GetNavigationManager();
    if (nav) nav->Reload(ReloadType::NORMAL, false);
}

- (void)stopLoading {
    if (_selectedTab >= _tabs.count) return;
    ViewController *vc = _tabs[_selectedTab];
    vc.webState->Stop();
}

#pragma mark - State Polling

- (void)updateState {
    if (_selectedTab >= _tabs.count) return;
    
    ViewController *vc = _tabs[_selectedTab];
    web::WebState *ws = vc.webState;
    if (!ws) return;
    
    NavigationManager *nav = ws->GetNavigationManager();
    
    // Update address bar with visible URL (not while editing)
    const GURL &visibleURL = ws->GetVisibleURL();
    if (visibleURL.is_valid() && ![self.addressField isFirstResponder]) {
        NSString *urlStr = [NSString stringWithUTF8String:visibleURL.spec().c_str()];
        self.addressField.text = urlStr;
    }
    
    // Update progress
    double progress = ws->GetLoadingProgress();
    self.progressView.progress = progress;
    self.progressView.hidden = !ws->IsLoading() || progress >= 1.0;
    
    // Update back/forward buttons
    if (nav) {
        self.backBtn.enabled = nav->CanGoBack();
        self.fwdBtn.enabled = nav->CanGoForward();
    }
    
    // Store in history when page finishes loading
    static NSMutableSet *visitedURLs = [NSMutableSet set];
    NSString *currentURL = visibleURL.is_valid() ? [NSString stringWithUTF8String:visibleURL.spec().c_str()] : nil;
    if (currentURL && !ws->IsLoading() && ![visitedURLs containsObject:currentURL]) {
        const std::u16string &title = ws->GetTitle();
        NSString *titleStr = title.empty() ? nil : [NSString stringWithCharacters:(const unichar *)title.data() length:title.length()];
        StoreHistoryItem(currentURL, titleStr);
        [visitedURLs addObject:currentURL];
    }
}

#pragma mark - Tab Picker

- (void)showTabs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tabs"
                                                                     message:nil
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSInteger i = 0; i < _tabs.count; i++) {
        web::WebState *ws = _tabs[i].webState;
        const std::u16string &title = ws->GetTitle();
        NSString *tabTitle = title.empty() ? @"New Tab" : [NSString stringWithCharacters:(const unichar *)title.data() length:title.length()];
        
        NSString *actionTitle = (i == _selectedTab) ? [NSString stringWithFormat:@"● %@", tabTitle] : tabTitle;
        
        [alert addAction:[UIAlertAction actionWithTitle:actionTitle
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self showTab:i];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"+ New Tab"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self newTab:@"https://www.google.com"];
    }]];
    
    if (_tabs.count > 1) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Close This Tab"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *action) {
            [self closeTab:_selectedTab];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - History

- (void)showHistory {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *history = [defaults arrayForKey:@"cyberbrowser_history"] ?: @[];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"History (%lu items)", (unsigned long)history.count]
                                                                     message:nil
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSDictionary *item in history) {
        NSString *title = item[@"title"] ?: item[@"url"] ?: @"Unknown";
        NSString *url = item[@"url"] ?: @"";
        
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self newTab:url];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear History"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [defaults removeObjectForKey:@"cyberbrowser_history"];
        [defaults synchronize];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    NSString *text = textField.text;
    if (!text || text.length == 0) return NO;
    
    if (_selectedTab >= _tabs.count) return NO;
    ViewController *vc = _tabs[_selectedTab];
    
    GURL url([text UTF8String]);
    if (url.is_valid() && (url.has_scheme() || url.SchemeIsHTTPOrHTTPS())) {
        // Valid URL
        NavigationManager::WebLoadParams params(url);
        params.transition_type = ui::PAGE_TRANSITION_TYPED;
        NavigationManager *nav = vc.webState->GetNavigationManager();
        if (nav) nav->LoadURLWithParams(params);
    } else {
        // Search query - Google
        NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *searchURL = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", encoded];
        GURL gurl([searchURL UTF8String]);
        NavigationManager::WebLoadParams params(gurl);
        params.transition_type = ui::PAGE_TRANSITION_GENERATED;
        NavigationManager *nav = vc.webState->GetNavigationManager();
        if (nav) nav->LoadURLWithParams(params);
    }
    return YES;
}

@end