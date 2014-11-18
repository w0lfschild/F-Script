//
//  FSObjectInspectorViewModelItem.h
//  FScript
//
//  Created by Anthony Dervish on 16/11/2014.
//
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, FSInspectorVMValueType) {
  FS_ITEM_HEADER,
  FS_ITEM_ENUM,
  FS_ITEM_OPTIONS,
  FS_ITEM_NUMBER,
  FS_ITEM_SIZE,
  FS_ITEM_RECT,
  FS_ITEM_OBJECT,
  FS_ITEM_POINT,
  FS_ITEM_RANGE,
  FS_ITEM_BOOL,
};

@class CHBidirectionalDictionary;

@interface FSObjectInspectorViewModelItem : NSTreeNode
@property (copy,nonatomic) NSString *name;
@property (strong,nonatomic) id value;
@property (assign,nonatomic) FSInspectorVMValueType valueType;
@property (readonly,nonatomic) NSString *displayValue;
@property (assign,nonatomic) CHBidirectionalDictionary *enumBiDict;
@end
