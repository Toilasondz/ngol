#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "Features/HSONFeatureEngine.h"

static NSString *const kHSONLauncherPosXKey = @"HSONLauncherPosX";
static NSString *const kHSONLauncherPosYKey = @"HSONLauncherPosY";

static __weak UIWindow *gHSONWindow;
static UIButton *gHSONLauncher;
static UIView *gHSONDimView;
static UIView *gHSONPanel;
static NSInteger gHSONSelectedTab = 0;

@class HSONMenuActionTarget;
@class HSONLauncherTarget;
static HSONMenuActionTarget *gHSONActionTarget;
static HSONLauncherTarget *gHSONLauncherTarget;

static UIColor *HSONColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static CAGradientLayer *HSONGradient(UIView *view, NSString *name, NSArray<UIColor *> *colors) {
    if (!view) return nil;
    CAGradientLayer *gradient = nil;
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer.name isEqualToString:name] && [layer isKindOfClass:CAGradientLayer.class]) {
            gradient = (CAGradientLayer *)layer;
            break;
        }
    }
    if (!gradient) {
        gradient = [CAGradientLayer layer];
        gradient.name = name;
        [view.layer insertSublayer:gradient atIndex:0];
    }
    NSMutableArray *cg = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) [cg addObject:(id)color.CGColor];
    gradient.colors = cg;
    gradient.locations = @[@0.0, @0.55, @1.0];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.frame = view.bounds;
    gradient.cornerRadius = view.layer.cornerRadius;
    return gradient;
}

static UILabel *HSONLabel(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

static UIWindow *HSONKeyWindow(void) {
    UIApplication *application = UIApplication.sharedApplication;
    UIWindow *fallbackWindow = nil;

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive &&
            windowScene.activationState != UISceneActivationStateForegroundInactive) continue;

        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow && !window.hidden && window.alpha > 0.01) return window;
            if (!window.hidden && window.alpha > 0.01 && window.rootViewController &&
                window.windowLevel <= UIWindowLevelNormal &&
                CGRectGetWidth(window.bounds) > 0 && CGRectGetHeight(window.bounds) > 0) {
                if (!fallbackWindow || window.windowLevel > fallbackWindow.windowLevel) {
                    fallbackWindow = window;
                }
            }
        }
    }
    if (fallbackWindow) return fallbackWindow;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows) {
        if (window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
            return window;
        }
        if (!fallbackWindow && !window.hidden && window.alpha > 0.01 && window.rootViewController &&
            CGRectGetWidth(window.bounds) > 0 && CGRectGetHeight(window.bounds) > 0) {
            fallbackWindow = window;
        }
    }
    if (!fallbackWindow) fallbackWindow = application.keyWindow;
#pragma clang diagnostic pop
    return fallbackWindow;
}

static CGPoint HSONClampLauncherCenter(CGPoint center, CGSize size, UIWindow *window) {
    CGRect bounds = window ? window.bounds : UIScreen.mainScreen.bounds;
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        insets = window ? window.safeAreaInsets : UIEdgeInsetsZero;
    }
    CGFloat halfW = size.width / 2.0;
    CGFloat halfH = size.height / 2.0;
    CGFloat minX = insets.left + halfW + 8.0;
    CGFloat maxX = bounds.size.width - insets.right - halfW - 8.0;
    CGFloat minY = insets.top + halfH + 8.0;
    CGFloat maxY = bounds.size.height - insets.bottom - halfH - 8.0;

    return CGPointMake(MAX(minX, MIN(maxX, center.x)),
                       MAX(minY, MIN(maxY, center.y)));
}

static void HSONHideMenu(void) {
    [gHSONPanel removeFromSuperview];
    [gHSONDimView removeFromSuperview];
    gHSONDimView = nil;
    gHSONPanel = nil;
}

static void HSONRunFeature(NSInteger index) {
    HSONHideMenu();
    HSONFeatureEngineRun(index);
}

