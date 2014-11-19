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

@interface FSNamedInteger : NSObject
@property NSInteger integer;
@property NSString *name;
@end
@implementation FSNamedInteger
+(instancetype)integer:(NSInteger)num withName:(NSString*)name {
        FSNamedInteger *n = [self new];
        n.integer = num;
        n.name = name.copy;
        return n;
}
@end

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

-(NSArray *)enumObjects
{
        NSMutableArray *objs = [NSMutableArray new];
        for (NSNumber *num in self.enumBiDict.allKeys) {
                [objs addObject:[FSNamedInteger integer:num.integerValue withName:self.enumBiDict[num]]];
        }
        return objs;
}


-(NSInteger)numValue
{
        return (NSUInteger)[self.value doubleValue];
}

-(void)setNumValue:(NSInteger)value
{
        self.value = [FSNumber numberWithDouble:value];
}

+(NSSet *)keyPathsForValuesAffectingDisplayValue
{
        return [NSSet setWithObject:@"value"];
}

@end
