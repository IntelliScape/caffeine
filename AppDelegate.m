//
//  AppDelegate.m
//  Caffeine
//
//  Created by Tomas Franzén on 2006-05-20.
//  Copyright 2006 Lighthead Software. All rights reserved.
//

#import "AppDelegate.h"
#import <CoreServices/CoreServices.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation AppDelegate

# pragma mark - Initialization

- (id)init {
	[super init];
	timer = [[NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(timer:) userInfo:nil repeats:YES] retain];
	webBaseURL = @"https://www.intelliscapesolutions.com/apps/caffeine";
    
	// Workaround for a bug in Snow Leopard where Caffeine would prevent the computer from going to sleep when another account was active.
	userSessionIsActive = YES;
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(userSessionDidResignActive:) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(userSessionDidBecomeActive:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
	return self;
}

- (void)awakeFromNib {
    menuView = [[LCMenuIconView alloc] initWithFrame:NSZeroRect];
    [menuView setMenu:menu];
    [menuView setAction:@selector(toggleActive:)];
	
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
    [defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"SuppressLaunchMessage"];
    [defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"SendProblemReports"];
	[defaults registerDefaults:defaultValues];
    [defaults synchronize];
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"SuppressLaunchMessage"]) {
        [self showPreferences:nil];
    }
	
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"ActivateOnLaunch"]) {
		[self toggleActive:nil];
    }
}

# pragma mark - Activation & Deactivation Methods

- (void)activateWithTimeoutDuration:(NSTimeInterval)interval {
    if(![self checkForAccessibilityPermission]) {
        return;
    };
	if(timeoutTimer) [[timeoutTimer autorelease] invalidate];
	timeoutTimer = nil;
	if(interval > 0)
		timeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timeoutReached:) userInfo:nil repeats:NO] retain];
	isActive = YES;
	[menuView setActive:isActive];
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:interval ? interval : -1], @"duration", nil];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.intelliscapesolutions.caffeine.activation" object:nil userInfo:info];
    
    [self sendActivityAssertions];
}

- (void)activate {
	[self activateWithTimeoutDuration:0];	
}

- (void)deactivate {
	isActive = NO;
	if(timeoutTimer) [[timeoutTimer autorelease] invalidate];
	timeoutTimer = nil;
	[menuView setActive:isActive];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.intelliscapesolutions.caffeine.deactivation" object:nil userInfo:nil];
    
    if(previousActivityAssertion) {
        IOPMAssertionRelease(previousActivityAssertion);
        previousActivityAssertion = 0;
    }
    if(previousIdleAssertion) {
        IOPMAssertionRelease(previousIdleAssertion);
        previousIdleAssertion = 0;
    }
}

- (IBAction)activateWithTimeout:(id)sender {
	int minutes = [(NSMenuItem*)sender tag];
	int seconds = minutes*60;
	if(seconds == -60) seconds = 2;
	if(minutes)
		[self activateWithTimeoutDuration:seconds];
	else
		[self activate];
}

- (void)toggleActive:(id)sender {
	if(timeoutTimer) [[timeoutTimer autorelease] invalidate];
	timeoutTimer = nil;
	
	if(isActive) {
		[self deactivate];
	} else {
		int defaultMinutesDuration = [[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultDuration"];
		int seconds = defaultMinutesDuration*60;
		if(seconds == -60) seconds = 2;
		if(defaultMinutesDuration)
			[self activateWithTimeoutDuration:seconds];
		else
			[self activate];
	}
}

- (void)timeoutReached:(NSTimer*)timer {
	[self deactivate];
}

- (BOOL)isActive {
	return isActive;
}

# pragma mark - Core Functionality

- (void)sendActivityAssertions {
    CFStringRef assertionReason = CFSTR("Caffeine is Active");
    IOPMAssertionID activityAssertionID;
    IOReturn activityResult = IOPMAssertionDeclareUserActivity(assertionReason, kIOPMUserActiveLocal, &activityAssertionID);
    if(activityResult == kIOReturnSuccess) {
        if(previousActivityAssertion) {
            IOPMAssertionRelease(previousActivityAssertion);
        }
        previousActivityAssertion = activityAssertionID;
    }else{
        NSLog(@"Failed to create activity assertion");
    }
    
    IOPMAssertionID preventIdleAssertionID;
    IOReturn idleResult = IOPMAssertionCreateWithDescription(kIOPMAssertionTypePreventUserIdleDisplaySleep, assertionReason, NULL, NULL, NULL, 0, NULL, &preventIdleAssertionID );
    if(idleResult == kIOReturnSuccess) {
        if(previousIdleAssertion) {
            IOPMAssertionRelease(previousIdleAssertion);
        }
        previousIdleAssertion = preventIdleAssertionID;
    }else{
        NSLog(@"Failed to create idle assertion");
    }
}

- (void)timer:(NSTimer*)timer {
    if(isActive && ![self screensaverIsRunning] && userSessionIsActive) {
        [self sendActivityAssertions];
    }
}

- (void)userSessionDidResignActive:(NSNotification *)note {
    userSessionIsActive = NO;
}

- (void)userSessionDidBecomeActive:(NSNotification *)note {
    userSessionIsActive = YES;
}

- (BOOL)screensaverIsRunning {
    NSString *activeAppID = [[[NSWorkspace sharedWorkspace] activeApplication] objectForKey:@"NSApplicationBundleIdentifier"];
    NSArray *bundleIDs = [NSArray arrayWithObjects:@"com.apple.ScreenSaver.Engine", @"com.apple.loginwindow", nil];
    return activeAppID && [bundleIDs containsObject:activeAppID];
}

- (LSSharedFileListItemRef)applicationItemInList:(LSSharedFileListRef)list {
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	
	NSArray *items = (id)LSSharedFileListCopySnapshot(list, NULL);
	for(id item in items) {    
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		CFURLRef URL = NULL;
		if(LSSharedFileListItemResolve(itemRef, 0, &URL, NULL)) continue;
		
		BOOL matches = [[(NSURL*)URL path] isEqual:appPath];
		CFRelease(URL);
		if(matches)
			return itemRef;
	}
	CFRelease(items);
	return NULL;
}

- (BOOL)startsAtLogin {
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	LSSharedFileListItemRef item = [self applicationItemInList:loginItems];
	BOOL starts = (item != NULL);
	if(item) CFRelease(item);
	CFRelease(loginItems);
	return starts;
}

- (void)setStartsAtLogin:(BOOL)start {
	if(start == [self startsAtLogin]) return;
	
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	if(start) {
		NSString *appPath = [[NSBundle mainBundle] bundlePath];
		CFURLRef appURL = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)appPath, kCFURLPOSIXPathStyle, YES);
		LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, appURL, NULL, NULL);
		CFRelease(appURL);
	}else{
		LSSharedFileListItemRef item = [self applicationItemInList:loginItems];
		if(item) {
			LSSharedFileListItemRemove(loginItems, item);
			CFRelease(item);
		}
			
	}
	
	CFRelease(loginItems);
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	[self showPreferences:nil];
	return NO;
}

