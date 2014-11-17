//  FSGenericObjectInspector.h Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import <AppKit/AppKit.h>

@class FSObjectInspectorViewModelItem;

@interface FSDetailedObjectInspector : NSObject <NSWindowDelegate>
@property (weak,nonatomic) id inspectedObject;
@property (readonly,nonatomic) NSWindow *window;
+ (FSDetailedObjectInspector *)detailedObjectInspectorWithObject:(id)object rootViewModelItem:(FSObjectInspectorViewModelItem*)root;
- (FSDetailedObjectInspector *)initWithObject:(id)object rootViewModelItem:(FSObjectInspectorViewModelItem*)root;
- (void)updateAction:(id)sender;

- (void)windowWillClose:(NSNotification *)aNotification;

@end
