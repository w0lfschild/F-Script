//
//  FSObjectInspectorViewModelItem.h
//  FScript
//
//  Created by Anthony Dervish on 16/11/2014.
//
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, FSInspectorVMItemType) {
  FS_ITEM_HEADER,
  FS_ITEM_ENUM,
  FS_ITEM_OPTIONS,
  FS_ITEM_CONTINUOUS,
  FS_ITEM_SIZE,
  FS_ITEM_RECT
};

@interface FSObjectInspectorViewModelItem : NSTreeNode
@property (copy,nonatomic) NSString *name;
@property (retain,nonatomic) id value;
@property (assign,nonatomic) FSInspectorVMItemType itemType;
@end
