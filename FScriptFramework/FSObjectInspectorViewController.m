//
//  FSObjectInspectorViewController.m
//  FScript
//
//  Created by Anthony Dervish on 17/11/2014.
//
//

#import "FSObjectInspectorViewController.h"
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

@end
