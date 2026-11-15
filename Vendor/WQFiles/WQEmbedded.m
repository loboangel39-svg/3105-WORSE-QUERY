#define main WQStandaloneMain
#include "main.m"
#undef main
#import "WQEmbedded.h"

void WQIntegratedInitialize(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        wq_set_container_label_resolver(wq_bundle_id_for_container);
        wq_set_container_list_provider(wq_ls_container_paths);
        wq_set_full_scan_ui(wq_confirm_full_scan, wq_full_scan_progress);
        wq_media_sweep_stale();
        wq_share_sweep_stale_exports();
    });
}

@interface WQEmbeddedHost : UIViewController
@end
@implementation WQEmbeddedHost
- (void)viewDidLoad {
    [super viewDidLoad];
    [self rebuild];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(rebuild)
        name:@"WQEmbeddedDesignChanged" object:nil];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
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
