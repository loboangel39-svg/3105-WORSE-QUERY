#import <Foundation/Foundation.h>
extern BOOL WQInternalRefreshEnabled(void) __attribute__((weak_import));
static inline BOOL WQSilentRefresh(void) {
    return WQInternalRefreshEnabled && WQInternalRefreshEnabled();
}
