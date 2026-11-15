// Internal refresh coordination only. No UI publication, permission prompts,
// authorization writes or background execution entitlement.
static NSString *const WQScanConsentKey = @"3105.WQScanConsent.v1";
static NSString *const WQScanRunningKey = @"3105.WQScanRunning.v1";
static NSMutableDictionary *WQScanState;
static BOOL WQScanStopped;
static BOOL WQScanBusy;
static BOOL WQScanNeedsRetry;
static BOOL WQScanForeground;
static BOOL WQScanTransient;

BOOL WQInternalRefreshEnabled(void) { return YES; }
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
    @synchronized (WQScanConsentKey) { return [WQScanState copy] ?: @{}; }
}
void WQIntegratedScanCancel(void) {
    @synchronized (WQScanConsentKey) {
        WQScanStopped = YES;
        WQScanState[@"status"] = @"stopped";
        [NSUserDefaults.standardUserDefaults removeObjectForKey:WQScanRunningKey];
    }
    wq_full_scan_stop();
    wq_log(@"refresh.internal: cancelled; cached results retained");
}
void WQIntegratedPrepareRefresh(void) {
    BOOL retry;
    @synchronized (WQScanConsentKey) { retry = WQScanNeedsRetry; WQScanNeedsRetry = NO; }
    if (retry) wq_enumerate_invalidate(); // original cache lifecycle, no cache deletion
}
BOOL WQIntegratedBeginRefresh(void) {
    @synchronized (WQScanConsentKey) {
        if (WQScanBusy || !WQScanForeground) return NO;
        if ([WQScanState[@"status"] isEqual:@"stopped"]) WQScanNeedsRetry = YES;
        WQScanBusy = YES; WQScanStopped = NO; WQScanTransient = NO;
        WQScanState[@"status"] = @"idle";
        return YES;
    }
}
void WQIntegratedEndRefresh(void) {
    @synchronized (WQScanConsentKey) { WQScanBusy = NO; }
}
void WQIntegratedScanAuthorize(void) {
    // Retained for binary/source compatibility only; automatic refresh cannot grant consent.
    wq_log(@"refresh.internal: new authorization required; automatic grant refused");
}
NSTimeInterval WQIntegratedRefreshRetryDelay(NSUInteger attempt, BOOL transient) {
    const NSTimeInterval delays[] = {2, 8, 30};
    return transient && attempt < 3 ? delays[attempt] : -1;
}
BOOL WQIntegratedRefreshHadTransientError(void) {
    @synchronized (WQScanConsentKey) { return WQScanTransient; }
}
static void WQRefreshRecordError(int code) {
    if (code == EINTR || code == EAGAIN || code == EBUSY || code == ETIMEDOUT) {
        @synchronized (WQScanConsentKey) { WQScanTransient = YES; }
    }
    if (code) wq_log(@"refresh.internal: source errno=%d", code);
}
static BOOL WQScanConfirmPresentation(NSString *what, int64_t ids, double seconds) {
    if (NSThread.isMainThread || !wq_app_group()) return NO;
    @synchronized (WQScanConsentKey) {
        NSDictionary *consent = [NSUserDefaults.standardUserDefaults dictionaryForKey:WQScanConsentKey][WQScanScope(what)];
        BOOL allowed = !WQScanStopped && WQScanForeground && WQScanConsentValid(consent, ids, NSDate.date);
        WQScanState[@"status"] = allowed ? @"running" : @"blocked";
        if (allowed) [NSUserDefaults.standardUserDefaults setObject:what forKey:WQScanRunningKey];
        wq_log(@"refresh.internal: scope=%@ full scan %@ (ids=%lld)", what, allowed ? @"previously authorized" : @"skipped: permission/scope/foreground", ids);
        return allowed;
    }
}
static void WQScanProgressPresentation(int64_t done, int64_t total, BOOL finished) {
    BOOL stop;
    @synchronized (WQScanConsentKey) { stop = WQScanStopped; }
    if (stop) wq_full_scan_stop();
    @synchronized (WQScanConsentKey) {
        if (finished) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:WQScanRunningKey];
            if (!WQScanStopped) WQScanState[@"status"] = @"complete";
            wq_log(@"refresh.internal: scan finished (cancelled=%d)", WQScanStopped);
        }
    }
}
static void WQScanRestorePresentationState(void) {
    WQScanState = [NSMutableDictionary new];
    if ([NSUserDefaults.standardUserDefaults objectForKey:WQScanRunningKey]) {
        WQScanState[@"status"] = @"stopped";
        [NSUserDefaults.standardUserDefaults removeObjectForKey:WQScanRunningKey];
        wq_log(@"refresh.internal: interrupted operation recovered; valid cache retained");
    }
}
static void WQScanInitializePresentation(void) {
    WQScanRestorePresentationState();
    WQScanForeground = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        @synchronized (WQScanConsentKey) { WQScanForeground = YES; }
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        @synchronized (WQScanConsentKey) { WQScanForeground = NO; }
        if (WQScanBusy || [WQIntegratedScanState()[@"status"] isEqual:@"running"]) WQIntegratedScanCancel();
    }];
    wq_set_full_scan_ui(WQScanConfirmPresentation, WQScanProgressPresentation);
}

