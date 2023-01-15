#import "AppDelegate.h"
#import "MacOsPluginRegistrant.h"

@implementation AppDelegate

- (id)init {

    self = [super init];

    if (self) {
        engine = [[MillEngine alloc] init];
    }

    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    [GeneratedPluginRegistrant registerWithRegistry:self];

    [self setupMethodChannel];
}

- (void) setupMethodChannel {
    FlutterViewController* controller = (FlutterViewController*) NSApp.mainWindow.contentViewController;

    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"com.calcitem.sanmill/engine"
                                     binaryMessenger:controller.engine.binaryMessenger];

    __weak MillEngine* weakEngine = engine;

    [channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
        if ([@"startup" isEqualToString:call.method]) {
            result(@([weakEngine startup: controller]));
        }
        else if ([@"send" isEqualToString:call.method]) {
          result(@([weakEngine send: call.arguments]));
        }
        else if ([@"read" isEqualToString:call.method]) {
            result([weakEngine read]);
        }
        else if ([@"shutdown" isEqualToString:call.method]) {
            result(@([weakEngine shutdown]));
        }
        else if ([@"isReady" isEqualToString:call.method]) {
            result(@([weakEngine isReady]));
        }
        else if ([@"isThinking" isEqualToString:call.method]) {
            result(@([weakEngine isThinking]));
        }
        else {
            result(FlutterMethodNotImplemented);
        }
    }];
}

@end