- (void)menuNeedsUpdate:(NSMenu *)m {
	if(isActive) {
		[infoMenuItem setHidden:NO];
		[infoSeparatorItem setHidden:NO];
		if(timeoutTimer) {
			NSTimeInterval left = [[timeoutTimer fireDate] timeIntervalSinceNow];
			if(left >= 3600)
				[infoMenuItem setTitle:[NSString stringWithFormat:@"%02d:%02d left", (int)(left/3600), (int)(((int)left%3600)/60)]];
			else if(left >= 60)
				[infoMenuItem setTitle:[NSString stringWithFormat:@"%d minutes left", (int)(left/60)]];
			else
				[infoMenuItem setTitle:[NSString stringWithFormat:@"%d seconds left", (int)left]];
		}else{
			[infoMenuItem setTitle:@"Caffeine is active"];
		}
	}else{
		[infoMenuItem setHidden:YES];
		[infoSeparatorItem setHidden:YES];
	}
}

# pragma mark - Application Lifecycle Events

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
    [self checkForAccessibilityPermission];
}

# pragma mark - Accessibility Permissions

-(BOOL)checkForAccessibilityPermission {
    // Prompt for accessibility permissions on macOS Mojave and later.
    if (@available(macOS 10.14, *)) {
        NSDictionary *options = @{(id)kAXTrustedCheckOptionPrompt: @NO};
        BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
        if(!accessibilityEnabled) {
            [self showAccessibilityPrompt:nil];
            return NO;
        }else{
            if([accessibilityPermissionWindow isVisible]) {
                [accessibilityPermissionWindow close];
            }
        }
    }
    return YES;
}

-(IBAction)showAccessibilityPrompt:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [accessibilityPermissionWindow center];
    [accessibilityPermissionWindow setIsVisible:YES];
    [accessibilityPermissionWindow makeKeyAndOrderFront:sender];
}

-(IBAction)launchSystemPreferences:(id)sender {
    NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

# pragma mark - Launch & About Windows

- (IBAction)showAbout:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:self];
}

- (IBAction)showPreferences:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [firstTimeWindow setBackgroundColor:[NSColor windowBackgroundColor]];
    [firstTimeWindow center];
    [firstTimeWindow makeKeyAndOrderFront:sender];
}

# pragma mark - Help & Feedback Window Utility Methods

-(IBAction)launchHelpCenter:(id)sender {
    [helpCenterWindow center];
    [helpCenterWindow setIsVisible:YES];
    [helpCenterWindow makeKeyAndOrderFront:nil];
}

-(IBAction)launchSupport:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:
     [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", webBaseURL, @"/support"]]];
}

-(IBAction)launchSupportAccessibility:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:
     [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", webBaseURL, @"/support/permissions"]]];
}

-(IBAction)launchFeedback:(id)sender {
    NSURL *nsurl=[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", webBaseURL, @"/feedback"]];
    if (NSClassFromString(@"WKWebView")) {
        NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
        WKWebView *feedbackWebView = [[WKWebView alloc] initWithFrame:[[feedbackWindow contentView] frame]];
        [feedbackWebView loadRequest:nsrequest];
        [[feedbackWindow contentView] addSubview:feedbackWebView];
        [feedbackWindow center];
        [feedbackWindow setIsVisible:YES];
        [feedbackWindow makeKeyAndOrderFront:nil];
    }else{
        [[NSWorkspace sharedWorkspace] openURL:nsurl];
    }
}

-(IBAction)launchDonate:(id)sender {
    NSURL *nsurl=[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", webBaseURL, @"/donate"]];
    if (NSClassFromString(@"WKWebView")) {
        NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
        WKWebView *donateWebView = [[WKWebView alloc] initWithFrame:[[donateWindow contentView] frame]];
        [donateWebView loadRequest:nsrequest];
        [[donateWindow contentView] addSubview:donateWebView];
        [donateWindow center];
        [donateWindow setIsVisible:YES];
        [donateWindow makeKeyAndOrderFront:nil];
    }else{
        [[NSWorkspace sharedWorkspace] openURL:nsurl];
    }
}

-(IBAction)showProblemReportInfoPopoverButton:(id)sender {
    [problemReportInfoPopover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
}

# pragma mark - Maintenance & Memory Management

- (void)dealloc {
    [timer invalidate];
    [timer release];
    [menuView release];
    [timeoutTimer release];
    [super dealloc];
}

@end
