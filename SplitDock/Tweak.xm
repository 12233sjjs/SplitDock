#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface SDInstalledApp : NSObject
@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *displayName;
@end

@implementation SDInstalledApp
@end

@interface SDOverlayWindow : UIWindow
@end

@interface SDLauncherController : UIViewController <UITextFieldDelegate>
@property(nonatomic, strong) UIView *menuView;
@property(nonatomic, strong) UITextField *searchField;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIButton *edgeHandle;
@property(nonatomic, strong) NSArray<SDInstalledApp *> *apps;
@property(nonatomic, strong) NSArray<SDInstalledApp *> *visibleApps;
@property(nonatomic, strong) NSMutableArray<UIButton *> *appButtons;
@property(nonatomic, strong) SDOverlayWindow *overlayWindow;
- (void)install;
- (void)layoutWheelButtons;
@end

@implementation SDOverlayWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self.rootViewController.view && !self.rootViewController.presentedViewController) {
        return nil;
    }
    return hit;
}

@end

static id SDCallObject(id target, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!target || ![target respondsToSelector:selector]) {
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static NSString *SDAppString(id proxy, NSString *selectorName) {
    id value = SDCallObject(proxy, selectorName);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static NSArray<SDInstalledApp *> *SDLoadInstalledApps(void) {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = SDCallObject(workspaceClass, @"defaultWorkspace");
    id installed = SDCallObject(workspace, @"allInstalledApplications");
    if (![installed isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<SDInstalledApp *> *apps = [NSMutableArray array];
    for (id proxy in installed) {
        NSString *bundleID = SDAppString(proxy, @"applicationIdentifier");
        NSString *name = SDAppString(proxy, @"localizedName");
        if (bundleID.length == 0 || name.length == 0) {
            continue;
        }

        SDInstalledApp *app = [SDInstalledApp new];
        app.bundleIdentifier = bundleID;
        app.displayName = name;
        [apps addObject:app];
    }

    [apps sortUsingComparator:^NSComparisonResult(SDInstalledApp *lhs, SDInstalledApp *rhs) {
        return [lhs.displayName localizedCaseInsensitiveCompare:rhs.displayName];
    }];
    return apps;
}

@implementation SDLauncherController

- (void)install {
    self.apps = SDLoadInstalledApps();
    self.visibleApps = self.apps;
    self.appButtons = [NSMutableArray array];

    UIWindowScene *activeScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            activeScene = (UIWindowScene *)scene;
            break;
        }
    }
    self.overlayWindow = activeScene
        ? [[SDOverlayWindow alloc] initWithWindowScene:activeScene]
        : [[SDOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 100;
    self.overlayWindow.backgroundColor = UIColor.clearColor;
    self.overlayWindow.rootViewController = self;
    self.overlayWindow.hidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    self.edgeHandle = [UIButton buttonWithType:UIButtonTypeCustom];
    self.edgeHandle.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.86];
    self.edgeHandle.layer.cornerRadius = 7.0;
    self.edgeHandle.accessibilityLabel = @"Open SplitDock launcher";
    [self.edgeHandle addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.edgeHandle];

    self.menuView = [[UIView alloc] initWithFrame:CGRectZero];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    self.menuView.layer.cornerRadius = 24.0;
    self.menuView.layer.borderWidth = 1.0;
    self.menuView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.13].CGColor;
    self.menuView.hidden = YES;
    [self.view addSubview:self.menuView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = @"SplitDock";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [self.menuView addSubview:title];
    title.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.statusLabel.text = [NSString stringWithFormat:@"%lu installed apps", (unsigned long)self.apps.count];
    [self.menuView addSubview:self.statusLabel];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.searchField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.searchField.placeholder = @"Search apps";
    self.searchField.textColor = UIColor.whiteColor;
    self.searchField.tintColor = [UIColor colorWithRed:0.30 green:0.76 blue:0.67 alpha:1.0];
    self.searchField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
    self.searchField.layer.cornerRadius = 11.0;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchField.returnKeyType = UIReturnKeyDone;
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(searchChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.menuView addSubview:self.searchField];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *wheel = [[UIView alloc] initWithFrame:CGRectZero];
    wheel.tag = 7001;
    [self.menuView addSubview:wheel];
    wheel.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.menuView.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:self.menuView.leadingAnchor constant:18],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.menuView.trailingAnchor constant:-18],
        [self.searchField.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.menuView.leadingAnchor constant:16],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.menuView.trailingAnchor constant:-16],
        [self.searchField.heightAnchor constraintEqualToConstant:40],
        [wheel.topAnchor constraintEqualToAnchor:self.searchField.bottomAnchor constant:8],
        [wheel.leadingAnchor constraintEqualToAnchor:self.menuView.leadingAnchor constant:8],
        [wheel.trailingAnchor constraintEqualToAnchor:self.menuView.trailingAnchor constant:-8],
        [wheel.bottomAnchor constraintEqualToAnchor:self.menuView.bottomAnchor constant:-8]
    ]];

    [self rebuildWheel];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    self.edgeHandle.frame = CGRectMake(width - 12, height * 0.43, 12, 112);
    CGFloat menuWidth = MIN(width - 28, 350);
    CGFloat menuHeight = MIN(height - 90, 430);
    self.menuView.frame = CGRectMake(width - menuWidth - 14, (height - menuHeight) / 2.0, menuWidth, menuHeight);
    [self layoutWheelButtons];
}