static void HSONBuildFeaturePage(UIScrollView *scroll, CGFloat width, BOOL homeVariant) {
    for (UIView *view in [scroll.subviews copy]) [view removeFromSuperview];
    scroll.contentOffset = CGPointZero;
    scroll.scrollEnabled = YES;

    UIView *hero = [[UIView alloc] initWithFrame:CGRectMake(7, 7, width - 14, 88)];
    hero.backgroundColor = HSONColor(19, 42, 72, 1);
    hero.layer.cornerRadius = 20;
    hero.layer.cornerCurve = kCACornerCurveContinuous;
    hero.layer.borderWidth = 1;
    hero.layer.borderColor = HSONColor(91, 188, 255, 0.34).CGColor;
    HSONGradient(hero, @"hson.hero", @[HSONColor(16, 91, 139, 0.92), HSONColor(46, 55, 129, 0.95), HSONColor(34, 33, 76, 1)]);
    [scroll addSubview:hero];

    UIView *mark = [[UIView alloc] initWithFrame:CGRectMake(15, 17, 52, 52)];
    mark.layer.cornerRadius = 17;
    mark.layer.cornerCurve = kCACornerCurveContinuous;
    mark.layer.borderWidth = 1;
    mark.layer.borderColor = HSONColor(177, 229, 255, 0.7).CGColor;
    HSONGradient(mark, @"hson.mark", @[HSONColor(24, 199, 255, 1), HSONColor(103, 88, 255, 1)]);
    [hero addSubview:mark];
    UILabel *hs = HSONLabel(@"HS", [UIFont systemFontOfSize:19 weight:UIFontWeightHeavy], UIColor.whiteColor);
    hs.frame = mark.bounds;
    hs.textAlignment = NSTextAlignmentCenter;
    [mark addSubview:hs];

    UILabel *eyebrow = HSONLabel(@"HSON  /  CREATOR EDITION", [UIFont systemFontOfSize:9 weight:UIFontWeightHeavy], HSONColor(176, 224, 255, 1));
    eyebrow.frame = CGRectMake(79, 17, width - 110, 15);
    [hero addSubview:eyebrow];
    UILabel *headline = HSONLabel(@"Chỉnh sửa nhanh hơn", [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy], UIColor.whiteColor);
    headline.frame = CGRectMake(79, 34, width - 110, 25);
    [hero addSubview:headline];
    UILabel *caption = HSONLabel(@"3 công cụ native cho Video Star", [UIFont systemFontOfSize:10 weight:UIFontWeightMedium], HSONColor(195, 215, 242, 1));
    caption.frame = CGRectMake(80, 60, width - 110, 16);
    [hero addSubview:caption];

    UILabel *section = HSONLabel(homeVariant ? @"TRUY CẬP NHANH" : @"CHỌN CHỨC NĂNG",
                                 [UIFont systemFontOfSize:10 weight:UIFontWeightHeavy], HSONColor(132, 193, 247, 1));
    section.frame = CGRectMake(10, 105, width - 20, 18);
    [scroll addSubview:section];

    NSArray<NSDictionary *> *items = @[
        @{ @"engineIndex": @0, @"glyph": @"IMAGE", @"title": @"Auto nhập ảnh", @"detail": @"Áp dụng media đã chọn cho các layer", @"color": HSONColor(54, 204, 255, 1) },
        @{ @"engineIndex": @2, @"glyph": @"BEAT", @"title": @"Auto chia beat", @"detail": @"Đặt điểm cắt theo nhịp trong scene", @"color": HSONColor(255, 183, 94, 1) },
        @{ @"engineIndex": @3, @"glyph": @"SCENE", @"title": @"Auto nhập phân cảnh", @"detail": @"Nhập QR và media lần lượt cho nhiều scene", @"color": HSONColor(89, 226, 174, 1) }
    ];
    CGFloat margin = 7;
    CGFloat gap = 10;
    CGFloat cardWidth = floor((width - margin * 2 - gap) / 2.0);
    CGFloat cardHeight = 116;
    CGFloat firstY = 130;
    for (NSInteger index = 0; index < (NSInteger)items.count; index++) {
        BOOL wideCard = (index == 2);
        NSInteger row = index / 2;
        NSInteger column = index % 2;
        CGFloat thisCardWidth = wideCard ? width - margin * 2 : cardWidth;
        CGFloat x = wideCard ? margin : margin + column * (cardWidth + gap);
        CGRect frame = CGRectMake(x, firstY + row * (cardHeight + gap), thisCardWidth, cardHeight);
        NSDictionary *item = items[(NSUInteger)index];
        UIColor *accent = item[@"color"];
        UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
        card.frame = frame;
        card.tag = [item[@"engineIndex"] integerValue];
        card.backgroundColor = HSONColor(21, 38, 63, 0.98);
        card.layer.cornerRadius = 19;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        card.layer.borderWidth = 1;
        card.layer.borderColor = [accent colorWithAlphaComponent:0.42].CGColor;
        card.layer.shadowColor = accent.CGColor;
        card.layer.shadowOpacity = 0.12;
        card.layer.shadowRadius = 10;
        card.layer.shadowOffset = CGSizeMake(0, 5);
        HSONGradient(card, [NSString stringWithFormat:@"hson.card.%ld", (long)index], @[HSONColor(27, 52, 83, 0.98), HSONColor(24, 34, 61, 0.98)]);
        [card addTarget:gHSONActionTarget action:@selector(hsonFeatureTapped:) forControlEvents:UIControlEventTouchUpInside];
        UIView *icon = [[UIView alloc] initWithFrame:CGRectMake(12, 12, 39, 39)];
        icon.layer.cornerRadius = 13;
        icon.layer.cornerCurve = kCACornerCurveContinuous;
        icon.backgroundColor = [accent colorWithAlphaComponent:0.17];
        icon.layer.borderWidth = 1;
        icon.layer.borderColor = [accent colorWithAlphaComponent:0.44].CGColor;
        icon.userInteractionEnabled = NO;
        [card addSubview:icon];
        UILabel *glyph = HSONLabel(item[@"glyph"], [UIFont systemFontOfSize:10 weight:UIFontWeightHeavy], accent);
        glyph.frame = icon.bounds;
        glyph.textAlignment = NSTextAlignmentCenter;
        glyph.adjustsFontSizeToFitWidth = YES;
        [icon addSubview:glyph];
        UILabel *name = HSONLabel(item[@"title"], [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy], UIColor.whiteColor);
        name.frame = CGRectMake(12, 59, thisCardWidth - 48, 19);
        name.adjustsFontSizeToFitWidth = YES;
        name.minimumScaleFactor = 0.82;
        name.userInteractionEnabled = NO;
        [card addSubview:name];
        UILabel *detail = HSONLabel(item[@"detail"], [UIFont systemFontOfSize:10 weight:UIFontWeightMedium], HSONColor(187, 210, 237, 1));
        detail.frame = CGRectMake(12, 79, thisCardWidth - 24, 28);
        detail.userInteractionEnabled = NO;
        [card addSubview:detail];
        [scroll addSubview:card];
    }
    CGFloat contentH = firstY + 2 * (cardHeight + gap) + 20;
    scroll.contentSize = CGSizeMake(width, contentH);
}

