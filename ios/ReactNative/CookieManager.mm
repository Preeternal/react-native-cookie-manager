#import "CookieManager.h"

// SwiftPM exposes the implementation as its own module, while CocoaPods
// generates the header under the pod target's module name.
#if defined(SWIFT_PACKAGE)
// SwiftPM does not expose the generated Swift compatibility header to a
// dependent Objective-C++ target when C++ modules are disabled. Declare the
// stable Objective-C surface exported by CookieManagerImpl instead.
@interface CookieManagerImpl : NSObject
- (void)startCookieChangeObserving:(void (^)(NSString *store))handler;
- (void)stopCookieChangeObserving;
- (void)set:(NSString *)url
         cookie:(NSDictionary *)cookie
      useWebKit:(BOOL)useWebKit
        validate:(BOOL)validate
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject;
- (void)setFromResponse:(NSString *)url
                 cookie:(NSString *)cookie
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject;
- (void)getFromResponse:(NSString *)url
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject;
- (void)get:(NSString *)url
       useWebKit:(BOOL)useWebKit
         resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject;
- (void)getAsArray:(NSString *)url
          useWebKit:(BOOL)useWebKit
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject;
- (void)getCookieHeader:(NSString *)url
               useWebKit:(BOOL)useWebKit
                 resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject;
- (void)clearAll:(BOOL)useWebKit
         resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject;
- (void)clearAllStoresWithResolve:(RCTPromiseResolveBlock)resolve
                           reject:(RCTPromiseRejectBlock)reject;
- (void)clearByName:(NSString *)url
               name:(NSString *)name
          useWebKit:(BOOL)useWebKit
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject;
- (void)getAll:(BOOL)useWebKit
       resolve:(RCTPromiseResolveBlock)resolve
        reject:(RCTPromiseRejectBlock)reject;
- (void)getAllAsArray:(BOOL)useWebKit
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject;
- (void)flushWithResolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject;
- (void)removeSessionCookiesWithClearFoundation:(BOOL)clearFoundation
                                     clearWebKit:(BOOL)clearWebKit
                                         resolve:(RCTPromiseResolveBlock)resolve
                                          reject:(RCTPromiseRejectBlock)reject;
@end
#elif __has_include(<CookieManager/CookieManager-Swift.h>)
#import <CookieManager/CookieManager-Swift.h>
#elif __has_include("CookieManager-Swift.h")
#import "CookieManager-Swift.h"
#else
#error "CookieManager Swift module not found; ensure CocoaPods or SwiftPM is configured"
#endif

@interface CookieManager ()
@property(nonatomic, strong) CookieManagerImpl *impl;
@end

@implementation CookieManager {
  CookieManagerImpl *_impl;
}

+ (NSString *)moduleName
{
  return @"CookieManager";
}

- (instancetype)init
{
  if (self = [super init]) {
    _impl = [CookieManagerImpl new];
  }
  return self;
}

- (void)invalidate
{
  [_impl stopCookieChangeObserving];
}

- (void)startCookieChangeObserving
{
  __weak CookieManager *weakSelf = self;
  [_impl startCookieChangeObserving:^(NSString *store) {
    CookieManager *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }
    [strongSelf emitOnCookieChange:@{ @"store" : store }];
  }];
}

- (void)stopCookieChangeObserving
{
  [_impl stopCookieChangeObserving];
}

#pragma mark - Shared helpers

- (void)handleSetWithUrlString:(NSString *)url
                        props:(NSDictionary *)props
                     useWebKit:(BOOL)useWebKit
                       validate:(BOOL)validate
                       resolve:(RCTPromiseResolveBlock)resolve
                        reject:(RCTPromiseRejectBlock)reject
{
  [_impl set:url
       cookie:props
     useWebKit:useWebKit
       validate:validate
       resolve:resolve
        reject:reject];
}

- (void)handleSetFromResponse:(NSString *)url
                       cookie:(NSString *)cookie
                      resolve:(RCTPromiseResolveBlock)resolve
                       reject:(RCTPromiseRejectBlock)reject
{
  [_impl setFromResponse:url cookie:cookie resolve:resolve reject:reject];
}

- (void)handleGetFromResponse:(NSString *)url
                      resolve:(RCTPromiseResolveBlock)resolve
                       reject:(RCTPromiseRejectBlock)reject
{
  [_impl getFromResponse:url resolve:resolve reject:reject];
}

