//  FSDetailedObjectInspector.m Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import "FSDetailedObjectInspector.h"
#import "FSMiscTools.h"
#import "FSObjectInspectorViewModelItem.h"
#import "FSObjectInspectorViewController.h"
#import "FSUtils.h"

static NSPoint sTopLeftPoint = { 0, 0 }; // Used for cascading windows.
static BOOL sIsFirstWindow = YES;
static void *TREE_OBSERVATION_CONTEXT = &TREE_OBSERVATION_CONTEXT;

@interface NSTreeNode (FSTraversal)
-(void)fs_visitNodesWithBlock:(void(^)(NSTreeNode*node))block;
@end
@implementation NSTreeNode (FSTraversal)
-(void)fs_visitNodesWithBlock:(void(^)(NSTreeNode*node))block
{
        assert(block && "block cannot be nil");
        block(self);
        for (NSTreeNode *child in self.childNodes) {
                [child fs_visitNodesWithBlock:block];
        }
}
@end



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


-(void)dealloc
{
        [self _unwatchItems];
}

- (void)updateAction:(id)sender
{
        [self.window setTitle:[NSString stringWithFormat:@"Inspecting %@ at address %p", descriptionForFSMessage(self.inspectedObject), self.inspectedObject]];
}

/////////////////// Window delegate callbacks

- (void)windowWillClose:(NSNotification*)aNotification
{
}

/*
 *
 *
 *================================================================================================*/
#pragma mark - Properties
/*==================================================================================================
 */


-(void)setRootViewModelItem:(FSObjectInspectorViewModelItem *)rootViewModelItem
{
        [self _unwatchItems];
        _rootViewModelItem = rootViewModelItem;
        [self _watchItems];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
        if (context == TREE_OBSERVATION_CONTEXT) {
                NSLog(@"Value changed for %@. Change = %@", object, change);
                id target = self.inspectedObject;
                FSObjectInspectorViewModelItem *item = object;
                @try {
                        if (item.setter) {
                                if (item.valueType == FS_ITEM_OBJECT) {
                                        item.setter(target, item.value, item);
                                        NSLog(@"[%@ setValue:%@ forKey:%@",target,item.value,item.getter);
                                }
                                else {
                                        item.setter(target, @(item.numValue), item);
                                        NSLog(@"[%@ setValue:%@ forKey:%@",target,@(item.numValue),item.getter);
                                }
                        }
                }
                @catch(NSException *e) {
                        NSLog(@"Exception when setting value for key %@ on %@: %@", keyPath, target, e);
                }
        }
}
/*
 *
 *
 *================================================================================================*/
#pragma mark - Utilities
/*==================================================================================================
 */


-(void)_watchItems
{
        [self.rootViewModelItem fs_visitNodesWithBlock:^(NSTreeNode *node) {
                [node addObserver:self
                       forKeyPath:@"value"
                          options:0
                          context:TREE_OBSERVATION_CONTEXT];
        }];
}
-(void)_unwatchItems
{
        [self.rootViewModelItem fs_visitNodesWithBlock:^(NSTreeNode *node) {
                [node removeObserver:self
                          forKeyPath:@"value" ];
        }];
}

@end