static void HSONBuildCreatorPage(UIScrollView *scroll, CGFloat width) {
    for (UIView *view in [scroll.subviews copy]) [view removeFromSuperview];
    scroll.contentOffset = CGPointZero;
    scroll.scrollEnabled = YES;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(7, 7, width - 14, 210)];
    card.backgroundColor = HSONColor(18, 33, 56, 0.98);
    card.layer.cornerRadius = 24;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1;
    card.layer.borderColor = HSONColor(96, 187, 255, 0.35).CGColor;
    HSONGradient(card, @"hson.creator", @[HSONColor(19, 44, 76, 0.98), HSONColor(31, 33, 71, 0.98)]);
    [scroll addSubview:card];

    UIView *avatar = [[UIView alloc] initWithFrame:CGRectMake(18, 18, 62, 62)];
    avatar.layer.cornerRadius = 20;
    avatar.layer.cornerCurve = kCACornerCurveContinuous;
    avatar.layer.borderWidth = 1.5;
    avatar.layer.borderColor = HSONColor(176, 230, 255, 0.85).CGColor;
    HSONGradient(avatar, @"hson.avatar", @[HSONColor(24, 199, 255, 1), HSONColor(103, 88, 255, 1)]);
    [card addSubview:avatar];
    UILabel *hs = HSONLabel(@"HS", [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy], UIColor.whiteColor);
    hs.frame = avatar.bounds;
    hs.textAlignment = NSTextAlignmentCenter;
    [avatar addSubview:hs];
    UILabel *overline = HSONLabel(@"CREATOR / UI DESIGN", [UIFont systemFontOfSize:9 weight:UIFontWeightHeavy], HSONColor(165, 218, 255, 1));
    overline.frame = CGRectMake(92, 25, width - 120, 16);
    [card addSubview:overline];
    UILabel *name = HSONLabel(@"HSON", [UIFont systemFontOfSize:26 weight:UIFontWeightHeavy], UIColor.whiteColor);
    name.frame = CGRectMake(90, 42, width - 120, 35);
    [card addSubview:name];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(18, 96, width - 50, 1)];
    line.backgroundColor = HSONColor(116, 177, 231, 0.3);
    [card addSubview:line];
    UILabel *description = HSONLabel(@"Menu độc lập tối ưu cho Video Star. Ba tính năng tự động: Auto nhập ảnh, Auto chia beat, Auto nhập phân cảnh được tinh chỉnh mượt mà 100%.",
                                     [UIFont systemFontOfSize:12 weight:UIFontWeightMedium], HSONColor(203, 220, 242, 1));
    description.frame = CGRectMake(18, 108, width - 50, 75);
    [card addSubview:description];
    UILabel *version = HSONLabel(@"HSON  •  MODERN MENU v5.0.0", [UIFont systemFontOfSize:9 weight:UIFontWeightHeavy], HSONColor(138, 177, 219, 1));
    version.frame = CGRectMake(7, 230, width - 14, 18);
    version.textAlignment = NSTextAlignmentCenter;
    [scroll addSubview:version];
    scroll.contentSize = CGSizeMake(width, 260);
}

