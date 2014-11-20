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
#import <objc/objc.h>
#import <AvailabilityMacros.h>


@interface FSObjectInspectorViewController ()
@property (nonatomic) BOOL hasAwoken;

@end

@implementation FSObjectInspectorViewController

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
                [self.outlineView expandItem:nil expandChildren:YES];
                NSLog(@"outline view size = %@", NSStringFromSize(self.outlineView.bounds.size));
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
        scrollViewSize.height += NSHeight(self.outlineView.headerView.bounds);
        return scrollViewSize;
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
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
                                break;
                        case FS_ITEM_ENUM:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorEnumView" owner:self];
                                break;
                        case FS_ITEM_OPTIONS:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
                                break;
                        case FS_ITEM_NUMBER:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorNumberView" owner:self];
                                break;
                        case FS_ITEM_SIZE:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
                                break;
                        case FS_ITEM_RECT:
                                view = [self.outlineView makeViewWithIdentifier:@"ObjectInspectorReadOnlyView" owner:self];
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

@end
