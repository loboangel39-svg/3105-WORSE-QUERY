#define main WQStandaloneMain
#include "main.m"
#undef main
#import "WQEmbedded.h"
#include "WQScanPresentation.inc"

void WQIntegratedInitialize(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        wq_set_container_label_resolver(wq_bundle_id_for_container);
        wq_set_container_list_provider(wq_ls_container_paths);
        WQScanInitializePresentation();
        wq_media_sweep_stale();
        wq_share_sweep_stale_exports();
    });
}

@interface WQEmbeddedHost : UIViewController
@property(nonatomic, strong) UIStackView *scanBanner;
@property(nonatomic, strong) UILabel *scanLabel;
@property(nonatomic, strong) UIButton *scanAction;
@property(nonatomic, strong) UIButton *scanStop;
@end
@implementation WQEmbeddedHost
- (void)viewDidLoad {
    [super viewDidLoad];
    self.scanLabel = [UILabel new];
    self.scanLabel.numberOfLines = 0;
    self.scanLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.scanAction = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.scanAction addTarget:self action:@selector(scanContinue) forControlEvents:UIControlEventTouchUpInside];
    self.scanStop = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.scanStop setTitle:WQLocalized(@"Cancel") forState:UIControlStateNormal];
    [self.scanStop addTarget:self action:@selector(scanCancel) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[self.scanAction, self.scanStop]];
    buttons.spacing = 12;
    self.scanBanner = [[UIStackView alloc] initWithArrangedSubviews:@[self.scanLabel, buttons]];
    self.scanBanner.axis = UILayoutConstraintAxisVertical;
    self.scanBanner.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.scanBanner.layoutMarginsRelativeArrangement = YES;
    self.scanBanner.layoutMargins = UIEdgeInsetsMake(8, 12, 8, 12);
    [self.view addSubview:self.scanBanner];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateScanBanner) name:@"WQScanPresentationChanged" object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(scanRetry) name:@"WQScanRetryRequested" object:nil];
    [self rebuild];
    [self updateScanBanner];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(rebuild)
        name:@"WQEmbeddedDesignChanged" object:nil];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)scanCancel { WQIntegratedScanCancel(); }
- (void)scanContinue {
    if ([WQIntegratedScanState()[@"status"] isEqual:@"permission"]) WQIntegratedScanAuthorize();
    else [self scanRetry];
}
- (void)scanRetry {
    if (!self.view.window || !WQIntegratedBeginRefresh()) return;
    dispatch_async(wq_io(), ^{
        WQIntegratedPrepareRefresh();
        dispatch_async(dispatch_get_main_queue(), ^{ [self rebuild]; WQIntegratedEndRefresh(); });
    });
}
- (void)updateScanBanner {
    NSDictionary *state = WQIntegratedScanState();
    NSString *status = state[@"status"];
    BOOL permission = [status isEqual:@"permission"];
    BOOL running = [status isEqual:@"running"];
    BOOL stopped = [status isEqual:@"stopped"];
    self.scanBanner.hidden = !permission && !running && !stopped;
    self.scanAction.hidden = running;
    self.scanStop.hidden = stopped;
    [self.scanAction setTitle:permission ? WQLocalized(@"Start Scan") : WQLocalized(@"Try Again") forState:UIControlStateNormal];
    if (permission) self.scanLabel.text = [NSString stringWithFormat:@"Scan %@: up to %@ file IDs. May take several minutes; no files are modified. Allow for 7 days for this scope (up to 50%% growth). You can navigate and cancel.", state[@"scope"], state[@"total"]];
    else if (running) self.scanLabel.text = [NSString stringWithFormat:@"%@ · %.0f%%", state[@"scope"], 100.0 * [state[@"done"] doubleValue] / MAX(1.0, [state[@"total"] doubleValue])];
    else self.scanLabel.text = @"Scan stopped. Previous results and valid cache are retained.";
    [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.scanBanner.hidden ? 0 : [self.scanBanner systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    self.scanBanner.frame = CGRectMake(0, self.view.safeAreaInsets.top, width, height);
    self.childViewControllers.firstObject.additionalSafeAreaInsets = UIEdgeInsetsMake(height, 0, 0, 0);
    [self.view bringSubviewToFront:self.scanBanner];
}
- (void)rebuild {
    for (UIViewController *child in self.childViewControllers) {
        [child willMoveToParentViewController:nil];
        [child.view removeFromSuperview];
        [child removeFromParentViewController];
    }
    UIViewController *root = wq_make_root_view_controller();
    [self addChildViewController:root];
    root.view.frame = self.view.bounds;
    root.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:root.view];
    [root didMoveToParentViewController:self];
}
@end

UIViewController *WQIntegratedMakeViewController(void) {
    WQIntegratedInitialize();
    return [WQEmbeddedHost new];
}

NSDictionary *WQIntegratedIdentities(NSArray<NSString *> *paths) {
    WQIntegratedInitialize();
    wq_load_display_names();
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *path in paths) {
        NSString *identifier = wq_container_label(path);
        if (!identifier.length) continue;
        result[path] = @{ @"bundleID": identifier,
            @"displayName": wq_display_name(identifier) ?: identifier };
    }
    return result;
}

NSDictionary<NSString *, id> *WQIntegratedRuntimeReport(void) {
    WQIntegratedInitialize();
    wq_load_display_names();
    NSMutableDictionary *containers = [NSMutableDictionary new];
    NSMutableDictionary *display = [NSMutableDictionary new];
    for (NSString *path in wq_ls_container_paths(nil)) {
        NSString *bid = wq_bundle_id_for_container(path);
        if (!bid.length) continue;
        containers[path] = bid;
        NSString *name = wq_display_name(bid);
        if (name.length) display[bid] = name;
    }
    NSString *path = [NSUserDefaults.standardUserDefaults stringForKey:@"WQLaunchServicesStore"];
    struct stat st = {0};
    BOOL readable = wq_display_names_loaded() && path.length && wq_stat(path, &st);
    NSMutableDictionary *report = [@{
        @"sourceState": readable ? @"valid" : @"unavailable",
        @"sourceFound": @(path.length > 0), @"sourceReadable": @(readable),
        @"storeBytes": readable ? @(st.st_size) : @0,
        // The original parser logs its layout and raw record counts itself.
        // These are not inferred from the number of mapped container paths.
        @"layout": @"original-parser (see WQFiles names log)", @"records": @(-1),
        @"containers": containers, @"display": display, @"bundleNames": @{},
        @"bundleIDs": @([NSSet setWithArray:containers.allValues].count),
        @"verifiedNames": @(display.count)
    } mutableCopy];
    if (path.length) report[@"sourcePath"] = path;
    return report;
}
