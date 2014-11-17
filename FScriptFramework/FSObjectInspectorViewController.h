//
//  FSObjectInspectorViewController.h
//  FScript
//
//  Created by Anthony Dervish on 17/11/2014.
//
//

#import <Cocoa/Cocoa.h>

@class FSObjectInspectorViewModelItem;

@interface FSObjectInspectorViewController : NSViewController <NSOutlineViewDelegate>
@property (assign) IBOutlet NSOutlineView *outlineView;
@property (weak,nonatomic) FSObjectInspectorViewModelItem *rootViewModelItem;
@end
