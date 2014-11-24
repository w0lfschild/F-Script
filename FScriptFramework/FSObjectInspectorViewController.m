//
//  FSObjectInspectorViewController.m
//  FScript
//
//  Created by Anthony Dervish on 17/11/2014.
//
//

#import "FSObjectInspectorViewController.h"
#import "FSObjectInspectorViewController+NonArc.h"
#import "FSObjectInspectorViewModelItem.h"
#import "FSObjectInspectorOptionsViewController.h"
#import "FSDetailedObjectInspector.h"
#import "FSNamedNumber.h"
#import "FSMiscTools.h"
#import "FSObjectEnumInfo.h"
#import <objc/objc.h>
#import <AvailabilityMacros.h>

@interface FSObjectInspectorViewController ()
@property (nonatomic) BOOL hasAwoken;
@property (nonatomic,strong) NSPopover *optionsPopover;
@end

@interface FSObjectInspectorOption : NSObject
@property (copy,nonatomic) NSString *name;
@property (nonatomic) BOOL state;
@property (nonatomic) NSUInteger value;
@end
@implementation FSObjectInspectorOption
+(FSObjectInspectorOption*)optionWithName:(NSString*)name value:(NSUInteger)value state:(BOOL)on
{
        FSObjectInspectorOption *opt = [FSObjectInspectorOption new];
        opt.name = name;
        opt.state = on;
        opt.value = value;
        return opt;
}

+(NSArray *)arrayFromOptions:(NSUInteger) opts dict:(NSMutableDictionary *)dict mask:(NSUInteger) mask
{
        NSMutableArray* result = [NSMutableArray array];
        for (NSNumber * opt in dict.allKeys) {                                                                                                             
                [result addObject:[FSObjectInspectorOption optionWithName:(NSString*)dict[opt] value:opt.unsignedIntegerValue state:(opts & opt.unsignedIntegerValue)]];
        }
        return result;
}
+(NSUInteger)optionsFromArray:(NSArray /*of FSObjectInspectorOption */ *) opts dict:(NSMutableDictionary *)dict mask:(NSUInteger) mask
{
        NSUInteger result = 0;
        for (FSObjectInspectorOption *opt in opts) {
                if (opt.state) {
                        result |= opt.value;
                }
        }
        return result;
}
@end

/*
 *
 *
 *================================================================================================*/
#pragma mark - FSObjectInspectorViewController Implementation
/*==================================================================================================
 */


@implementation FSObjectInspectorViewController
{
        CGFloat _scrollViewOffsetY;
}

- (void)viewDidLoad
{
        [super viewDidLoad];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10
        self.view.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
#endif
}

- (void)awakeFromNib
{
        if (!self.hasAwoken) {
                self.hasAwoken = YES;
                [self expandAll:self];
                NSScrollView* scrollView = self.outlineView.enclosingScrollView;
                _scrollViewOffsetY = NSHeight(scrollView.superview.bounds) - NSHeight(scrollView.frame);
                self.outlineView.doubleAction = @selector(inspectAction:);
                self.outlineView.target = self;
        }
}

- (NSSize)desiredSize
{
        NSScrollView* scrollView = self.outlineView.enclosingScrollView;
        NSSize scrollViewSize = [NSScrollView frameSizeForContentSize:self.outlineView.bounds.size
                                              horizontalScrollerClass:scrollView.horizontalScroller.class
                                                verticalScrollerClass:scrollView.verticalScroller.class
                                                           borderType:scrollView.borderType
                                                          controlSize:scrollView.horizontalScroller.controlSize
                                                        scrollerStyle:scrollView.scrollerStyle];
        if (self.outlineView.headerView) {
                scrollViewSize.height += NSHeight(self.outlineView.headerView.bounds);
        }
        scrollViewSize.height += _scrollViewOffsetY;
        return scrollViewSize;
}
-(void)dealloc
{
        [NSObject cancelPreviousPerformRequestsWithTarget:self ];
}
-(IBAction)expandAll:(id)sender
{
        [self.outlineView expandItem:nil expandChildren:YES];
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
        _rootViewModelItem = rootViewModelItem;
        [self performSelector:@selector(expandAll:) withObject:self afterDelay:0.0];
}

/*
 *
 *
 *================================================================================================*/
#pragma mark - NSOutlineViewDelegate
/*==================================================================================================
 */