@interface HSONMenuActionTarget : NSObject
- (void)hsonFeatureTapped:(UIButton *)sender;
- (void)hsonTabTapped:(UIButton *)sender;
- (void)hsonCloseTapped;
@end
@implementation HSONMenuActionTarget
- (void)hsonFeatureTapped:(UIButton *)sender { HSONRunFeature(sender.tag); }
- (void)hsonTabTapped:(UIButton *)sender {
    gHSONSelectedTab = sender.tag;
    if (!gHSONPanel) return;
    UIScrollView *scroll = [gHSONPanel viewWithTag:901];
    if (!scroll) return;
    CGFloat width = CGRectGetWidth(scroll.bounds);
    if (gHSONSelectedTab == 2) HSONBuildCreatorPage(scroll, width);
    else HSONBuildFeaturePage(scroll, width, gHSONSelectedTab == 0);
    UIView *tabContainer = [gHSONPanel viewWithTag:902];
    for (UIView *candidate in tabContainer.subviews) {
        if (![candidate isKindOfClass:UIButton.class]) continue;
        UIButton *tab = (UIButton *)candidate;
        BOOL selected = tab.tag == gHSONSelectedTab;
        tab.backgroundColor = selected ? HSONColor(31, 91, 139, 1) : HSONColor(25, 42, 68, 0.95);
        tab.layer.borderColor = (selected ? HSONColor(94, 198, 255, 0.75) : HSONColor(91, 157, 221, 0.25)).CGColor;
    }
}
- (void)hsonCloseTapped { HSONHideMenu(); }
@end

