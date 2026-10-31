// menubar.m is the AppKit side of the status item: an NSStatusItem whose menu
// is rebuilt from Go every time it opens, so displays that come and go are
// always shown correctly.

#import <Cocoa/Cocoa.h>

#include "menubar.h"
#include "_cgo_export.h"

@interface MBController : NSObject <NSMenuDelegate, NSApplicationDelegate>
@end

static NSStatusItem *statusItem;
static NSMenu *displayMenu;
static MBController *controller;

// A four-point star with thin, curved-in arms.
static NSBezierPath *sparkle(NSPoint c, CGFloat r) {
    CGFloat k = r * 0.18;
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p moveToPoint:NSMakePoint(c.x, c.y + r)];
    NSPoint tips[] = {{c.x + r, c.y}, {c.x, c.y - r}, {c.x - r, c.y}, {c.x, c.y + r}};
    CGFloat dx[] = {k, k, -k, -k}, dy[] = {k, -k, -k, k};
    for (int i = 0; i < 4; i++) {
        NSPoint cp = NSMakePoint(c.x + dx[i], c.y + dy[i]);
        [p curveToPoint:tips[i] controlPoint1:cp controlPoint2:cp];
    }
    [p closePath];
    return p;
}

// The menu bar icon: a display with a small sparkle at its top right. Drawn by
// hand rather than from system symbols so every straight edge lands on a whole
// point, which keeps it sharp on 1x screens. Points are in a 20x18 box with y
// going up.
static NSImage *menuIcon(void) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(20, 18) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [NSColor.blackColor set];
        // Screen: a 1pt line just inside the edge, by clipping to the shape
        // and stroking 2pt.
        NSBezierPath *screen = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1, 4, 13, 10) xRadius:2 yRadius:2];
        [NSGraphicsContext saveGraphicsState];
        [screen addClip];
        screen.lineWidth = 2;
        [screen stroke];
        [NSGraphicsContext restoreGraphicsState];
        NSRectFill(NSMakeRect(6, 2, 3, 2)); // neck
        NSRectFill(NSMakeRect(4, 1, 7, 1)); // foot
        [sparkle(NSMakePoint(16.5, 14.5), 3.5) fill];
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = @"Displays";
    return image;
}

@implementation MBController

// The status item is created here rather than before [NSApp run]: AppKit can
// quietly drop one created before the app has finished launching.
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = menuIcon();
    statusItem.button.image = icon;
    statusItem.visible = YES;

    displayMenu = [[NSMenu alloc] init];
    // Keep AppKit from second-guessing the enabled state set in Go.
    displayMenu.autoenablesItems = NO;
    displayMenu.delegate = self;
    statusItem.menu = displayMenu;

    // A menu bar app has no terminal to complain to, so say what happened.
    fprintf(stderr, "menubar: statusItem=%d button=%d icon=%d visible=%d screens=%lu\n",
        statusItem != nil, statusItem.button != nil, icon != nil, statusItem.visible,
        (unsigned long)NSScreen.screens.count);
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    menubarRebuild(); // Go calls mb_add_item for each display

    [menu addItem:[NSMenuItem separatorItem]];
    menubarLogin(); // Go calls mb_add_login
    [menu addItem:[NSMenuItem separatorItem]];
    // Greyed out, with no action. Builds without an app bundle (brew services)
    // have no version to show.
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *title = version ? [NSString stringWithFormat:@"MagiciLabs DisplayCtl %@", version] : @"MagiciLabs DisplayCtl";
    NSMenuItem *about = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    about.enabled = NO;
    [menu addItem:about];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                  action:@selector(quit:)
                                           keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
}

- (void)toggle:(NSMenuItem *)sender {
    menubarToggle((uint32_t)sender.tag);
}

- (void)toggleLogin:(NSMenuItem *)sender {
    menubarLoginToggle();
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

@end

void mb_run(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        // Accessory: a menu bar app, with no icon in the Dock.
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        controller = [MBController new];
        NSApp.delegate = controller;
        [NSApp run];
    }
}

void mb_add_item(const char *title, uint32_t id, bool on, bool enabled) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@(title)
                                                  action:@selector(toggle:)
                                           keyEquivalent:@""];
    item.target = controller;
    item.tag = (NSInteger)id;
    item.state = on ? NSControlStateValueOn : NSControlStateValueOff;
    item.enabled = enabled;
    [displayMenu addItem:item];
}

void mb_add_login(const char *title, bool on, bool enabled) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@(title)
                                                  action:@selector(toggleLogin:)
                                           keyEquivalent:@""];
    item.target = controller;
    item.state = on ? NSControlStateValueOn : NSControlStateValueOff;
    item.enabled = enabled;
    [displayMenu addItem:item];
}
