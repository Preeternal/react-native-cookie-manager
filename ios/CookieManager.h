#if RCT_NEW_ARCH_ENABLED
#import <CookieManagerSpec/CookieManagerSpec.h>
@interface CookieManager : NSObject <NativeCookieManagerSpec>
#else
#import <React/RCTBridgeModule.h>
@interface CookieManager : NSObject <RCTBridgeModule>
#endif

@end
