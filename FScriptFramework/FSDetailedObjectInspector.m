//  FSDetailedObjectInspector.m Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import "FSDetailedObjectInspector.h"
#import "FSMiscTools.h"
#import "FSObjectInspectorViewModelItem.h"
#import "FSObjectInspectorViewController.h"
#import "FSUtils.h"

static NSPoint sTopLeftPoint = { 0, 0 }; // Used for cascading windows.
static BOOL sIsFirstWindow = YES;
@interface FSDetailedObjectInspector ()
@property (strong,readwrite,nonatomic) NSWindow *window;
@property (strong,nonatomic) FSObjectInspectorViewController *viewController;
@property (strong,nonatomic) FSObjectInspectorViewModelItem *rootViewModelItem;
@end

@implementation FSDetailedObjectInspector {
}

+ (FSDetailedObjectInspector*)detailedObjectInspectorWithObject:(id)object rootViewModelItem:(FSObjectInspectorViewModelItem*)root
{
        return [[self alloc] initWithObject:object rootViewModelItem:root];
}

- (FSDetailedObjectInspector *)initWithObject:(id)object rootViewModelItem:(FSObjectInspectorViewModelItem*)root
{
        if ((self = [super init])) {
                self.rootViewModelItem = root;
                NSPanel* panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(100.0, 100.0, 500.0, 300.0)
                                                            styleMask:(NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask)
                                                              backing:NSBackingStoreBuffered
                                                                defer:NO];
                panel.delegate = self;
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10
                panel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
#endif
                self.window = panel;
                _inspectedObject = object;
                FSObjectInspectorViewController *objectInspectorViewController = [[FSObjectInspectorViewController alloc] initWithNibName:@"FSObjectInspectorViewController" bundle:nil];
                objectInspectorViewController.rootViewModelItem = root;
                self.viewController = objectInspectorViewController;
                panel.contentView = objectInspectorViewController.view;
                NSSize desiredSize = self.viewController.desiredSize;
                [panel setFrame:[panel frameRectForContentRect:rectWithSize(desiredSize)] display:YES];
                [self updateAction:nil];
                sTopLeftPoint = [self.window cascadeTopLeftFromPoint:sTopLeftPoint];
                if (sIsFirstWindow) {
                        sIsFirstWindow = NO;
                        sTopLeftPoint = [self.window cascadeTopLeftFromPoint:sTopLeftPoint];
                }
                [self.window makeKeyAndOrderFront:nil];
                return self;
        }
        return nil;
}


- (void)updateAction:(id)sender
{
        [self.window setTitle:[NSString stringWithFormat:@"Inspecting %@ at address %p", descriptionForFSMessage(self.inspectedObject), self.inspectedObject]];
}

/////////////////// Window delegate callbacks

- (void)windowWillClose:(NSNotification*)aNotification
{
}


@end
