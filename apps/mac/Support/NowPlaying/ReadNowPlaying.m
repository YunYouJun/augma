// Local media-session bridge. Observation is read-only; explicit transport
// requests are restricted to the current NetEase session. No volume changes.
// System-host technique: https://github.com/ungive/mediaremote-adapter
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <signal.h>
#import <unistd.h>
#import <CommonCrypto/CommonDigest.h>

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

static NSString *bundleIdentifier(id client) {
  NSString *identifier = nil;
  if ([client respondsToSelector:NSSelectorFromString(@"bundleIdentifier")]) identifier = [client valueForKey:@"bundleIdentifier"];
  if (![identifier isEqualToString:@"com.netease.163music"] && [client respondsToSelector:NSSelectorFromString(@"parentApplicationBundleIdentifier")]) {
    identifier = [client valueForKey:@"parentApplicationBundleIdentifier"];
  }
  return identifier;
}

static BOOL supportsSeek(CFArrayRef commands) {
  for (id item in (__bridge NSArray *)commands) {
    if ([item respondsToSelector:NSSelectorFromString(@"command")] &&
        [item respondsToSelector:NSSelectorFromString(@"isEnabled")] &&
        [[item valueForKey:@"command"] unsignedIntValue] == 24 && [[item valueForKey:@"enabled"] boolValue]) return YES;
  }
  return NO;
}

static NSString *trackIdentifier(void *framework, NSDictionary *metadata) {
  // NetEase regenerates ContentItemIdentifier when pausing or seeking. Derive a
  // stable song identity from its metadata instead of treating that session UUID as a song ID.
  NSMutableArray *identity = [NSMutableArray array];
  for (NSString *suffix in @[@"Title", @"Artist", @"Album"]) {
    id value = field(framework, metadata, suffix);
    if (value && (![value isKindOfClass:NSString.class] || [value length] > 4096)) return nil;
    [identity addObject:value ?: @""];
  }
  id duration = field(framework, metadata, @"Duration");
  if (![duration isKindOfClass:NSNumber.class] || !isfinite([duration doubleValue]) || [duration doubleValue] <= 0) return nil;
  [identity addObject:duration];
  NSData *data = [NSJSONSerialization dataWithJSONObject:identity options:0 error:NULL];
  if (!data) return nil;
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *value = [NSMutableString string];
  for (NSUInteger index = 0; index < sizeof(digest); index++) [value appendFormat:@"%02x", digest[index]];
  return value;
}