static void HSONOpenMenu(void) {
    UIWindow *window = HSONKeyWindow();
    if (!window) return;
    if (gHSONDimView) { HSONHideMenu(); return; }
    gHSONWindow = window;
    if (!gHSONActionTarget) gHSONActionTarget = [HSONMenuActionTarget new];

    UIView *dim = [[UIView alloc] initWithFrame:window.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.68];
    dim.userInteractionEnabled = YES;
    UITapGestureRecognizer *dismiss = [[UITapGestureRecognizer alloc] initWithTarget:gHSONActionTarget action:@selector(hsonCloseTapped)];
    [dim addGestureRecognizer:dismiss];
    [window addSubview:dim];
    gHSONDimView = dim;

    CGFloat maxWidth = MIN(390, CGRectGetWidth(window.bounds) - 30);
    CGFloat maxHeight = MIN(575, CGRectGetHeight(window.bounds) - 60);
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((CGRectGetWidth(window.bounds) - maxWidth) / 2,
                                                             (CGRectGetHeight(window.bounds) - maxHeight) / 2,
                                                             maxWidth, maxHeight)];
    panel.backgroundColor = HSONColor(8, 13, 27, 1);
    panel.layer.cornerRadius = 27;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = HSONColor(90, 192, 255, 0.42).CGColor;
    panel.layer.shadowColor = HSONColor(33, 124, 255, 1).CGColor;
    panel.layer.shadowOpacity = 0.32;
    panel.layer.shadowRadius = 28;
    panel.layer.shadowOffset = CGSizeMake(0, 15);
    panel.clipsToBounds = YES;
    HSONGradient(panel, @"hson.panel", @[HSONColor(7, 14, 29, 1), HSONColor(13, 28, 51, 1), HSONColor(31, 22, 59, 1)]);
    [window addSubview:panel];
    gHSONPanel = panel;

    UILabel *brand = HSONLabel(@"HSON", [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy], UIColor.whiteColor);
    brand.frame = CGRectMake(18, 12, 150, 30);
    [panel addSubview:brand];
    UILabel *subtitle = HSONLabel(@"VIDEO STAR  /  CREATOR EDITION", [UIFont systemFontOfSize:9 weight:UIFontWeightBold], HSONColor(127, 203, 255, 1));
    subtitle.frame = CGRectMake(19, 41, maxWidth - 90, 14);
    [panel addSubview:subtitle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(maxWidth - 52, 13, 36, 34);
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:25 weight:UIFontWeightMedium];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    close.backgroundColor = HSONColor(38, 61, 95, 0.9);
    close.layer.cornerRadius = 12;
    close.layer.borderWidth = 1;
    close.layer.borderColor = HSONColor(115, 193, 255, 0.35).CGColor;
    [close addTarget:gHSONActionTarget action:@selector(hsonCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:close];

    UIView *tabContainer = [[UIView alloc] initWithFrame:CGRectMake(14, 64, maxWidth - 28, 42)];
    tabContainer.tag = 902;
    tabContainer.backgroundColor = HSONColor(14, 24, 43, 0.9);
    tabContainer.layer.cornerRadius = 15;
    tabContainer.layer.cornerCurve = kCACornerCurveContinuous;
    tabContainer.layer.borderWidth = 1;
    tabContainer.layer.borderColor = HSONColor(84, 158, 237, 0.28).CGColor;
    [panel addSubview:tabContainer];

    NSArray<NSString *> *titles = @[@"Trang chủ", @"Chức năng", @"Tác giả"];
    CGFloat tabW = floor((CGRectGetWidth(tabContainer.bounds) - 8) / titles.count);
    NSMutableArray<UIButton *> *tabButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *tab = [UIButton buttonWithType:UIButtonTypeCustom];
        tab.frame = CGRectMake(4 + i * tabW, 4, tabW, 34);
        tab.tag = i;
        [tab setTitle:titles[i] forState:UIControlStateNormal];
        tab.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
        [tab setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        tab.layer.cornerRadius = 11;
        tab.layer.cornerCurve = kCACornerCurveContinuous;
        tab.layer.borderWidth = 1;
        tab.layer.borderColor = HSONColor(91, 157, 221, 0.25).CGColor;
        [tab addTarget:gHSONActionTarget action:@selector(hsonTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tabContainer addSubview:tab];
        [tabButtons addObject:tab];
    }

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(14, 116, maxWidth - 28, maxHeight - 128)];
    scroll.tag = 901;
    scroll.showsVerticalScrollIndicator = NO;
    [panel addSubview:scroll];

    gHSONSelectedTab = 0;
    HSONBuildFeaturePage(scroll, CGRectGetWidth(scroll.bounds), YES);
    [gHSONActionTarget hsonTabTapped:tabButtons[0]];
}

