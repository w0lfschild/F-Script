//
//  FSObjectInspectorViewController.h
//  FScript
//
//  Created by Anthony Dervish on 17/11/2014.
//
//

#import <Cocoa/Cocoa.h>

@class FSObjectInspectorViewModelItem;
@class FSInterpreter;
@class FSDetailedObjectInspector;

@interface FSObjectInspectorViewController : NSViewController <NSOutlineViewDelegate, NSPopoverDelegate>
@property (assign) IBOutlet NSOutlineView *outlineView;
@property (weak,nonatomic) FSDetailedObjectInspector *inspector;
@property (weak,nonatomic) FSObjectInspectorViewModelItem *rootViewModelItem;
@property (weak,nonatomic) FSObjectInspectorViewModelItem *selectedViewModelItem;
@property (readonly,nonatomic) NSSize desiredSize;
@property (strong,nonatomic) FSInterpreter *interpreter;

-(IBAction)showColorPanel:(id)sender;
-(IBAction)showOptionsPopover:(id)sender;
-(IBAction)inspectAction:(id)sender;
@end