// Signature and command IDs: WebKit Source/WebCore/PAL/pal/spi/mac/MediaRemoteSPI.h.
// Never fall back to a global media-key event or launch a player implicitly.
void augma_send_playback_command(void) {
  @autoreleasepool {
    const char *mode = getenv("AUGMA_NOW_PLAYING_COMMAND");
    if (!mode) exit(2);
    uint32_t command;
    if (strcmp(mode, "play") == 0) command = 0;
    else if (strcmp(mode, "pause") == 0) command = 1;
    else if (strcmp(mode, "next") == 0) command = 4;
    else if (strcmp(mode, "previous") == 0) command = 5;
    else if (strcmp(mode, "seek") == 0) command = 24;
    else exit(2);
    void *framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    void (*getClient)(dispatch_queue_t, void (^)(id)) = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingClient") : NULL;
    void (*getInfo)(dispatch_queue_t, void (^)(NSDictionary *)) = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingInfo") : NULL;
    void *(*origin)(void) = framework ? dlsym(framework, "MRMediaRemoteGetLocalOrigin") : NULL;
    void (*getCommands)(void *, dispatch_queue_t, void (^)(CFArrayRef)) = framework ? dlsym(framework, "MRMediaRemoteGetSupportedCommandsForOrigin") : NULL;
    Boolean (*sendCommand)(uint32_t, CFDictionaryRef, void *, CFStringRef, uint32_t, dispatch_queue_t,
                          void (^)(uint32_t, CFArrayRef)) = framework ? dlsym(framework, "MRMediaRemoteSendCommandToApp") : NULL;
    if (!getClient || !sendCommand) exit(2);
    dispatch_queue_t callbacks = dispatch_queue_create("cn.yunyoujun.augma.playback", DISPATCH_QUEUE_SERIAL);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), callbacks, ^{ exit(3); });
    getClient(callbacks, ^(id client) {
      if (![bundleIdentifier(client) isEqualToString:@"com.netease.163music"]) exit(4);
      NSMutableDictionary *options = [@{@"kMRMediaRemoteOptionDisableImplicitAppLaunchBehaviors": @YES} mutableCopy];
      void (^send)(void) = ^{
        Boolean accepted = sendCommand(command, (__bridge CFDictionaryRef)options, NULL, CFSTR("com.netease.163music"), 0, callbacks,
        ^(uint32_t error, CFArrayRef statuses) {
          if (error) exit(5);
          for (id status in (__bridge NSArray *)statuses) {
            if (![status isKindOfClass:NSNumber.class] || [status unsignedIntValue] != 0) exit(5);
          }
          exit(0);
        });
        if (!accepted) exit(5);
      };
      if (command != 24) { send(); return; }
      if (!getInfo || !origin || !getCommands) exit(2);
      const char *rawPosition = getenv("AUGMA_NOW_PLAYING_POSITION");
      const char *rawIdentifier = getenv("AUGMA_NOW_PLAYING_CONTENT_IDENTIFIER");
      if (!rawPosition || !rawIdentifier) exit(2);
      char *end = NULL;
      double position = strtod(rawPosition, &end);
      NSString *expectedIdentifier = [NSString stringWithUTF8String:rawIdentifier];
      if (!end || *end || !isfinite(position) || position < 0 || position > 604800 ||
          !expectedIdentifier.length || strlen(rawIdentifier) > 4096) exit(2);
      __block double targetPosition = position;
      // Recheck the current item and capability immediately before submitting a seek.
      // A drag that started on another song must never seek the new song.
      dispatch_group_t group = dispatch_group_create();
      dispatch_group_enter(group);
      getInfo(callbacks, ^(NSDictionary *metadata) {
        id identifier = trackIdentifier(framework, metadata);
        id duration = field(framework, metadata, @"Duration");
        if (![identifier isKindOfClass:NSString.class] || ![identifier isEqualToString:expectedIdentifier] ||
            ![duration isKindOfClass:NSNumber.class] || !isfinite([duration doubleValue]) ||
            [duration doubleValue] <= 0 || [duration doubleValue] > 604800 || position > [duration doubleValue] + 0.001) exit(4);
        targetPosition = MIN(position, [duration doubleValue]);
        dispatch_group_leave(group);
      });
      dispatch_group_enter(group);
      getCommands(origin(), callbacks, ^(CFArrayRef commands) {
        if (!supportsSeek(commands)) exit(4);
        dispatch_group_leave(group);
      });
      dispatch_group_notify(group, callbacks, ^{
        CFStringRef *key = dlsym(framework, "kMRMediaRemoteOptionPlaybackPosition");
        options[key ? (__bridge NSString *)*key : @"kMRMediaRemoteOptionPlaybackPosition"] = @(targetPosition);
        send();
      });
    });
    dispatch_main();
  }
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
    void *(*origin)(void) = framework ? dlsym(framework, "MRMediaRemoteGetLocalOrigin") : NULL;
    void (*getCommands)(void *, dispatch_queue_t, void (^)(CFArrayRef)) = framework ? dlsym(framework, "MRMediaRemoteGetSupportedCommandsForOrigin") : NULL;
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
          NSString *identifier = bundleIdentifier(client);
          if (identifier) result[@"bundleIdentifier"] = identifier;
          dispatch_group_leave(group);
        });
        dispatch_group_enter(group);
        getPlaying(callbacks, ^(BOOL playing) { result[@"playing"] = @(playing); dispatch_group_leave(group); });
        if (origin && getCommands) {
          dispatch_group_enter(group);
          getCommands(origin(), callbacks, ^(CFArrayRef commands) {
            result[@"canSeek"] = @(supportsSeek(commands));
            dispatch_group_leave(group);
          });
        }
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
          NSString *identifier = trackIdentifier(framework, metadata);
          if (identifier) result[@"trackIdentifier"] = identifier;
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
