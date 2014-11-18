//
//  FSObjectInspectorViewModelItem.m
//  FScript
//
//  Created by Anthony Dervish on 16/11/2014.
//
//

#import "FSObjectInspectorViewModelItem.h"
#import "FSNamedNumber.h"
#import "FSNumber.h"
#import "CHBidirectionalDictionary.h"

@implementation FSObjectInspectorViewModelItem

-(NSString *)displayValue
{
        switch (self.valueType) {
                case FS_ITEM_HEADER:
                        return self.name;
                        break;
                case FS_ITEM_ENUM:
                        return [self.value description];
                        break;
                case FS_ITEM_OPTIONS:
                        return [self.value description];
                        break;
                case FS_ITEM_NUMBER:
                        return [self.value description];
                        break;
                case FS_ITEM_SIZE:
                        return NSStringFromSize([(NSValue*)self.value sizeValue]);
                        break;
                case FS_ITEM_RECT:
                        return NSStringFromRect([(NSValue*)self.value rectValue]);
                        break;
                case FS_ITEM_OBJECT:
                        return [self.value description];
                        break;
                case FS_ITEM_POINT:
                        return NSStringFromPoint([(NSValue*)self.value pointValue]);
                        break;
                case FS_ITEM_RANGE:
                        return NSStringFromRange([(NSValue*)self.value rangeValue]);
                        break;
                case FS_ITEM_BOOL:
                        return [self.value description];
                        break;
                default:
                        break;
        }

}
+(NSSet *)keyPathsForValuesAffectingDisplayValue
{
        return [NSSet setWithObject:@"value"];
}
@end
