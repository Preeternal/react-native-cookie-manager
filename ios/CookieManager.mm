#import "CookieManager.h"

// Universal include for framework/static builds
#if __has_include(<CookieManager/CookieManager-Swift.h>)
#import <CookieManager/CookieManager-Swift.h>
#elif __has_include("CookieManager-Swift.h")
#import "CookieManager-Swift.h"
#else
#warning "CookieManager-Swift.h not found at build time"
@class CookieManagerImpl;
#import "CookieManager-Swift.h"
#endif

@interface CookieManager ()
@property(nonatomic, strong) CookieManagerImpl *impl;
@end

@implementation CookieManager {
  CookieManagerImpl *_impl;
}

RCT_EXPORT_MODULE();

- (instancetype)init
{
  if (self = [super init]) {
    _impl = [CookieManagerImpl new];
  }
  return self;
}

#pragma mark - Shared helpers

- (void)handleSetWithUrlString:(NSString *)url
                        props:(NSDictionary *)props
                     useWebKit:(NSNumber *)useWebKit
                       resolve:(RCTPromiseResolveBlock)resolve
                        reject:(RCTPromiseRejectBlock)reject
{
  [_impl set:url
       cookie:props
     useWebKit:[useWebKit boolValue]
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

- (void)handleClearAll:(NSNumber *)useWebKit
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject
{
  [_impl clearAll:[useWebKit boolValue] resolve:resolve reject:reject];
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

- (void)handleFlushWithResolve:(RCTPromiseResolveBlock)resolve
                        reject:(RCTPromiseRejectBlock)reject
{
  [_impl flushWithResolve:resolve reject:reject];
}

- (void)handleRemoveSessionCookies:(RCTPromiseResolveBlock)resolve
                            reject:(RCTPromiseRejectBlock)reject
{
  [_impl removeSessionCookiesWithResolve:resolve reject:reject];
}

#if RCT_NEW_ARCH_ENABLED

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
  return dict;
}

- (void)setCookie:(NSString *)url
           cookie:(JS::NativeCookieManager::Cookie &)cookie
        useWebKit:(NSNumber *)useWebKit
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject
{
  NSDictionary *props = CookieManagerPropsFromSpecCookie(cookie);
  [self handleSetWithUrlString:url props:props useWebKit:useWebKit resolve:resolve reject:reject];
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

- (void)clearAll:(NSNumber *)useWebKit
         resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
{
  [self handleClearAll:useWebKit resolve:resolve reject:reject];
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

- (void)flush:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [self handleFlushWithResolve:resolve reject:reject];
}

- (void)removeSessionCookies:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [self handleRemoveSessionCookies:resolve reject:reject];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeCookieManagerSpecJSI>(params);
}

#else

RCT_EXPORT_METHOD(setCookie
                  : (NSString *)url cookie
                  : (NSDictionary *)props useWebKit
                  : (BOOL)useWebKit resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleSetWithUrlString:url
                         props:props
                      useWebKit:@(useWebKit)
                        resolve:resolve
                         reject:reject];
}

RCT_EXPORT_METHOD(setFromResponse
                  : (NSString *)url cookie
                  : (NSString *)cookie resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleSetFromResponse:url cookie:cookie resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getFromResponse
                  : (NSString *)url resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleGetFromResponse:url resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getCookies
                  : (NSString *)url useWebKit
                  : (BOOL)useWebKit resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleGet:url useWebKit:@(useWebKit) resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(clearAll
                  : (BOOL)useWebKit resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleClearAll:@(useWebKit) resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(clearByName
                  : (NSString *)url name
                  : (NSString *)name useWebKit
                  : (BOOL)useWebKit resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleClearByName:url name:name useWebKit:@(useWebKit) resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getAll
                  : (BOOL)useWebKit resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleGetAll:@(useWebKit) resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(flush
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleFlushWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(removeSessionCookies
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)
{
  [self handleRemoveSessionCookies:resolve reject:reject];
}

#endif

@end