- (void)toggleMenu {
    self.menuView.hidden = !self.menuView.hidden;
    self.edgeHandle.alpha = self.menuView.hidden ? 1.0 : 0.45;
    if (!self.menuView.hidden) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self rebuildWheel];
    } else {
        [self.searchField resignFirstResponder];
    }
}

- (void)searchChanged:(UITextField *)field {
    NSString *query = field.text ?: @"";
    if (query.length == 0) {
        self.visibleApps = self.apps;
    } else {
        NSString *normalizedQuery = query.lowercaseString;
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SDInstalledApp *app, NSDictionary *bindings) {
            return [app.displayName.lowercaseString containsString:normalizedQuery] ||
                   [app.bundleIdentifier.lowercaseString containsString:normalizedQuery];
        }];
        self.visibleApps = [self.apps filteredArrayUsingPredicate:predicate];
    }
    self.statusLabel.text = [NSString stringWithFormat:@"%lu matches", (unsigned long)self.visibleApps.count];
    [self rebuildWheel];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    SDInstalledApp *first = self.visibleApps.firstObject;
    if (first) {
        [self launchApp:first];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)rebuildWheel {
    UIView *wheel = [self.menuView viewWithTag:7001];
    if (!wheel || !self.appButtons) {
        return;
    }
    [wheel.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.appButtons makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.appButtons removeAllObjects];

    NSUInteger count = MIN(self.visibleApps.count, 8);
    if (count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:wheel.bounds];
        empty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        empty.text = @"No matching apps";
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
        empty.font = [UIFont systemFontOfSize:14];
        [wheel addSubview:empty];
        return;
    }

    CGFloat diameter = 76;
    for (NSUInteger index = 0; index < count; index++) {
        SDInstalledApp *app = self.visibleApps[index];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)index;
        button.backgroundColor = [UIColor colorWithRed:0.18 green:0.25 blue:0.26 alpha:1.0];
        button.layer.cornerRadius = diameter / 2.0;
        button.layer.borderColor = [UIColor colorWithRed:0.35 green:0.78 blue:0.68 alpha:0.75].CGColor;
        button.layer.borderWidth = 1.0;
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        [button setTitle:app.displayName forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.accessibilityLabel = app.displayName;
        [button addTarget:self action:@selector(appButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [wheel addSubview:button];
        [self.appButtons addObject:button];
    }

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self layoutWheelButtons];
}

- (void)layoutWheelButtons {
    UIView *wheel = [self.menuView viewWithTag:7001];
    if (!wheel || self.appButtons.count == 0) {
        return;
    }

    CGFloat diameter = 76;
    CGFloat radius = MAX(36, MIN(CGRectGetWidth(wheel.bounds), CGRectGetHeight(wheel.bounds)) * 0.30);
    CGPoint center = CGPointMake(CGRectGetMidX(wheel.bounds), CGRectGetMidY(wheel.bounds));
    NSUInteger buttonCount = self.appButtons.count;
    [self.appButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, BOOL *stop) {
        CGFloat angle = ((CGFloat)index / (CGFloat)buttonCount) * (CGFloat)(M_PI * 2.0) - (CGFloat)(M_PI / 2.0);
        CGPoint point = CGPointMake(center.x + cos(angle) * radius, center.y + sin(angle) * radius);
        button.frame = CGRectMake(point.x - diameter / 2.0, point.y - diameter / 2.0, diameter, diameter);
    }];
}

- (void)appButtonPressed:(UIButton *)button {
    NSUInteger index = (NSUInteger)button.tag;
    if (index < self.visibleApps.count) {
        [self launchApp:self.visibleApps[index]];
    }
}

- (void)launchApp:(SDInstalledApp *)app {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = SDCallObject(workspaceClass, @"defaultWorkspace");
    SEL selector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if (![workspace respondsToSelector:selector]) {
        self.statusLabel.text = @"Launch service unavailable";
        return;
    }

    [self toggleMenu];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, selector, app.bundleIdentifier);
    });
}

@end

static SDLauncherController *SDController;

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SDController = [SDLauncherController new];
            [SDController install];
        });
    }
}
