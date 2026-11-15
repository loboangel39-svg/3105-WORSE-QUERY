#import <Foundation/Foundation.h>
extern BOOL WQInternalRefreshEnabled(void) __attribute__((weak_import));
static inline BOOL WQSilentRefresh(void) {
    return WQInternalRefreshEnabled && WQInternalRefreshEnabled();
}
extern void WQInternalRefreshRetry(id owner, SEL action, int errorCode) __attribute__((weak_import));
static inline void WQRetryInternal(id owner, SEL action, int errorCode) {
    if (WQSilentRefresh() && WQInternalRefreshRetry) WQInternalRefreshRetry(owner, action, errorCode);
}