#ifdef WQ_SCAN_UI_TESTING
BOOL WQScanConsentPolicyTests(void) {
    NSDate *now = NSDate.date;
    NSDictionary *valid = @{ @"ids": @1000, @"until": [now dateByAddingTimeInterval:60] };
    NSDictionary *expired = @{ @"ids": @1000, @"until": [now dateByAddingTimeInterval:-1] };
    BOOL policy = !WQScanConsentValid(nil, 1000, now) &&
        WQScanConsentValid(valid, 1000, now) && WQScanConsentValid(valid, 1500, now) &&
        !WQScanConsentValid(valid, 1501, now) && !WQScanConsentValid(expired, 1000, now) &&
        !WQScanConsentValid(valid, 0, now) &&
        ![WQScanScope(@"Internal Daemons") isEqual:WQScanScope(@"System")];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary *oldConsent = [defaults dictionaryForKey:WQScanConsentKey];
    id oldMarker = [defaults objectForKey:WQScanRunningKey];
    NSMutableDictionary *oldState = WQScanState;
    [defaults setObject:@{ WQScanScope(@"test"): valid } forKey:WQScanConsentKey];
    [defaults setObject:@"interrupted-test" forKey:WQScanRunningKey];
    WQScanRestorePresentationState();
    NSDictionary *beforeNoGrant = [defaults dictionaryForKey:WQScanConsentKey];
    WQIntegratedScanAuthorize();
    BOOL noGrant = [[defaults dictionaryForKey:WQScanConsentKey] isEqual:beforeNoGrant];
    BOOL recovered = [WQScanState[@"status"] isEqual:@"stopped"] &&
        ![defaults objectForKey:WQScanRunningKey] &&
        WQScanConsentValid([defaults dictionaryForKey:WQScanConsentKey][WQScanScope(@"test")], 1000, now);
    WQScanState = oldState;
    if (oldConsent) [defaults setObject:oldConsent forKey:WQScanConsentKey];
    else [defaults removeObjectForKey:WQScanConsentKey];
    if (oldMarker) [defaults setObject:oldMarker forKey:WQScanRunningKey];
    else [defaults removeObjectForKey:WQScanRunningKey];
    BOOL backoff = WQIntegratedRefreshRetryDelay(0, YES) == 2 &&
        WQIntegratedRefreshRetryDelay(1, YES) == 8 && WQIntegratedRefreshRetryDelay(2, YES) == 30 &&
        WQIntegratedRefreshRetryDelay(3, YES) < 0 && WQIntegratedRefreshRetryDelay(0, NO) < 0;
    return policy && recovered && backoff && noGrant;
}
#endif

// Native screens retain their original worker and cache logic. Only retry
// ownership/delay is added here, with weak lifetime and a foreground check.
void WQInternalRefreshRetry(id owner, SEL action, int errorCode) {
    NSCAssert(NSThread.isMainThread, @"Retry scheduling requires main queue");
    static char retryKey;
    if ([WQIntegratedScanState()[@"status"] isEqual:@"blocked"]) return;
    BOOL transient = errorCode == EINTR || errorCode == EAGAIN || errorCode == EBUSY || errorCode == ETIMEDOUT;
    NSMutableDictionary *state = objc_getAssociatedObject(owner, &retryKey);
    if (!state) { state = [@{ @"attempt": @0, @"pending": @NO } mutableCopy]; objc_setAssociatedObject(owner, &retryKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if ([state[@"pending"] boolValue]) return;
    if (!errorCode) { state[@"attempt"] = @0; return; }
    NSTimeInterval delay = WQIntegratedRefreshRetryDelay([state[@"attempt"] unsignedIntegerValue], transient);
    if (delay < 0) { wq_log(@"refresh.internal: native retry stopped errno=%d", errorCode); return; }
    state[@"attempt"] = @([state[@"attempt"] unsignedIntegerValue] + 1);
    state[@"pending"] = @YES;
    __weak id weakOwner = owner;
    wq_log(@"refresh.internal: native transient errno=%d retry in %.0fs", errorCode, delay);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        state[@"pending"] = @NO;
        id target = weakOwner;
        if (!target || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        if ([target isKindOfClass:UIViewController.class] && !((UIViewController *)target).viewIfLoaded.window) return;
        if ([target respondsToSelector:action]) ((void (*)(id, SEL))[target methodForSelector:action])(target, action);
    });
}

#ifdef WQ_SCAN_UI_TESTING
@interface WQInternalRetryProbe : NSObject
@property(nonatomic) NSUInteger calls;
@property(nonatomic) BOOL completed;
@property(nonatomic, copy) void (^completion)(BOOL);
- (void)retry;
@end
@implementation WQInternalRetryProbe
- (void)retry {
    self.calls++;
    WQInternalRefreshRetry(self, @selector(retry), EAGAIN);
    if (self.calls == 3) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.completed) { self.completed = YES; self.completion(self.calls == 3); }
    });
}
@end
void WQInternalRetryExercise(void (^completion)(BOOL)) {
    WQInternalRetryProbe *probe = [WQInternalRetryProbe new];
    probe.completion = completion;
    WQInternalRefreshRetry(probe, @selector(retry), EAGAIN);
    WQInternalRefreshRetry(probe, @selector(retry), EAGAIN); // duplicate is rejected
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 75 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!probe.completed) { probe.completed = YES; probe.completion(NO); }
    });
}
#endif
