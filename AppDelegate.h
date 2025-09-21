//
//  AppDelegate.h
//  Caffeine
//
//  Created by Tomas Franzén on 2006-05-20.
//  Copyright 2006 Lighthead Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "LCMenuIconView.h"
#import "ISToggleSwitch.h"

// Workaround for bug in 64-bit SDK
#ifndef __POWER__
enum {
	OverallAct                    = 0,    /* Delays idle sleep by small amount                 */
	UsrActivity                   = 1,    /* Delays idle sleep and dimming by timeout time          */
	NetActivity                   = 2,    /* Delays idle sleep and power cycling by small amount         */
	HDActivity                    = 3,    /* Delays hard drive spindown and idle sleep by small amount  */
	IdleActivity                  = 4     /* Delays idle sleep by timeout time                 */
};

extern OSErr UpdateSystemActivity(UInt8 activity);
#endif



@interface AppDelegate : NSObject {
	BOOL isActive;
	BOOL userSessionIsActive;
	NSTimer *timer;
	NSTimer *timeoutTimer;
	
	LCMenuIconView *menuView;
	IBOutlet NSMenu *menu;
	IBOutlet NSWindow *firstTimeWindow;
	IBOutlet NSMenuItem *infoMenuItem;
	IBOutlet NSMenuItem *infoSeparatorItem;
    
    IBOutlet NSWindow *accessibilityPermissionWindow;
    IBOutlet NSWindow *helpCenterWindow;
    IBOutlet NSWindow *feedbackWindow;
    IBOutlet NSWindow *donateWindow;
    
    IBOutlet ISToggleSwitch *problemReportSwitch;
    IBOutlet NSPopover *problemReportInfoPopover;
    IBOutlet NSButton *problemReportInfoPopoverButton;
    
    NSString *webBaseURL;
    IOPMAssertionID previousActivityAssertion;
    IOPMAssertionID previousIdleAssertion;
}

- (IBAction)showAbout:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)activateWithTimeout:(id)sender;

- (void)activateWithTimeoutDuration:(NSTimeInterval)interval;
- (void)activate;
- (void)deactivate;
- (BOOL)isActive;
- (void)toggleActive:(id)sender;

- (void)userSessionDidResignActive:(NSNotification *)note;
- (void)userSessionDidBecomeActive:(NSNotification *)note;

-(IBAction)showAccessibilityPrompt:(id)sender;
-(IBAction)launchSupportAccessibility:(id)sender;
-(IBAction)launchHelpCenter:(id)sender;
-(IBAction)launchSupport:(id)sender;
-(IBAction)launchFeedback:(id)sender;
-(IBAction)launchDonate:(id)sender;
-(IBAction)launchSystemPreferences:(id)sender;
-(IBAction)showProblemReportInfoPopoverButton:(id)sender;

@end