static void HSONLauncherTapped(void) {
    if (gHSONDimView) HSONHideMenu();
    else HSONOpenMenu();
}

@interface HSONLauncherTarget : NSObject
@property (nonatomic, assign) CGPoint lastPosition;
- (void)hsonLaunch:(UIButton *)sender;
- (void)hsonPan:(UIPanGestureRecognizer *)pan;
@end
@implementation HSONLauncherTarget
- (void)hsonLaunch:(UIButton *)sender { (void)sender; HSONLauncherTapped(); }
- (void)hsonPan:(UIPanGestureRecognizer *)pan {
    if (!gHSONLauncher) return;
    UIView *superview = gHSONLauncher.superview;
    if (!superview) return;

    CGPoint translation = [pan translationInView:superview];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.lastPosition = gHSONLauncher.center;
    }
    CGPoint proposed = CGPointMake(self.lastPosition.x + translation.x,
                                   self.lastPosition.y + translation.y);
    UIWindow *win = [superview isKindOfClass:UIWindow.class] ? (UIWindow *)superview : HSONKeyWindow();
    CGPoint clamped = HSONClampLauncherCenter(proposed, gHSONLauncher.bounds.size, win);
    gHSONLauncher.center = clamped;

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
        [ud setDouble:clamped.x forKey:kHSONLauncherPosXKey];
        [ud setDouble:clamped.y forKey:kHSONLauncherPosYKey];
        [ud synchronize];
    }
}
@end

