//
//  LCMenuIconView.h
//  Caffeine
//
//  Created by Tomas Franzén on 2009-09-04.
//  Copyright 2009 Lighthead Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LCMenuIconView : NSControl {
    BOOL isActive;
    BOOL menuIsShown;
    
    IBOutlet NSMenu *menu;
    NSStatusItem *statusItem;
    
    NSImage *activeImage;
    NSImage *inactiveImage;
    
    NSImage *highlightImage;
    NSImage *highlightActiveImage;
    
    NSTimeInterval lastMouseUp;
    
    SEL action;
    id target;
}

@property(nonatomic, setter = setActive:) BOOL isActive;
@property(retain) NSStatusItem *statusItem;
@property(retain) NSMenu *menu;
@end
