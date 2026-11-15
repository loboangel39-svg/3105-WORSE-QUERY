#import <Foundation/Foundation.h>
extern BOOL WQInternalRefreshEnabled(void);
static inline BOOL WQSilentRefresh(void) {
    return WQInternalRefreshEnabled();
}
extern void WQInternalRefreshRetry(id owner, SEL action, int errorCode);
static inline void WQRetryInternal(id owner, SEL action, int errorCode) {
    if (WQSilentRefresh()) WQInternalRefreshRetry(owner, action, errorCode);
}
