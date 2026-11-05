// Read-only bridge to the local media session. No account files, networking,
// playback commands, seeking or volume setters are exposed here.
// System-host technique: https://github.com/ungive/mediaremote-adapter
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <signal.h>
#import <unistd.h>

static void emit(NSDictionary *payload) {
  NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:NULL];
  if (!json) json = [@"{\"error\":\"invalidMetadata\"}" dataUsingEncoding:NSUTF8StringEncoding];
  fwrite(json.bytes, 1, json.length, stdout);
  fputc('\n', stdout);
  fflush(stdout);
}

static id field(void *framework, NSDictionary *metadata, NSString *suffix) {
  NSString *name = [@"kMRMediaRemoteNowPlayingInfo" stringByAppendingString:suffix];
  CFStringRef *symbol = dlsym(framework, name.UTF8String);
  return metadata[symbol ? (__bridge NSString *)*symbol : name];
}

// Called from Perl's DynaLoader; this entry point never returns to its XSUB frame.
void augma_observe_now_playing(void) {
  @autoreleasepool {
    signal(SIGPIPE, SIG_DFL);
    BOOL once = getenv("AUGMA_NOW_PLAYING_ONCE") && strcmp(getenv("AUGMA_NOW_PLAYING_ONCE"), "1") == 0;
    void *framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    void (*getInfo)(dispatch_queue_t, void (^)(NSDictionary *)) = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingInfo") : NULL;
    void (*getClient)(dispatch_queue_t, void (^)(id)) = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingClient") : NULL;
    void (*getPlaying)(dispatch_queue_t, void (^)(BOOL)) = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") : NULL;
    if (!getInfo || !getClient || !getPlaying) { emit(@{@"error": @"unsupportedSystem"}); exit(2); }
    dispatch_queue_t callbacks = dispatch_queue_create("cn.yunyoujun.augma.now-playing.callbacks", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t reader = dispatch_queue_create("cn.yunyoujun.augma.now-playing.reader", DISPATCH_QUEUE_SERIAL);
    void (^sample)(void) = ^{
      @autoreleasepool {
        if (!once && getppid() == 1) exit(0);
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        getClient(callbacks, ^(id client) {
          NSString *identifier = nil;
          if ([client respondsToSelector:NSSelectorFromString(@"bundleIdentifier")]) identifier = [client valueForKey:@"bundleIdentifier"];
          if (![identifier isEqualToString:@"com.netease.163music"] && [client respondsToSelector:NSSelectorFromString(@"parentApplicationBundleIdentifier")]) {
            identifier = [client valueForKey:@"parentApplicationBundleIdentifier"];
          }
          if (identifier) result[@"bundleIdentifier"] = identifier;
          dispatch_group_leave(group);
        });
        dispatch_group_enter(group);
        getPlaying(callbacks, ^(BOOL playing) { result[@"playing"] = @(playing); dispatch_group_leave(group); });
        dispatch_group_enter(group);
        getInfo(callbacks, ^(NSDictionary *metadata) {
          NSDictionary *strings = @{@"Title": @"title", @"Artist": @"artist", @"Album": @"album", @"Lyrics": @"lyrics"};
          for (NSString *suffix in strings) {
            id value = field(framework, metadata, suffix);
            if ([value isKindOfClass:NSString.class] && [value length] <= 131072) result[strings[suffix]] = value;
          }
          NSDictionary *numbers = @{@"Duration": @"duration", @"ElapsedTime": @"elapsed", @"PlaybackRate": @"rate"};
          for (NSString *suffix in numbers) {
            id value = field(framework, metadata, suffix);
            if ([value isKindOfClass:NSNumber.class] && isfinite([value doubleValue])) result[numbers[suffix]] = value;
          }
          id timestamp = field(framework, metadata, @"Timestamp");
          if ([timestamp isKindOfClass:NSDate.class]) result[@"timestamp"] = @([timestamp timeIntervalSince1970]);
          id artwork = field(framework, metadata, @"ArtworkData");
          if ([artwork isKindOfClass:NSData.class] && [artwork length] <= 4194304) result[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
          dispatch_group_leave(group);
        });
        if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC))) {
          emit(@{@"error": @"timeout"});
          // Do not overlap snapshots or publish late callback results.
          exit(3);
        }
        if (![result[@"bundleIdentifier"] isEqualToString:@"com.netease.163music"]) {
          // Ignore other players entirely, including their titles and artwork.
          emit(@{});
        } else { emit(result); }
        if (once) exit(0);
      }
    };
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, reader);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC, 100 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, sample);
    dispatch_resume(timer);
    dispatch_main();
  }
}