- (void)handleGet:(NSString *)url
         useWebKit:(NSNumber *)useWebKit
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  [_impl get:url useWebKit:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleGetAsArray:(NSString *)url
               useWebKit:(NSNumber *)useWebKit
                 resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
{
  [_impl getAsArray:url useWebKit:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleGetCookieHeader:(NSString *)url
                    useWebKit:(NSNumber *)useWebKit
                      resolve:(RCTPromiseResolveBlock)resolve
                       reject:(RCTPromiseRejectBlock)reject
{
  [_impl getCookieHeader:url useWebKit:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleClearAll:(NSNumber *)useWebKit
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject
{
  [_impl clearAll:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleClearAllStores:(RCTPromiseResolveBlock)resolve
                      reject:(RCTPromiseRejectBlock)reject
{
  [_impl clearAllStoresWithResolve:resolve reject:reject];
}

- (void)handleClearByName:(NSString *)url
                     name:(NSString *)name
                useWebKit:(NSNumber *)useWebKit
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject
{
  [_impl clearByName:url name:name useWebKit:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleGetAll:(NSNumber *)useWebKit
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject
{
  [_impl getAll:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleGetAllAsArray:(NSNumber *)useWebKit
                    resolve:(RCTPromiseResolveBlock)resolve
                     reject:(RCTPromiseRejectBlock)reject
{
  [_impl getAllAsArray:[useWebKit boolValue] resolve:resolve reject:reject];
}

- (void)handleFlushWithResolve:(RCTPromiseResolveBlock)resolve
                        reject:(RCTPromiseRejectBlock)reject
{
  [_impl flushWithResolve:resolve reject:reject];
}

- (void)handleRemoveSessionCookies:(BOOL)clearFoundation
                       clearWebKit:(BOOL)clearWebKit
                           resolve:(RCTPromiseResolveBlock)resolve
                            reject:(RCTPromiseRejectBlock)reject
{
  [_impl removeSessionCookiesWithClearFoundation:clearFoundation
                                     clearWebKit:clearWebKit
                                        resolve:resolve
                                         reject:reject];
}

static NSDictionary *_Nonnull CookieManagerPropsFromSpecCookie(JS::NativeCookieManager::Cookie &cookie) {
  NSMutableDictionary *dict = [NSMutableDictionary new];
  if (cookie.name() != nil) {
    dict[@"name"] = cookie.name();
  }
  if (cookie.value() != nil) {
    dict[@"value"] = cookie.value();
  }
  if (cookie.path() != nil) {
    dict[@"path"] = cookie.path();
  }
  if (cookie.domain() != nil) {
    dict[@"domain"] = cookie.domain();
  }
  if (cookie.version() != nil) {
    dict[@"version"] = cookie.version();
  }
  if (cookie.expires() != nil) {
    dict[@"expires"] = cookie.expires();
  }
  if (cookie.secure().has_value()) {
    dict[@"secure"] = @(cookie.secure().value());
  }
  if (cookie.httpOnly().has_value()) {
    dict[@"httpOnly"] = @(cookie.httpOnly().value());
  }
  if (cookie.sameSite() != nil) {
    dict[@"sameSite"] = cookie.sameSite();
  }
  if (cookie.maxAge().has_value()) {
    dict[@"maxAge"] = @(cookie.maxAge().value());
  }
  return dict;
}

- (void)setCookie:(NSString *)url
           cookie:(JS::NativeCookieManager::Cookie &)cookie
        useWebKit:(BOOL)useWebKit
          validate:(BOOL)validate
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject
{
  NSDictionary *props = CookieManagerPropsFromSpecCookie(cookie);
  [self handleSetWithUrlString:url
                         props:props
                      useWebKit:useWebKit
                        validate:validate
                         resolve:resolve
                          reject:reject];
}

- (void)setFromResponse:(NSString *)url
                 cookie:(NSString *)cookie
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject
{
  [self handleSetFromResponse:url cookie:cookie resolve:resolve reject:reject];
}

- (void)getFromResponse:(NSString *)url
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject
{
  [self handleGetFromResponse:url resolve:resolve reject:reject];
}

- (void)getCookies:(NSString *)url
         useWebKit:(NSNumber *)useWebKit
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  [self handleGet:url useWebKit:useWebKit resolve:resolve reject:reject];
}

- (void)getAsArray:(NSString *)url
         useWebKit:(NSNumber *)useWebKit
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  [self handleGetAsArray:url useWebKit:useWebKit resolve:resolve reject:reject];
}

- (void)getCookieHeader:(NSString *)url
              useWebKit:(NSNumber *)useWebKit
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject
{
  [self handleGetCookieHeader:url useWebKit:useWebKit resolve:resolve reject:reject];
}

- (void)clearAll:(NSNumber *)useWebKit
         resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
{
  [self handleClearAll:useWebKit resolve:resolve reject:reject];
}

- (void)clearAllStores:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [self handleClearAllStores:resolve reject:reject];
}

- (void)clearByName:(NSString *)url
               name:(NSString *)name
          useWebKit:(NSNumber *)useWebKit
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject
{
  [self handleClearByName:url name:name useWebKit:useWebKit resolve:resolve reject:reject];
}

- (void)getAll:(NSNumber *)useWebKit
       resolve:(RCTPromiseResolveBlock)resolve
        reject:(RCTPromiseRejectBlock)reject
{
  [self handleGetAll:useWebKit resolve:resolve reject:reject];
}

- (void)getAllAsArray:(NSNumber *)useWebKit
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject
{
  [self handleGetAllAsArray:useWebKit resolve:resolve reject:reject];
}

- (void)flush:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [self handleFlushWithResolve:resolve reject:reject];
}

- (void)removeSessionCookies:(BOOL)iosClearFoundation
           iosClearWebKit:(BOOL)iosClearWebKit
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject
{
  [self handleRemoveSessionCookies:iosClearFoundation
                        clearWebKit:iosClearWebKit
                            resolve:resolve
                             reject:reject];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeCookieManagerSpecJSI>(params);
}

@end