- (NSView*)outlineView:(NSOutlineView*)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
        if ([tableColumn.identifier isEqualToString:@"Name"]) {
                return [self.outlineView makeViewWithIdentifier:@"Name" owner:self];
        }
        NSView *view = nil;
        FSObjectInspectorViewModelItem* viewModel = [item representedObject];
        if ([viewModel respondsToSelector:@selector(valueType)]) {
                switch (viewModel.valueType) {
                        case FS_ITEM_HEADER:
                                view = [self.outlineView makeViewWithIdentifier:@"Header" owner:self];
                                break;
                        case FS_ITEM_ENUM:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorEnumView" owner:self];
                                break;
                        case FS_ITEM_OPTIONS:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorOptionsView" owner:self];
                                break;
                        case FS_ITEM_NUMBER:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorNumberView" owner:self];
                                break;
                        case FS_ITEM_SIZE:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorSizeView" owner:self];
                                break;
                        case FS_ITEM_RECT:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorRectView" owner:self];
                                break;
                        case FS_ITEM_OBJECT:
                                view = [self.outlineView makeViewWithIdentifier:[self _viewIdentifierForValueClass:viewModel.valueClass]
                                                                          owner:self];
                                break;
                        case FS_ITEM_POINT:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
                                break;
                        case FS_ITEM_RANGE:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
                                break;
                        case FS_ITEM_BOOL:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorEnumView" owner:self];
                                break;
                                
                        default:
                                break;
                }
        }
        else {
                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
        }
        return view;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
        FSInspectorVMValueType vmType = ((FSObjectInspectorViewModelItem*)[item representedObject]).valueType;
        return  vmType == FS_ITEM_HEADER;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
        FSInspectorVMValueType valueType = [(FSObjectInspectorViewModelItem*)[item representedObject] valueType] ;
        return (valueType != FS_ITEM_HEADER && valueType != FS_ITEM_GROUP);
}
/*
 *
 *
 *================================================================================================*/
#pragma mark - Utilities
/*==================================================================================================
 */


-(NSString*)_viewIdentifierForValueClass:(Class)class
{
        if (class == NSColor.class) {
                return @"ObjectInspectorColorView";
        }
        else if (class == NSString.class) {
                return @"ObjectInspectorStringView";
        }
        return @"ObjectInspectorReadOnlyView";
}

-(IBAction)setColor:(id)sender
{
        NSColor *color = [(NSColorPanel*)sender color];
        self.selectedViewModelItem.value = color;
}

-(void)showColorPanel:(id)sender
{
        NSInteger row = [self.outlineView rowForView:sender];
        if (row >= 0) {
                [NSColorPanel.sharedColorPanel orderFront:self];
                NSColorPanel.sharedColorPanel.target = self;
                NSColorPanel.sharedColorPanel.action = @selector(setColor:);
                
                self.selectedViewModelItem = [[self.outlineView itemAtRow:row] representedObject];
                
        }
        
}
-(IBAction)inspectAction:(id)sender
{
        NSInteger row = [self.outlineView selectedRow];
        if (row >= 0) {
                FSObjectInspectorViewModelItem *item = [[self.outlineView itemAtRow:row] representedObject];
                if (item.valueType == FS_ITEM_OBJECT && item.valueClass != nil) {
                        inspect(item.value, self.interpreter, nil);
                }
        }
}

-(FSObjectInspectorOptionsViewController*)optionsViewController
{
        return (FSObjectInspectorOptionsViewController*)self.optionsPopover.contentViewController;
}
-(NSPopover*)optionsPopover
{
        if (_optionsPopover == nil) {
                _optionsPopover = [NSPopover new];
                _optionsPopover.behavior = NSPopoverBehaviorTransient;
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10
                _optionsPopover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameLightContent];
#else
                _optionsPopover.appearance = NSPopoverAppearanceHUD;
#endif
                _optionsPopover.contentViewController = [FSObjectInspectorOptionsViewController new];
                _optionsPopover.delegate = self;
        }
        return _optionsPopover;
}

-(IBAction)showOptionsPopover:(id)sender
{
        NSInteger row = [self.outlineView rowForView:sender];
        if (row >= 0) {
                NSRect senderFrame = [sender frame];
                FSObjectInspectorViewModelItem *clickedItem = [[self.outlineView itemAtRow:row] representedObject];
                self.selectedViewModelItem = clickedItem;
                NSArray *optionItems = [FSObjectInspectorOption arrayFromOptions:clickedItem.numValue dict:clickedItem.enumBiDict mask:clickedItem.optsMask];
                self.optionsViewController.optionItems = optionItems;
                [self.optionsPopover showRelativeToRect:senderFrame ofView:sender preferredEdge:NSMaxYEdge];
        }
}
/*
 *
 *
 *================================================================================================*/
#pragma mark - NSPopoverDelegate
/*==================================================================================================
 */

-(void)popoverDidClose:(NSNotification *)notification
{
        
        NSUInteger newOpts = [FSObjectInspectorOption optionsFromArray:self.optionsViewController.optionItems dict:self.selectedViewModelItem.enumBiDict mask:self.selectedViewModelItem.optsMask];
        self.selectedViewModelItem.value = objectFromOptions(newOpts, self.selectedViewModelItem.enumBiDict, self.selectedViewModelItem.optsMask);
}

/*
 *
 *
 *================================================================================================*/
#pragma mark - NSResponder
/*==================================================================================================
 */
-(BOOL)acceptsFirstResponder
{
        return YES;
}
-(id)supplementalTargetForAction:(SEL)action sender:(id)sender
{
        if (action == @selector(refreshModel:)
            || action == @selector(browseAction:))
        {
                return self.inspector;
        }
        return [super supplementalTargetForAction:action sender:sender];
}
@end
