//
//  LCMenuIconView.m
//  Caffeine
//
//

#import "LCMenuIconView.h"


@implementation LCMenuIconView
@synthesize isActive, statusItem, menu;

- (id)initWithFrame:(NSRect)r {
    self = [super initWithFrame:r];
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:30] retain];
    [statusItem setVisible:YES];
    [statusItem setView:self];
    [statusItem setEnabled:YES];
    if (@available(macOS 10.14, *)) {
        [statusItem addObserver:self forKeyPath:@"view.effectiveAppearance" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    }else{
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"AppleInterfaceStyle" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    }
    
    return self;
}

- (void)drawRect:(NSRect)r {
    NSImage *i = isActive ? activeImage : inactiveImage;
    if(menuIsShown) i = isActive ? highlightActiveImage : highlightImage;
    NSRect f = [self bounds];
    NSPoint p = NSMakePoint(f.size.width/2 - [i size].width/2, f.size.height/2 - [i size].height/2 + 1);
    
    [statusItem drawStatusBarBackgroundInRect:r withHighlight:menuIsShown];
    [i drawAtPoint:p fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    [self setNeedsDisplay];
}

- (void)setActive:(BOOL)flag {
    isActive = flag;
    [self setNeedsDisplay:YES];
}

- (void)rightMouseDown:(NSEvent*)e {
    menuIsShown = YES;
    [self setNeedsDisplay:YES];
    [statusItem popUpStatusItemMenu:menu];
    menuIsShown = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)e {
    if([e modifierFlags] & (NSCommandKeyMask | NSControlKeyMask))
        return [self rightMouseDown:e];
    
    [NSApp sendAction:action to:target from:self];
}

- (void)mouseUp:(NSEvent *)theEvent {
    if([NSDate timeIntervalSinceReferenceDate] - lastMouseUp < 0.2) {
        [NSApp sendAction:@selector(showPreferences:) to:nil from:nil];
        lastMouseUp = 0;
    } else lastMouseUp = [NSDate timeIntervalSinceReferenceDate];
}

- (void)setAction:(SEL)a {
    action = a;
}

- (void)setTarget:(id)t {
    target = t;
}

# pragma mark - System/Menu Bar Theme Methods

- (void)setLightMode {
    activeImage = [NSImage imageNamed:@"active"];
    inactiveImage = [NSImage imageNamed:@"inactive"];
    
    // Big Sur does not invert icon color when highlighted in light appearance
    if (@available(macOS 10.16, *)) {
        highlightImage = [NSImage imageNamed:@"inactive"];
        highlightActiveImage = [NSImage imageNamed:@"active"];
    }else{
        highlightImage = [NSImage imageNamed:@"highlighted"];
        highlightActiveImage = [NSImage imageNamed:@"highlightactive"];
    }
    [self setNeedsDisplay];
}

- (void)setDarkMode {
    activeImage = [NSImage imageNamed:@"highlightactive"];
    inactiveImage = [NSImage imageNamed:@"highlighted"];
    highlightImage = [NSImage imageNamed:@"highlighted"];
    highlightActiveImage = [NSImage imageNamed:@"highlightactive"];
    [self setNeedsDisplay];
}

# pragma mark - System/Menu Bar Theme Event Handlers

- (void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context
{
    if (@available(macOS 10.14, *)) {
        if([keyPath isEqualToString:@"view.effectiveAppearance"]){
            NSStatusItem *item = object;
            NSAppearance *appearance = item.view.effectiveAppearance;
            NSString *appearanceName = (NSString*)(appearance.name);
            if([[appearanceName lowercaseString] containsString:@"dark"]){
                [self setDarkMode];
            }else{
                [self setLightMode];
            }
        }
    }else{
        if([[change objectForKey:@"new"] isNotEqualTo:[NSNull null]] && [[change objectForKey:@"new"] isEqualToString:@"Dark"]) {
            [self setDarkMode];
        }else{
            [self setLightMode];
        }
    }
    [self setNeedsDisplay];
}

@end
