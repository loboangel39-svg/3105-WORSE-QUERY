// 3105 presentation adapter. All mutable UI state is confined to the main queue.
// No container access, parser, scan algorithm or cache format is changed here.
static NSString *const WQScanConsentKey = @"3105.WQScanConsent.v1";
static NSString *const WQScanRunningKey = @"3105.WQScanRunning.v1";
static NSMutableDictionary *WQScanState;
static BOOL WQScanStopped;
static BOOL WQScanBusy;
static BOOL WQScanDeferredRetry;
static BOOL WQScanNeedsRetry;

static void WQScanPublish(void) {
    [NSNotificationCenter.defaultCenter postNotificationName:@"WQScanPresentationChanged" object:nil];
}
static NSString *WQScanScope(NSString *what) {
    return [NSString stringWithFormat:@"%ld:%@", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, what];
}
static BOOL WQScanConsentValid(NSDictionary *consent, int64_t ids, NSDate *now) {
    NSDate *until = consent[@"until"];
    int64_t approved = [consent[@"ids"] longLongValue];
    return [until isKindOfClass:NSDate.class] && [until compare:now] == NSOrderedDescending &&
        ids > 0 && approved > 0 && (double)ids <= (double)approved * 1.5;
}
NSDictionary *WQIntegratedScanState(void) {
    NSCAssert(NSThread.isMainThread, @"UI state requires main queue");
    return [WQScanState copy] ?: @{};
}
void WQIntegratedScanCancel(void) {
    NSCAssert(NSThread.isMainThread, @"UI action requires main queue");
    WQScanStopped = YES;
    WQScanDeferredRetry = NO;
    wq_full_scan_stop();
    WQScanState[@"status"] = @"stopped";
    [NSUserDefaults.standardUserDefaults removeObjectForKey:WQScanRunningKey];
    WQScanPublish();
}
void WQIntegratedPrepareRefresh(void) {
    NSCAssert(!NSThread.isMainThread, @"Refresh preparation requires worker queue");
    __block BOOL retry;
    dispatch_sync(dispatch_get_main_queue(), ^{ retry = WQScanNeedsRetry; WQScanNeedsRetry = NO; });
    if (retry) wq_enumerate_invalidate();
}
BOOL WQIntegratedBeginRefresh(void) {
    NSCAssert(NSThread.isMainThread, @"UI action requires main queue");
    if (WQScanBusy) return NO;
    if ([WQScanState[@"status"] isEqual:@"stopped"]) WQScanNeedsRetry = YES;
    WQScanBusy = YES;
    WQScanStopped = NO;
    WQScanState[@"refreshing"] = @YES;
    WQScanPublish();
    return YES;
}
void WQIntegratedEndRefresh(void) {
    WQScanBusy = NO;
    WQScanState[@"refreshing"] = @NO;
    WQScanPublish();
    if (WQScanDeferredRetry && UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        WQScanDeferredRetry = NO;
        [NSNotificationCenter.defaultCenter postNotificationName:@"WQScanRetryRequested" object:nil];
    }
}
void WQIntegratedScanAuthorize(void) {
    NSCAssert(NSThread.isMainThread, @"UI action requires main queue");
    if (![WQScanState[@"status"] isEqual:@"permission"]) return;
    NSMutableDictionary *consents = [[NSUserDefaults.standardUserDefaults dictionaryForKey:WQScanConsentKey] mutableCopy] ?: [NSMutableDictionary new];
    consents[WQScanScope(WQScanState[@"scope"])] = @{
        @"ids": WQScanState[@"total"], @"until": [NSDate dateWithTimeIntervalSinceNow:7 * 86400]
    };
    [NSUserDefaults.standardUserDefaults setObject:consents forKey:WQScanConsentKey];
    WQScanState[@"status"] = @"ready";
    WQScanStopped = NO;
    WQScanDeferredRetry = YES;
    WQScanNeedsRetry = YES;
    WQScanPublish();
    if (!WQScanBusy) WQIntegratedEndRefresh();
}

// Returns immediately after a short main-queue state update. Never waits for
// user input. A declined attempt unwinds through wq_full_scan_begin's gate.
static BOOL WQScanConfirmPresentation(NSString *what, int64_t ids, double seconds) {
    if (NSThread.isMainThread) return NO;
    __block BOOL allowed = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (WQScanStopped || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        NSDictionary *consent = [NSUserDefaults.standardUserDefaults dictionaryForKey:WQScanConsentKey][WQScanScope(what)];
        allowed = WQScanConsentValid(consent, ids, NSDate.date);
        // Keep the first pending scope visible until the user decides.
        if ([WQScanState[@"status"] isEqual:@"permission"]) { allowed = NO; return; }
        WQScanState[@"scope"] = what;
        WQScanState[@"total"] = @(ids);
        WQScanState[@"done"] = @0;
        WQScanState[@"seconds"] = @(seconds);
        WQScanState[@"status"] = allowed ? @"running" : @"permission";
        if (allowed) [NSUserDefaults.standardUserDefaults setObject:what forKey:WQScanRunningKey];
        WQScanPublish();
    });
    return allowed;
}
static void WQScanProgressPresentation(int64_t done, int64_t total, BOOL finished) {
    // The engine may call concurrently. Throttle updates before enqueuing UI work.
    static CFAbsoluteTime last;
    @synchronized (WQScanConsentKey) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (!finished && now - last < 0.25) return;
        last = now;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (WQScanStopped) wq_full_scan_stop();
            if (finished) {
                [NSUserDefaults.standardUserDefaults removeObjectForKey:WQScanRunningKey];
                if (!WQScanStopped) WQScanState[@"status"] = @"complete";
            } else if (!WQScanStopped) {
                WQScanState[@"done"] = @(done);
                WQScanState[@"total"] = @(total);
            }
            WQScanPublish();
        });
    }
}
static void WQScanInitializePresentation(void) {
    WQScanState = [NSMutableDictionary new];
    if ([NSUserDefaults.standardUserDefaults objectForKey:WQScanRunningKey]) {
        WQScanState[@"status"] = @"stopped";
        [NSUserDefaults.standardUserDefaults removeObjectForKey:WQScanRunningKey];
    }
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        if (WQScanBusy || [WQScanState[@"status"] isEqual:@"running"]) WQIntegratedScanCancel();
    }];
    wq_set_full_scan_ui(WQScanConfirmPresentation, WQScanProgressPresentation);
}

#ifdef WQ_SCAN_UI_TESTING
BOOL WQScanConsentPolicyTests(void) {
    NSDate *now = NSDate.date;
    NSDictionary *valid = @{ @"ids": @1000, @"until": [now dateByAddingTimeInterval:60] };
    NSDictionary *expired = @{ @"ids": @1000, @"until": [now dateByAddingTimeInterval:-1] };
    return !WQScanConsentValid(nil, 1000, now) &&
        WQScanConsentValid(valid, 1000, now) && WQScanConsentValid(valid, 1500, now) &&
        !WQScanConsentValid(valid, 1501, now) && !WQScanConsentValid(expired, 1000, now) &&
        !WQScanConsentValid(valid, 0, now) &&
        ![WQScanScope(@"Internal Daemons") isEqual:WQScanScope(@"System")];
}
#endif
