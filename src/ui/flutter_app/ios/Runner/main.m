#import <FlutterMacOS/FlutterMacOS.h>
#import "AppDelegate.h"

int main(int argc, char* argv[]) {
  @autoreleasepool {
    NSApplication* app = [NSApplication sharedApplication];
    AppDelegate* delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];
    [NSApp run];
  }
}
