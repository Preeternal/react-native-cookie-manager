#import <React/RCTBridgeModule.h>

#if RCT_NEW_ARCH_ENABLED
#import <CookieManagerSpec/CookieManagerSpec.h>
@interface CookieManager : NSObject <NativeCookieManagerSpec>
#else
@interface CookieManager : NSObject <RCTBridgeModule>
#endif

@end