static void HSONAttachLauncherAttempt(NSUInteger attempt) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *exeName = NSProcessInfo.processInfo.processName ?: @"";

    // Support standard Video Star, patched/sideloaded variants, or direct injection
    BOOL isVideoStar = [bundleID.lowercaseString containsString:@"videostar"] ||
                       [exeName.lowercaseString containsString:@"videostar"] ||
                       [bundleID isEqualToString:@"com.frontierdesign.videostar"] ||
                       [bundleID isEqualToString:@"com.frontierdesign.videostar1"] ||
                       [bundleID isEqualToString:@"com.cameraxis.videostar"];
    if (!isVideoStar && bundleID.length > 0 && [bundleID hasPrefix:@"com.apple."]) {
        return;
    }

    UIWindow *window = HSONKeyWindow();
    if (!window) {
        if (attempt == 0) NSLog(@"[HSONMenu] Waiting for a visible Video Star window");
        if (attempt < 120) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                HSONAttachLauncherAttempt(attempt + 1);
            });
        }
        return;
    }

    if (gHSONLauncher && gHSONLauncher.superview == window) {
        gHSONLauncher.hidden = NO;
        gHSONLauncher.alpha = 1.0;
        [window bringSubviewToFront:gHSONLauncher];
        return;
    }

    [gHSONLauncher removeFromSuperview];
    gHSONWindow = window;
    if (!gHSONLauncherTarget) gHSONLauncherTarget = [HSONLauncherTarget new];

    UIButton *launcher = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat size = 54;
    CGFloat width = CGRectGetWidth(window.bounds);
    CGFloat height = CGRectGetHeight(window.bounds);

    // Restore saved position or use default
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    CGPoint defaultCenter;
    if ([ud objectForKey:kHSONLauncherPosXKey] && [ud objectForKey:kHSONLauncherPosYKey]) {
        defaultCenter = CGPointMake([ud doubleForKey:kHSONLauncherPosXKey],
                                    [ud doubleForKey:kHSONLauncherPosYKey]);
    } else {
        CGFloat x = MAX(size / 2.0 + 12.0, width - size / 2.0 - 18.0);
        CGFloat y = MIN(MAX(height * 0.68, 110.0), MAX(110.0, height - size - 100.0));
        defaultCenter = CGPointMake(x, y);
    }
    defaultCenter = HSONClampLauncherCenter(defaultCenter, CGSizeMake(size, size), window);

    launcher.frame = CGRectMake(defaultCenter.x - size / 2.0, defaultCenter.y - size / 2.0, size, size);
    launcher.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    launcher.backgroundColor = HSONColor(20, 93, 148, 1);
    launcher.layer.cornerRadius = size / 2;
    launcher.layer.borderWidth = 1.5;
    launcher.layer.borderColor = HSONColor(171, 231, 255, 0.9).CGColor;
    launcher.layer.shadowColor = HSONColor(17, 147, 255, 1).CGColor;
    launcher.layer.shadowOpacity = 0.45;
    launcher.layer.shadowRadius = 14;
    launcher.layer.shadowOffset = CGSizeMake(0, 5);
    HSONGradient(launcher, @"hson.launcher", @[HSONColor(24, 199, 255, 1), HSONColor(103, 88, 255, 1)]);

    UILabel *logo = HSONLabel(@"HS", [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy], UIColor.whiteColor);
    logo.frame = launcher.bounds;
    logo.textAlignment = NSTextAlignmentCenter;
    logo.userInteractionEnabled = NO;
    [launcher addSubview:logo];

    [launcher addTarget:gHSONLauncherTarget action:@selector(hsonLaunch:) forControlEvents:UIControlEventTouchUpInside];

    // Add Pan gesture for smooth dragging
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:gHSONLauncherTarget action:@selector(hsonPan:)];
    [launcher addGestureRecognizer:pan];

    launcher.accessibilityLabel = @"Open HSON menu";
    launcher.accessibilityHint = @"Show the HSON tool menu";
    [window addSubview:launcher];
    [window bringSubviewToFront:launcher];
    gHSONLauncher = launcher;
    NSLog(@"[HSONMenu] Launcher attached to Video Star window %@", window);
}

static NSMutableArray *gHSONLifecycleObservers;

static void HSONInstallLifecycleObservers(void) {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    gHSONLifecycleObservers = [NSMutableArray array];
    NSArray<NSString *> *names = @[
        UIApplicationDidBecomeActiveNotification,
        UISceneDidActivateNotification,
        UIWindowDidBecomeKeyNotification,
        UIWindowDidBecomeVisibleNotification
    ];
    for (NSString *name in names) {
        id token = [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                  usingBlock:^(__unused NSNotification *notification) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                HSONAttachLauncherAttempt(0);
            });
        }];
        if (token) [gHSONLifecycleObservers addObject:token];
    }
}

__attribute__((constructor)) static void HSONModernMenuInit(void) {
    NSLog(@"[HSONMenu] Constructor loaded in bundle %@ (process: %@)",
          NSBundle.mainBundle.bundleIdentifier, NSProcessInfo.processInfo.processName);
    dispatch_async(dispatch_get_main_queue(), ^{
        gHSONLauncherTarget = [HSONLauncherTarget new];
        gHSONActionTarget = [HSONMenuActionTarget new];
        HSONInstallLifecycleObservers();
        HSONAttachLauncherAttempt(0);

        NSArray<NSNumber *> *delays = @[@0.4, @1.2, @2.5, @5.0];
        for (NSNumber *delay in delays) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                HSONAttachLauncherAttempt(0);
            });
        }
    });
}
