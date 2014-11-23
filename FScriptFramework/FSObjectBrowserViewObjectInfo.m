//  FSObjectBrowserViewObjectInfo.m Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import "FSObjectBrowserViewObjectInfo.h"
#import "FSObjectEnumInfo.h"
#import "FSObjectBrowserCell.h"
#import "FSObjectBrowserMatrix.h"
#import "FSNamedNumber.h"
#import "FSNumber.h"
#import "FSMiscTools.h"
#import "FSBoolean.h"
#import "FSBlock.h"
#import "BlockRep.h"
#import "FSGenericPointer.h"
#import "FSGenericPointerPrivate.h"
#import "FSObjectBrowserNamedObjectWrapper.h"
#import "FSObjectInspectorViewModelItem.h"
#import "FSNSString.h"
#import <objc/objc-class.h>
#import "FSGenericPointerPrivate.h"
#import "FSObjectPointerPrivate.h"
#import "FSCNClassDefinition.h"
#import "FSCNCategory.h"
#import "FSCNIdentifier.h"
#import "FSCNSuper.h"
#import "FSPattern.h"
#import "FSCNUnaryMessage.h"
#import "FSCNBinaryMessage.h"
#import "FSCNKeywordMessage.h"
#import "FSCNCascade.h"
#import "FSCNStatementList.h"
#import "FSCNPrecomputedObject.h"
#import "FSCNArray.h"
#import "FSCNBlock.h"
#import "FSCNAssignment.h"
#import "FSCNMethod.h"
#import "FSCNReturn.h"
#import "FSCNDictionary.h"
#import "FSAssociation.h"

static inline NSString* fs_setterForProperty(NSString* prop)
{
        NSString* setter = @"";
        if (prop.length > 1) {
                setter = [[@"set" stringByAppendingString:[prop substringToIndex:1].uppercaseString] stringByAppendingString:[prop substringFromIndex:1]];
        }
        else if (prop.length == 1) {
                setter = [prop uppercaseString];
        }
        return setter;
}

NSString*
labelFromPropertyName(NSString* propertyName)
{
        NSMutableString* formLabel = [ NSMutableString string ];
        NSScanner* scanner  = [ NSScanner scannerWithString: propertyName ];
        
        BOOL first = YES;
        NSString* item      = nil;
        NSString* upperCase = @"";
        
        while ( ![ scanner isAtEnd ] && [ scanner scanUpToCharactersFromSet: [ NSCharacterSet uppercaseLetterCharacterSet ] intoString: &item ] ) {
                if ( !first ) {
                        [ formLabel appendFormat: @" %@%@", upperCase, item ];
                }
                else {
                        [ formLabel appendFormat: @"%@%@", [ [item substringToIndex:1] uppercaseString ], (item.length>1?[ item substringFromIndex:1]:@"") ];
                        first = NO;
                }
                
                [ scanner scanCharactersFromSet: [ NSCharacterSet uppercaseLetterCharacterSet ] intoString: &upperCase ];
        }
        
        if ( ![ scanner isAtEnd ] ) {
                [ formLabel appendFormat: @" %@", [ [ scanner string ] substringFromIndex: [ scanner scanLocation ] ] ];
        }
        
        return formLabel;
}


@interface FSObjectBrowserViewObjectHelper ()

@property (nonatomic, assign) FSObjectInspectorViewModelItem* currentViewModelItem;

- (id)initWithObjectBrowserView:(FSObjectBrowserView*)view;
- (void)fillMatrix:(NSMatrix*)m withObject:(id)object;
@end


@implementation FSObjectBrowserView (FSObjectBrowserViewObjectInfo)


- (void)fillMatrix:(NSMatrix*)m column:(NSUInteger)col withObject:(id)object
{
        FSObjectBrowserViewObjectHelper* objectHelper = [[FSObjectBrowserViewObjectHelper alloc] initWithObjectBrowserView:self];
        [objectHelper fillMatrix:m withObject:object];

        [self addBlankRowToMatrix:m];
        [self fillMatrix:m withMethodsForObject:object];

        [m sizeToCells];
        //[m scrollCellToVisibleAtRow:[matrix selectedRow] column:0];
        [m setNeedsDisplay];

        [objectHelper release];
}

@end


@implementation FSObjectBrowserViewObjectHelper {
        FSObjectBrowserCell* selectedCell;
        NSString* selectedClassLabel;
        NSString* selectedLabel;
        id selectedObject;
        NSString* classLabel;
        NSMatrix* m;
        FSObjectBrowserView* view;
}

- (id)init
{
        return [self initWithObjectBrowserView:nil];
}

- (id)initWithObjectBrowserView:(FSObjectBrowserView*)theView
{
        self = [super init];
        if (self) {

                view = [[theView retain] autorelease];
                self.rootViewModelItem = [FSObjectInspectorViewModelItem new];
                self.currentViewModelItem = self.rootViewModelItem;
        }

        return self;
}

- (void)dealloc
{
        [_rootViewModelItem release];
        [super dealloc];
}
- (void)addClassLabel:(NSString*)cLabel toMatrix:(NSMatrix*)matrix
{
        [view addClassLabel:cLabel toMatrix:matrix];
        FSObjectInspectorViewModelItem* item = [[FSObjectInspectorViewModelItem new] autorelease];
        item.valueType = FS_ITEM_HEADER;
        item.name = cLabel;
        [self.rootViewModelItem.mutableChildNodes addObject:item];
        self.currentViewModelItem = item;
}

- (void)addObject:(id)object valueType:(FSInspectorVMValueType)valueType getter:(FSGetterBlock)getter setter:(FSSetterBlock)setter withLabel:(NSString*)label enumBiDict:(NSMutableDictionary*)enumBiDict mask:(NSUInteger)mask valueClass:(Class)valueClass notNil:(BOOL)notNil
{
        @try {
                if (!notNil || object) {
                        if (view) {
                                [view addObject:object withLabel:label toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        }
                }
                if (valueType != FS_ITEM_OBJECT || valueClass) {
                        FSObjectInspectorViewModelItem* item = [[FSObjectInspectorViewModelItem new] autorelease];
                        item.name = label;
                        item.valueType = valueType;
                        item.value = object;
                        item.enumBiDict = enumBiDict;
                        item.getter = getter;
                        item.setter = setter;
                        item.optsMask = mask;
                        item.valueClass = valueClass ?: [object class];
                        [self.currentViewModelItem.mutableChildNodes addObject:item];
                }
        }
        @catch (id exception)
        {
                NSLog(@"%@", exception);
        }
}
- (void)addObject:(id)object valueType:(FSInspectorVMValueType)valueType getter:(FSGetterBlock)getter setter:(FSSetterBlock)setter withLabel:(NSString*)label notNil:(BOOL)notNil
{
        [self addObject:object valueType:valueType getter:getter setter:setter withLabel:label enumBiDict:nil mask:0 valueClass:nil notNil:notNil];
}
- (void)addObject:(id)object valueType:(FSInspectorVMValueType)valueType withLabel:(NSString*)label notNil:(BOOL)notNil
{
        [self addObject:object valueType:valueType getter:nil setter:nil withLabel:label enumBiDict:nil mask:0 valueClass:(Class)nil notNil:notNil];
}
- (void)addObject:(id)object valueType:(FSInspectorVMValueType)valueType getter:(FSGetterBlock)getter setter:(FSSetterBlock)setter withLabel:(NSString*)label
{
        [self addObject:object valueType:valueType getter:getter setter:setter withLabel:label enumBiDict:nil mask:0 valueClass:nil notNil:NO];
}

- (void)addGroup:(NSString*)groupName
{
        FSObjectInspectorViewModelItem* item = [[FSObjectInspectorViewModelItem new] autorelease];
        item.name = groupName;
        item.valueType = FS_ITEM_GROUP;
        [self.currentViewModelItem.mutableChildNodes addObject:item];
        self.currentViewModelItem = item;
}

- (void)endGroup
{
        self.currentViewModelItem = (FSObjectInspectorViewModelItem*)self.currentViewModelItem.parentNode;
}

#define START_GROUP(GROUP) [self addGroup:(@ #GROUP)];
#define END_GROUP(GROUP) [self endGroup];

#define ADD_VALUE(OBJECT, VALUE_TYPE, GETTER, SETTER, BIDICT, MASK, VALUE_CLASS, LABEL, NOT_NIL)                                                                                                                                                                                                                                                               \
        @try {                                                                                                                                                                                                                                                                                                                                                 \
                if (#SETTER[0] != '-') { \
                        [self addObject:(OBJECT)valueType:VALUE_TYPE getter:^(id obj, FSObjectInspectorViewModelItem* item) { return [obj valueForKey:@ #GETTER]; } setter:^(id obj, id newVal, FSObjectInspectorViewModelItem* item) { [obj setValue:newVal forKey:@ #GETTER]; } withLabel:(LABEL)enumBiDict:BIDICT mask:MASK valueClass:VALUE_CLASS notNil:NOT_NIL]; \
                } \
                else { \
                        [self addObject:(OBJECT)valueType:VALUE_TYPE getter:^(id obj, FSObjectInspectorViewModelItem* item) { return [obj valueForKey:@ #GETTER]; } setter:nil withLabel:(LABEL)enumBiDict:BIDICT mask:MASK valueClass:VALUE_CLASS notNil:NOT_NIL]; \
                } \
        }                                                                                                                                                                                                                                                                                                                                                      \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_ENUM(OBJECT, GETTER, ENUM) \
        ADD_VALUE(objectFrom##ENUM([OBJECT GETTER]), FS_ITEM_ENUM, GETTER, GETTER, FSObjectEnumInfo.optionsFor##ENUM, 0, nil, labelFromPropertyName(@#GETTER), NO);

#define ADD_OPTIONS(OBJECT, GETTER, ENUM) \
        ADD_VALUE(objectFrom##ENUM([OBJECT GETTER]), FS_ITEM_OPTIONS, GETTER, GETTER, FSObjectEnumInfo.optionsFor##ENUM, ENUM##Mask, nil, labelFromPropertyName(@#GETTER), NO);

#define ADD_SIZE(OBJECT, GETTER) \
        ADD_VALUE([NSValue valueWithSize:[OBJECT GETTER], FS_ITEM_SIZE, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO)

#define ADD_RECT(OBJECT, GETTER) \
        ADD_VALUE([NSValue valueWithRect:[OBJECT GETTER], FS_ITEM_RECT, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO)


#define ADD_POINT(OBJECT, GETTER) \
        ADD_VALUE([NSValue valueWithPoint:[OBJECT GETTER], FS_ITEM_POINT, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO)


#define ADD_RANGE(OBJECT, GETTER) \
        ADD_VALUE([NSValue valueWithRange:[OBJECT GETTER], FS_ITEM_RANGE, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO)

#define ADD_OBJECT(OBJECT, GETTER) \
        ADD_VALUE([OBJECT GETTER], FS_ITEM_OBJECT, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO)
#define ADD_OBJECT_NOT_NIL(OBJECT, GETTER) \
        ADD_VALUE([OBJECT GETTER], FS_ITEM_OBJECT, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), YES)
#define ADD_OBJECT_RO(OBJECT, LABEL) ADD_OBJECT2((OBJECT), nil, nil, LABEL)
#define ADD_OBJECT_RO_NOT_NIL(OBJECT, LABEL) ADD_OBJECT_NOT_NIL(OBJECT, nil, nil, LABEL) \
        ADD_VALUE((OBJECT), FS_ITEM_OBJECT, nil, nil, nil, nil, 0, LABEL, YES)


#define ADD_COLOR(OBJECT, GETTER) \
        ADD_VALUE([OBJECT GETTER], FS_ITEM_OBJECT, GETTER, GETTER, nil, 0, NSColor.class, labelFromPropertyName(@#GETTER), NO)

#define ADD_COLOR_NOT_NIL(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE([OBJECT GETTER], FS_ITEM_OBJECT, GETTER, GETTER, nil, 0, NSColor.class, labelFromPropertyName(@#GETTER), YES)

#define ADD_STRING(OBJECT, GETTER) \
        ADD_VALUE([OBJECT GETTER], FS_ITEM_OBJECT, GETTER, GETTER, nil, 0, NSString.class, labelFromPropertyName(@#GETTER), NO)

#define ADD_STRING_NOT_NIL(OBJECT, GETTER) \
        ADD_VALUE([OBJECT GETTER], FS_ITEM_OBJECT, GETTER, GETTER, nil, 0, NSString.class, labelFromPropertyName(@#GETTER), YES)

#define ADD_BOOL(OBJECT, GETTER) \
        ADD_VALUE([FSBoolean booleanWithBool:[OBJECT GETTER]], FS_ITEM_BOOL, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO);

#define ADD_NUMBER(OBJECT, GETTER) \
        ADD_VALUE([FSNumber numberWithDouble:([OBJECT GETTER)], FS_ITEM_NUMBER, GETTER, GETTER, nil, 0, nil, labelFromPropertyName(@#GETTER), NO)

#define ADD_DICTIONARY(OBJECTS, LABEL)                                                                                                                                                                   \
        @try {                                                                                                                                                                                           \
                if ([(OBJECTS)count] <= 20)                                                                                                                                                              \
                        [view addDictionary:(OBJECTS)withLabel:(LABEL)toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject]; \
                else                                                                                                                                                                                     \
                        [self addObject:(OBJECTS)valueType:FS_ITEM_OBJECT withLabel:(LABEL)notNil:NO];                                                                                                   \
        }                                                                                                                                                                                                \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_OBJECTS(OBJECTS, LABEL)                                                                                                                                                                   \
        @try {                                                                                                                                                                                        \
                if ([(OBJECTS)count] <= 20)                                                                                                                                                           \
                        [view addObjects:(OBJECTS)withLabel:(LABEL)toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject]; \
                else                                                                                                                                                                                  \
                        [self addObject:(OBJECTS)valueType:FS_ITEM_OBJECT withLabel:(LABEL)notNil:NO];                                                                                                \
        }                                                                                                                                                                                             \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_SEL(S, LABEL)                                                                                                                                                                                                                       \
        @try {                                                                                                                                                                                                                                  \
                [view addObject:[FSBlock blockWithSelector:(S)] withLabel:(LABEL)toMatrix:m leaf:YES classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:0]; \
        }                                                                                                                                                                                                                                       \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_SEL_NOT_NULL(S, LABEL)                                                                                                                                                                                                                                   \
        @try {                                                                                                                                                                                                                                                       \
                {                                                                                                                                                                                                                                                    \
                        SEL selector = (S);                                                                                                                                                                                                                          \
                        if (selector != (SEL)0)                                                                                                                                                                                                                      \
                                [view addObject:[FSBlock blockWithSelector:selector] withLabel:(LABEL)toMatrix:m leaf:YES classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:0]; \
                }                                                                                                                                                                                                                                                    \
        }                                                                                                                                                                                                                                                            \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_POINTER(POINTER, LABEL)                                                                                                                                                                                                                                                               \
        @try {                                                                                                                                                                                                                                                                                    \
                if (POINTER == NULL) {                                                                                                                                                                                                                                                            \
                        ADD_OBJECT_RO(nil, LABEL)                                                                                                                                                                                                                                                 \
                }                                                                                                                                                                                                                                                                                 \
                else {                                                                                                                                                                                                                                                                            \
                        [view addObject:[[[FSGenericPointer alloc] initWithCPointer:(POINTER)freeWhenDone:NO type:@encode(void)] autorelease] withLabel:(LABEL)toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject]; \
                }                                                                                                                                                                                                                                                                                 \
        }                                                                                                                                                                                                                                                                                         \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_CLASS_LABEL(LABEL)                          \
        {                                               \
                [self addClassLabel:(LABEL)toMatrix:m]; \
        }


#define ADD_SIZE2(SIZE, GETTER, SETTER, LABEL) \
        ADD_VALUE([NSValue valueWithSize:(SIZE)], FS_ITEM_SIZE, GETTER, SETTER, nil, nil, 0, LABEL, NO)
#define ADD_RECT2(RECT,GETTER, SETTER, LABEL) \
        ADD_VALUE([NSValue valueWithRect:(RECT)], FS_ITEM_RECT, GETTER, SETTER, nil, nil, 0, LABEL, NO)
#define ADD_POINT2(POINT,GETTER, SETTER, LABEL) \
        ADD_VALUE([NSValue valueWithPoint:(POINT)], FS_ITEM_POINT, GETTER, SETTER, nil, nil, 0, LABEL, NO)
#define ADD_RANGE2(RANGE, GETTER, SETTER,LABEL) \
        ADD_VALUE([NSValue valueWithRange:(RANGE)], FS_ITEM_RANGE, GETTER, SETTER, nil, nil, 0, LABEL, NO)
#define ADD_OBJECT2(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE((OBJECT), FS_ITEM_OBJECT, GETTER, SETTER, nil, nil, 0, LABEL, NO)
#define ADD_COLOR2(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, 0, NSColor.class, LABEL, NO)
#define ADD_NUMBER2(NUMBER, GETTER, SETTER, LABEL) \
        ADD_VALUE([FSNumber numberWithDouble:(NUMBER)], FS_ITEM_NUMBER, GETTER, SETTER, nil, 0, nil, LABEL, NO);

- (void)fillMatrix:(NSMatrix*)theMatrix withObject:(id)object
{

        [object retain]; // (1) To be sure object will not be deallocated as a side effect of the removing of rows

        m = theMatrix;
        selectedCell = [[[m selectedCell] retain] autorelease]; // retain and autorelease in order to avoid premature deallocation as a side effect of the removing of rows
        selectedClassLabel = [[[selectedCell classLabel] copy] autorelease]; // copy and autorelease in order to avoid premature invalidation as a side effect of the removing of rows
        selectedLabel = [[[selectedCell label] copy] autorelease]; // copy and autorelease in order to avoid premature invalidation as a side effect of the removing of rows
        selectedObject = [selectedCell representedObject];
        classLabel = @"";

        [m renewRows:0 columns:1];

        [view addObject:object toMatrix:m label:@"" classLabel:@"" indentationLevel:0 leaf:YES];
        [object release]; // It's now safe to match the retain in instruction (1)

        if (selectedObject == object && [selectedClassLabel isEqualToString:@""] && [selectedLabel isEqualToString:@""])
                [m selectCellAtRow:[m numberOfRows] - 1 column:0];

        if (object != nil && object == [object class]) // object is a class
        {
                NSMutableArray* classNames = [NSMutableArray array];
                NSUInteger count, i;
                Class* classes = allClasses(&count);

                @try {
                        for (i = 0; i < count; i++) {
#ifdef __LP64__
                                if (class_getSuperclass(classes[i]) == object)
                                        [classNames addObject:NSStringFromClass(classes[i])];
#else
                                if (classes[i]->super_class == object)
                                        [classNames addObject:NSStringFromClass(classes[i])];
#endif
                        }
                }
                @finally
                {
                        free(classes);
                }
                [classNames sortUsingFunction:FSCompareClassNamesForAlphabeticalOrder context:NULL];

                [view addBlankRowToMatrix:m];

#ifdef __LP64__
                if (class_getSuperclass(object) == nil)
                        [view addLabelAlone:@"This class is a root class" toMatrix:m];
                else
                        [view addObject:class_getSuperclass((Class)object) withLabel:@"Superclass" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
#else
                if (((Class)object)->super_class == nil)
                        [view addLabelAlone:@"This class is a root class" toMatrix:m];
                else
                        [view addObject:((Class)object)->super_class withLabel:@"Superclass" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
#endif

                if ([classNames count] == 0)
                        [view addLabelAlone:@"No subclasses" toMatrix:m];
                [view addClassesWithNames:classNames withLabel:@"Direct subclasses" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
        }
        else if ([object isKindOfClass:[NSManagedObject class]]) {
                NSManagedObject* o = object;
                classLabel = @"NSManagedObject Properties";
                NSArray* attributeKeys = [[[[o entity] attributesByName] allKeys] sortedArrayUsingSelector:@selector(compare:)];
                [view addPropertyLabel:@"Attributes" toMatrix:m];
                for (NSUInteger i = 0, count = [attributeKeys count]; i < count; i++) {
                        NSString* key = [attributeKeys objectAtIndex:i];
                        ADD_OBJECT2([o valueForKey:key], key, - , key)
                }

                NSArray* relationshipKeys = [[[[o entity] relationshipsByName] allKeys] sortedArrayUsingSelector:@selector(compare:)];
                [view addPropertyLabel:@"Relationships" toMatrix:m];
                for (NSUInteger i = 0, count = [relationshipKeys count]; i < count; i++) {
                        NSString* key = [relationshipKeys objectAtIndex:i];
                        ADD_OBJECT2([o valueForKey:key], key, - , key)
                }

                ADD_CLASS_LABEL(@"NSManagedObject Info");
                ADD_OBJECT(o, entity)
                ADD_BOOL(o, isDeleted)
                ADD_BOOL(o, isInserted)
                ADD_BOOL(o, isUpdated)
                ADD_OBJECT(o, managedObjectContext)
                ADD_OBJECT(o, objectID)
        }
        else if (([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSSet class]])
                 && [object count] < 500) // We display the elements only if there is less than a certain number of them
        {
                [view addBlankRowToMatrix:m];
                if ([object isKindOfClass:[NSArray class]]) {
                        NSArray* o = object;
                        if ([o count] == 0)
                                [view addLabelAlone:@"This array is empty" toMatrix:m];
                        [view addObjects:o withLabel:@"Elements" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[NSDictionary class]]) {
                        NSDictionary* o = object;
                        if ([o count] == 0)
                                [view addLabelAlone:@"This dictionary is empty" toMatrix:m];
                        [view addDictionary:o withLabel:@"Entries" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[NSSet class]]) {
                        NSSet* o = object;
                        if ([o count] == 0)
                                [view addLabelAlone:@"This set is empty" toMatrix:m];
                        [view addObjects:[object allObjects] withLabel:@"Elements" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
        }
        else if ([object isKindOfClass:[FSAssociation class]]) {
                FSAssociation* o = object;
                [view addBlankRowToMatrix:m];
                [view addObject:[o key] withLabel:@"Key" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                [view addObject:[o value] withLabel:@"Value" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
        }
        else if ([object isKindOfClass:[NSView class]]) {
                NSView* o = object;
                [view addBlankRowToMatrix:m];

                [view addObject:[o superview] withLabel:@"Superview" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];

                if ([[o subviews] count] == 0)
                        [view addLabelAlone:@"No subviews" toMatrix:m];
                else
                        [view addObjects:[o subviews] withLabel:@"Subviews" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
        }
        else if ([object isKindOfClass:[FSCNBase class]]) {
                [view addBlankRowToMatrix:m];

                if ([object isKindOfClass:[FSCNArray class]]) {
                        FSCNArray* o = object;
                        if (o->count == 0)
                                [view addLabelAlone:@"An empty array" toMatrix:m];
                        else
                                [view addObjects:[NSArray arrayWithObjects:o->elements count:o->count] withLabel:@"Elements" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNAssignment class]]) {
                        FSCNAssignment* o = object;
                        [view addObject:o->left withLabel:@"lvalue" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObject:o->right withLabel:@"rvalue" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNBlock class]]) {
                        FSCNBlock* o = object;
                        [view addObject:[o->blockRep ast] withLabel:@"Abstract syntax tree" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNCascade class]]) {
                        FSCNCascade* o = object;
                        [view addObject:o->receiver withLabel:@"Receiver" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObjects:[NSArray arrayWithObjects:o->messages count:o->messageCount] withLabel:@"Message sends" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNCategory class]]) {
                        FSCNCategory* o = object;
                        [view addObject:o->className withLabel:@"Class name" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObjects:o->methods withLabel:@"Methods" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNClassDefinition class]]) {
                        FSCNClassDefinition* o = object;
                        [view addObject:o->className withLabel:@"Class name" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObject:o->superclassName withLabel:@"Superclass name" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObjects:o->civarNames withLabel:@"Class instance variables names" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObjects:o->ivarNames withLabel:@"Instance variables names" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObjects:o->methods withLabel:@"Methods" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNDictionary class]]) {
                        FSCNDictionary* o = object;
                        if (o->count == 0)
                                [view addLabelAlone:@"An empty dictionary" toMatrix:m];
                        else
                                [view addObjects:[NSArray arrayWithObjects:o->entries count:o->count] withLabel:@"Entries" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNMethod class]]) {
                        FSCNMethod* o = object;
                        [view addObject:o->method->code withLabel:@"Abstract syntax tree" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNMessage class]]) {
                        FSCNMessage* o = object;
                        [view addObject:o->receiver withLabel:@"Receiver" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];

                        if ([object isKindOfClass:[FSCNBinaryMessage class]]) {
                                FSCNBinaryMessage* o = object;
                                [view addObject:o->argument withLabel:@"Argument" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        }
                        else if ([object isKindOfClass:[FSCNKeywordMessage class]]) {
                                FSCNKeywordMessage* o = object;
                                [view addObjects:[NSArray arrayWithObjects:o->arguments count:o->argumentCount] withLabel:(o->argumentCount > 1 ? @"Arguments" : @"Argument")toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        }
                }
                else if ([object isKindOfClass:[FSCNPrecomputedObject class]]) {
                        FSCNPrecomputedObject* o = object;
                        [view addObject:o->object withLabel:@"Precomputed object" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNStatementList class]]) {
                        FSCNStatementList* o = object;
                        [view addObject:[NSNumber numberWithUnsignedInteger:o->statementCount] withLabel:@"Number of statements" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                        [view addObjects:[NSArray arrayWithObjects:o->statements count:o->statementCount] withLabel:@"Statements" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
                else if ([object isKindOfClass:[FSCNReturn class]]) {
                        FSCNReturn* o = object;
                        [view addObject:o->expression withLabel:@"Expression" toMatrix:m classLabel:@"" selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                }
        }

        /////////////////// Objective-C 2.0 declared properties ///////////////////
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FScriptAutomaticallyIntrospectDeclaredProperties"]) {
                [self introspectPropertiesOfObject:object];
        }

        /////////////////// Bindings ///////////////////
        if ([object respondsToSelector:@selector(exposedBindings)] && [object respondsToSelector:@selector(infoForBinding:)]) {
                NSUInteger i, count;
                NSArray* exposedBindings = nil;

                // Several Cocoa objects have a buggy implementation of the exposedBindings method (e.g. NSTextView),
                // which leads to an exception being thrown when the method is called on certain *class* objects.
                // We work around these bugs here by preventing the buggy exception to interupt the current method.
                // Note: I'm writing this in Mac OS X 10.4.6.
                // Update for 10.5: the exposedBindings method now crash for certain class objects. I work around this
                // bellow by not calling it at all on class objects.
                @try {
                        if ([object class] != object)
                                exposedBindings = [object exposedBindings];
                }
                @catch (id exeption)
                {
                }

                if (exposedBindings) {
                        for (i = 0, count = [exposedBindings count]; i < count; i++)
                                if ([object infoForBinding:[exposedBindings objectAtIndex:i]])
                                        break;

                        if (i < count && count > 0) {
                                classLabel = @"Bindings";
                                [view addClassLabel:classLabel toMatrix:m color:[NSColor colorWithCalibratedRed:0 green:0.7098 blue:1 alpha:1]];

                                for (i = 0, count = [exposedBindings count]; i < count; i++) {
                                        [view addBindingForObject:object withName:[exposedBindings objectAtIndex:i] toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                                }

                                ADD_OBJECT_RO(exposedBindings, @"Exposed Bindings");
                        }
                }
        }
        [self populateModelWithObject:object];
}

- (void)populateModelWithObject:(id)object
{
        // For each documented base class the object inherits from, populate the matrix with 'interesting' values
        // declared as members of that base class
        for (Class baseClass in FSObjectBrowserViewObjectHelper.baseClasses) {
                if ([object isKindOfClass:baseClass]) {
                        NSString* method = [NSString stringWithFormat:@"add%@:", [baseClass className]];
                        SEL selector = NSSelectorFromString(method);

                        NSAssert([self respondsToSelector:selector], @"Missing base class method");

                        [self performSelector:selector withObject:object];
                        break;
                }
        }
}

-(void)introspectPropertiesOfObject:(id)object
{
        Class cls = [object classOrMetaclass];
        while (cls) {
                unsigned int i, count;
                objc_property_t* properties = class_copyPropertyList(cls, &count);
                if (properties != NULL && !(cls == [NSView class])) // Second part of condition is a quick fix to avoid bloating display for the NSView class with a "one property" section (10.5.0) or spurious properties (10.6). TODO: revise this.
                {
                        classLabel = [NSString stringWithFormat:@"%@ Properties", [cls printString]];
                        [view addClassLabel:classLabel toMatrix:m color:[NSColor magentaColor]];
                        
                        for (i = 0; i < count; i++) {
                                NSString* propertyName = [NSString stringWithUTF8String:property_getName(properties[i])];
                                NSString* propertyEncoding = [NSString stringWithUTF8String:property_getAttributes(properties[i])];
                                NSError* error = nil;
                                NSRegularExpression* customGetterRegexp = [NSRegularExpression regularExpressionWithPattern:@"(?:^G|,G)([^,]+)" options:0 error:&error];
                                NSTextCheckingResult* customGetterMatch = [customGetterRegexp firstMatchInString:propertyEncoding options:0 range:NSMakeRange(0, propertyEncoding.length)];
                                NSString* getter = propertyName;
                                if (customGetterMatch) {
                                        getter = [propertyEncoding substringWithRange:[customGetterMatch rangeAtIndex:1]];
                                }
                                
                                id propertyValue = nil; // initialized to nil in order to shut down a spurious warning
                                NSString* errorMessage = nil;
                                
                                @try {
                                        propertyValue = [[[[@"[:object| object " stringByAppendingString:getter] stringByAppendingString:@"]"] asBlock] value:object];
                                }
                                @catch (id exception)
                                {
                                        errorMessage = [@"F-Script can't display the value of this property. " stringByAppendingString:FSErrorMessageFromException(exception)];
                                        [view addObject:errorMessage withLabel:propertyName toMatrix:m leaf:YES classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:0];
                                }
                                if (!errorMessage)
                                        ADD_OBJECT_RO(propertyValue, propertyName)
                                        }
                        free(properties);
                }
                if (cls == [cls superclass]) // Defensive programming against flawed class hierarchies with infinite loops.
                        cls = nil;
                else
                        cls = [cls superclass];
        }
        
}

+ (NSArray*)baseClasses
{
        static NSArray *sBaseClasses = nil;
        if (!sBaseClasses) {
                sBaseClasses = [[NSArray alloc] initWithObjects:
                                                                          [FSGenericPointer class],
                                                                          [FSObjectPointer class],
                                                                          [NSAffineTransform class],
                                                                          [NSAlert class],
                                                                          [NSAnimation class],
                                                                          [NSAnimationContext class],
                                                                          [NSAttributedString class],
                                                                          [NSBezierPath class],
                                                                          [NSCell class],
                                                                          [NSCollectionViewItem class],
                                                                          [NSComparisonPredicate class],
                                                                          [NSCompoundPredicate class],
                                                                          [NSController class],
                                                                          [NSCursor class],
                                                                          [NSDockTile class],
                                                                          [NSDocument class],
                                                                          [NSDocumentController class],
                                                                          [NSEntityDescription class],
                                                                          [NSEvent class],
                                                                          [NSExpression class],
                                                                          [NSFetchRequest class],
                                                                          [NSFileWrapper class],
                                                                          [NSFont class],
                                                                          [NSFontDescriptor class],
                                                                          [NSFontManager class],
                                                                          [NSGlyphInfo class],
                                                                          [NSGlyphGenerator class],
                                                                          [NSGradient class],
                                                                          [NSGraphicsContext class],
                                                                          [NSImage class],
                                                                          [NSImageRep class],
                                                                          [NSLayoutManager class],
                                                                          [NSManagedObjectContext class],
                                                                          [NSManagedObjectID class],
                                                                          [NSManagedObjectModel class],
                                                                          [NSMenu class],
                                                                          [NSMenuItem class],
                                                                          [NSOpenGLContext class],
                                                                          [NSOpenGLPixelBuffer class],
                                                                          [NSOpenGLPixelFormat class],
                                                                          [NSPageLayout class],
                                                                          [NSParagraphStyle class],
                                                                          [NSPersistentStoreCoordinator class],
                                                                          [NSPredicateEditorRowTemplate class],
                                                                          [NSPropertyDescription class],
                                                                          [NSResponder class],
                                                                          [NSRulerMarker class],
                                                                          [NSScreen class],
                                                                          [NSShadow class],
                                                                          [NSStatusBar class],
                                                                          [NSStatusItem class],
                                                                          [NSTabViewItem class],
                                                                          [NSTableColumn class],
                                                                          [NSTextAttachment class],
                                                                          [NSTextBlock class],
                                                                          [NSTextContainer class],
                                                                          [NSTextList class],
                                                                          [NSTextTab class],
                                                                          [NSToolbar class],
                                                                          [NSToolbarItem class],
                                                                          [NSTrackingArea class],
                                                                          [NSUndoManager class],
                                                                          [NSATSTypesetter class],
                                                                          nil];
        }
        return sBaseClasses;
}
- (void)addFSGenericPointer:(id)object
{
        FSGenericPointer* o = object;
        NSArray* memoryContent = [o memoryContent];

        if (memoryContent) {
                ADD_CLASS_LABEL(@"FSGenericPointer Info");
                ADD_OBJECT_RO(memoryContent, @"Memory content")
                ADD_OBJECT_NOT_NIL(o, memoryContentUTF8)
        }
}

- (void)addFSObjectPointer:(id)object
{
        FSObjectPointer* o = object;
        NSArray* memoryContent = [o memoryContent];

        if (memoryContent) {
                ADD_CLASS_LABEL(@"FSObjectPointer Info");
                ADD_OBJECT_RO(memoryContent, @"Memory content")
        }
}

- (void)addNSAffineTransform:(id)object
{
        NSAffineTransform* o = object;
        NSAffineTransformStruct s = [o transformStruct];
        ADD_CLASS_LABEL(@"NSAffineTransform Info");
        ADD_NUMBER(s, m11)
        ADD_NUMBER(s,m12)
        ADD_NUMBER(s,m21)
        ADD_NUMBER(s,m22)
        ADD_NUMBER(s,tX)
        ADD_NUMBER(s,tY)
}

- (void)addNSAlert:(id)object
{
        NSAlert* o = object;
        ADD_CLASS_LABEL(@"NSAlert Info");
        ADD_OBJECT(o, accessoryView)
        ADD_ENUM(o, alertStyle, AlertStyle)
        ADD_OBJECTS(o, buttons)
        ADD_OBJECT_NOT_NIL(o, delegate)
        ADD_OBJECT_NOT_NIL(o, helpAnchor)
        ADD_OBJECT(o, icon)
        ADD_STRING(o, informativeText)
        ADD_STRING(o, messageText)
        ADD_BOOL(o, showsHelp)
        ADD_BOOL(o, showsSuppressionButton)
        ADD_OBJECT(o, suppressionButton)
        ADD_OBJECT(o, window)
}

- (void)addNSAnimation:(id)object
{
        if ([object isKindOfClass:[NSViewAnimation class]]) {
                NSViewAnimation* o = object;

                if ([o viewAnimations] != nil) {
                        ADD_CLASS_LABEL(@"NSViewAnimation Info");
                        ADD_OBJECTS(o, viewAnimations)
                }
        }

        NSAnimation* o = object;
        ADD_CLASS_LABEL(@"NSAnimation Info");
        ADD_ENUM(o, animationBlockingMode, AnimationBlockingMode)
        ADD_ENUM(o, animationCurve, AnimationCurve)
        ADD_NUMBER(o, currentProgress)
        ADD_NUMBER(o, currentValue)
        ADD_OBJECT(o, delegate)
        ADD_NUMBER(o, duration)
        ADD_NUMBER(o, frameRate)
        ADD_BOOL(o, isAnimating)
        ADD_OBJECTS(o, progressMarks)
        ADD_OBJECT(o, runLoopModesForAnimating)
}

- (void)addNSAnimationContext:(id)object
{
        NSAnimationContext* o = object;
        ADD_CLASS_LABEL(@"NSAnimationContext Info");
        ADD_NUMBER(o, duration)
}

- (void)addNSAttributedString:(id)object
{
        if ([object isKindOfClass:[NSMutableAttributedString class]]) {
                if ([object isKindOfClass:[NSTextStorage class]]) {
                        NSTextStorage* o = object;
                        ADD_CLASS_LABEL(@"NSTextStorage Info");
                        //ADD_OBJECT(          [o attributeRuns]                      ,@"Attribute runs")
                        ADD_NUMBER(o, changeInLength)
                        ADD_OBJECT_NOT_NIL(o, delegate)
                        ADD_OPTIONS(o, editedMask, TextStorageEditedOptions)
                        ADD_RANGE(o, editedRange)
                        ADD_BOOL(o, fixesAttributesLazily)
                        ADD_OBJECT(o, font)
                        ADD_COLOR(o, foregroundColor)
                        ADD_OBJECTS(o, layoutManagers)
                        // Note: invoking "paragraphs" and retaining the result cause the result of "layoutManager" to become trash !
                }
        }
}

- (void)addNSBezierPath:(id)object
{
        NSBezierPath* o = object;
        ADD_CLASS_LABEL(@"NSBezierPath Info");
        ADD_RECT(o, bounds)
        ADD_RECT(o, controlPointBounds)
        if (![o isEmpty])
                ADD_POINT(o, currentPoint)
        ADD_NUMBER(o, elementCount)
        ADD_NUMBER(o, flatness)
        ADD_BOOL(o, isEmpty)
        ADD_ENUM(o, lineCapStyle, LineCapStyle)
        ADD_ENUM(o, lineJoinStyle, LineJoinStyle)
        ADD_NUMBER(o, lineWidth)
        ADD_NUMBER(o, miterLimit)
        ADD_ENUM(o, windingRule, WindingRule)
}

- (void)addNSCell:(id)object
{
        if ([object isKindOfClass:[NSActionCell class]]) {
                if ([object isKindOfClass:[NSButtonCell class]]) {
                        if ([object isKindOfClass:[NSMenuItemCell class]]) {
                                if ([object isKindOfClass:[NSPopUpButtonCell class]]) {
                                        NSPopUpButtonCell* o = object;
                                        ADD_CLASS_LABEL(@"NSPopUpButtonCell Info");
                                        ADD_BOOL(o, altersStateOfSelectedItem)
                                        ADD_ENUM(o, arrowPosition, PopUpArrowPosition)
                                        ADD_BOOL(o, autoenablesItems)
                                        ADD_NUMBER(o, indexOfSelectedItem)
                                        ADD_OBJECTS(o, itemArray)
                                        ADD_NUMBER(o, numberOfItems)
                                        ADD_OBJECT(o, objectValue)
                                        ADD_ENUM(o, preferredEdge, RectEdge)
                                        ADD_BOOL(o, pullsDown)
                                        ADD_OBJECT(o, selectedItem)
                                        ADD_BOOL(o, usesItemFromMenu)
                                }

                                NSMenuItemCell* o = object;
                                ADD_CLASS_LABEL(@"NSMenuItemCell Info");
                                if ([[o menuItem] image])
                                        ADD_NUMBER(o, imageWidth)
                                ADD_BOOL(o, isHighlighted)
                                if (![[[o menuItem] keyEquivalent] isEqualToString:@""])
                                        ADD_NUMBER(o, keyEquivalentWidth)
                                ADD_OBJECT(o, menuItem)
                                ADD_BOOL(o, needsDisplay)
                                ADD_BOOL(o, needsSizing)
                                ADD_NUMBER(o, stateImageWidth)
                                ADD_NUMBER(o, titleWidth)
                        }

                        NSButtonCell* o = object;
                        ADD_CLASS_LABEL(@"NSButtonCell Info");
                        ADD_OBJECT_NOT_NIL(o, alternateImage)
                        ADD_STRING(o, alternateTitle)
                        ADD_OBJECT(o, attributedAlternateTitle)
                        ADD_OBJECT(o, attributedTitle)
                        ADD_COLOR(o, backgroundColor)
                        ADD_ENUM(o, bezelStyle, BezelStyle)
                        ADD_ENUM(o, gradientType, GradientType)
                        ADD_OPTIONS(o, highlightsBy, CellStyleMask)
                        ADD_BOOL(o, imageDimsWhenDisabled)
                        ADD_ENUM(o, imagePosition, CellImagePosition)
                        ADD_ENUM(o, imageScaling, ImageScaling)
                        ADD_BOOL(o, isTransparent)
                        ADD_OBJECT_NOT_NIL(o, keyEquivalentFont)
                        ADD_OPTIONS( [o keyEquivalentModifierMask] & NSDeviceIndependentModifierFlagsMask, keyEquivalentModifierMask, setKeyEquivalentModifierMask, @"Key equivalent modifier mask")
                        ADD_BOOL(o, showsBorderOnlyWhileMouseInside)
                        ADD_OPTIONS(o, showsStateBy, CellStyleMask)
                        ADD_OBJECT_NOT_NIL(o, sound)
                        ADD_STRING(o, title)
                }
                else if ([object isKindOfClass:[NSDatePickerCell class]]) {
                        NSDatePickerCell* o = object;
                        ADD_CLASS_LABEL(@"NSDatePickerCell Info");
                        ADD_COLOR(o, backgroundColor)
                        ADD_OBJECT(o, calendar)
                        ADD_OPTIONS(o, datePickerElements, DatePickerElementFlags)
                        ADD_ENUM(o, datePickerMode, DatePickerMode)
                        ADD_ENUM(o, datePickerStyle, DatePickerStyle)
                        ADD_OBJECT(o, dateValue)
                        ADD_OBJECT_NOT_NIL(o, delegate)
                        ADD_BOOL(o, drawsBackground)
                        ADD_OBJECT_NOT_NIL(o, locale)
                        ADD_OBJECT(o, maxDate)
                        ADD_OBJECT(o, minDate)
                        ADD_COLOR(o, textColor)
                        ADD_NUMBER(o, timeInterval)
                        ADD_OBJECT(o, timeZone)
                }
                else if ([object isKindOfClass:[NSFormCell class]]) {
                        NSFormCell* o = object;
                        ADD_CLASS_LABEL(@"NSFormCell Info");
                        ADD_OBJECT(o, attributedTitle)
                        ADD_OBJECT_NOT_NIL(o, placeholderAttributedString)
                        ADD_STRING_NOT_NIL(o, placeholderString)
                        ADD_ENUM(o, titleAlignment, TextAlignment)
                        ADD_ENUM(o, titleBaseWritingDirection, WritingDirection)
                        ADD_OBJECT(o, titleFont)
                        ADD_NUMBER(o, titleWidth)
                }
                else if ([object isKindOfClass:[NSLevelIndicatorCell class]]) {
                        NSLevelIndicatorCell* o = object;
                        ADD_CLASS_LABEL(@"NSLevelIndicatorCell Info");
                        ADD_NUMBER(o, criticalValue)
                        ADD_ENUM(o, levelIndicatorStyle, LevelIndicatorStyle)
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                        ADD_NUMBER(o, numberOfMajorTickMarks)
                        ADD_NUMBER(o, numberOfTickMarks)
                        ADD_OBJECT_RO(objectFromTickMarkPosition([o tickMarkPosition],NO), @"Tick mark position")
                        ADD_NUMBER(o, warningValue)
                }
                else if ([object isKindOfClass:[NSPathCell class]]) {
                        NSPathCell* o = object;
                        ADD_CLASS_LABEL(@"NSPathCell Info");
                        ADD_OBJECTS(o, allowedTypes)
                        ADD_COLOR_NOT_NIL([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT(o, delegate)
                        ADD_SEL(o, doubleAction)
                        ADD_OBJECTS(o, pathComponentCells)
                        ADD_ENUM(o, pathStyle, PathStyle)
                        ADD_OBJECT_NOT_NIL(o, placeholderAttributedString)
                        ADD_STRING_NOT_NIL(o, placeholderString)
                        ADD_OBJECT_NOT_NIL(o, URL)
                }
                else if ([object isKindOfClass:[NSSegmentedCell class]]) {
                        NSSegmentedCell* o = object;
                        NSInteger segmentCount = [o segmentCount];
                        ADD_CLASS_LABEL(@"NSSegmentedCell Info");

                        ADD_NUMBER(o, segmentCount)
                        ADD_NUMBER(o, selectedSegment)
                        ADD_ENUM(o, trackingMode, SegmentSwitchTracking)

                       [self processSegmentedItem:o];
                }
                else if ([object isKindOfClass:[NSSliderCell class]]) {
                        NSSliderCell* o = object;
                        ADD_CLASS_LABEL(@"NSSliderCell Info");
                        ADD_BOOL(o, allowsTickMarkValuesOnly)
                        ADD_NUMBER(o, altIncrementValue)
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_10
                        ADD_BOOL(o, isVertical)
                        ADD_NUMBER(o, knobThickness)
#endif
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                        ADD_NUMBER(o, numberOfTickMarks)
                        ADD_ENUM(o, sliderType, SliderType)
                        ADD_OBJECT_RO(objectFromTickMarkPosition([o tickMarkPosition], [(NSSliderCell*)o isVertical] == 1), @"Tick mark position")
                        ADD_RECT(o, trackRect)
                }
                else if ([object isKindOfClass:[NSStepperCell class]]) {
                        NSStepperCell* o = object;
                        ADD_CLASS_LABEL(@"NSStepperCell Info");
                        ADD_BOOL(o, autorepeat)
                        ADD_NUMBER(o, increment)
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                        ADD_BOOL(o, valueWraps)
                }
                else if ([object isKindOfClass:[NSTextFieldCell class]]) {
                        if ([object isKindOfClass:[NSComboBoxCell class]]) {
                                NSComboBoxCell* o = object;
                                ADD_CLASS_LABEL(@"NSComboBoxCell Info");
                                if ([o usesDataSource])
                                        ADD_OBJECT(o, dataSource)
                                ADD_BOOL(o, hasVerticalScroller)
                                ADD_NUMBER(o, indexOfSelectedItem)
                                ADD_SIZE(o, intercellSpacing)
                                ADD_BOOL(o, isButtonBordered)
                                ADD_NUMBER(o, itemHeight)
                                ADD_NUMBER(o, numberOfItems)
                                ADD_NUMBER(o, numberOfVisibleItems)
                                if (![o usesDataSource] && [o indexOfSelectedItem] != -1)
                                        ADD_OBJECT(o, objectValueOfSelectedItem)
                                if (![o usesDataSource])
                                        ADD_OBJECTS(o, objectValues)
                                ADD_BOOL(o, usesDataSource)
                        }
                        else if ([object isKindOfClass:[NSPathComponentCell class]]) {
                                NSPathComponentCell* o = object;
                                ADD_CLASS_LABEL(@"NSPathComponentCell Info");
                                ADD_OBJECT_NOT_NIL(o, image)
                                ADD_OBJECT_NOT_NIL(o, URL)
                        }
                        else if ([object isKindOfClass:[NSSearchFieldCell class]]) {
                                NSSearchFieldCell* o = object;
                                ADD_CLASS_LABEL(@"NSSearchFieldCell Info");
                                ADD_OBJECT(o, cancelButtonCell)
                                ADD_NUMBER(o, maximumRecents)
                                ADD_OBJECTS(o, recentSearches)
                                ADD_OBJECT_NOT_NIL(o, recentsAutosaveName)
                                ADD_OBJECT(o, searchButtonCell)
                                ADD_OBJECT_NOT_NIL(o, searchMenuTemplate)
                                ADD_BOOL(o, sendsSearchStringImmediately)
                                ADD_BOOL(o, sendsWholeSearchString)
                        }
                        else if ([object isKindOfClass:[NSTokenFieldCell class]]) {
                                NSTokenField* o = object;
                                ADD_CLASS_LABEL(@"NSTokenField Info");
                                ADD_NUMBER(o, completionDelay)
                                ADD_OBJECT_NOT_NIL(o, delegate)
                                ADD_OBJECT(o, tokenizingCharacterSet)
                                ADD_ENUM(o, tokenStyle, TokenStyle)
                        }

                        NSTextFieldCell* o = object;
                        ADD_CLASS_LABEL(@"NSTextFieldCell Info");
                        ADD_OBJECTS(o, allowedInputSourceLocales)
                        ADD_COLOR(o, backgroundColor)
                        ADD_ENUM(o, bezelStyle, TextFieldBezelStyle)
                        ADD_BOOL(o, drawsBackground)
                        ADD_OBJECT_NOT_NIL(o, placeholderAttributedString)
                        ADD_STRING_NOT_NIL(o, placeholderString)
                        ADD_COLOR(o, textColor)
                }
        }
        else if ([object isKindOfClass:[NSBrowserCell class]]) {
                NSBrowserCell* o = object;
                ADD_CLASS_LABEL(@"NSBrowserCell Info");
                ADD_OBJECT_NOT_NIL(o, alternateImage)
                ADD_BOOL(o, isLeaf)
                ADD_BOOL(o, isLoaded)
        }
        else if ([object isKindOfClass:[NSImageCell class]]) {
                NSImageCell* o = object;
                ADD_CLASS_LABEL(@"NSImageCell Info");
                ADD_ENUM(o, imageAlignment, ImageAlignment)
                ADD_ENUM(o, imageScaling, ImageScaling)
        }
        else if ([object isKindOfClass:[NSTextAttachmentCell class]]) {
                NSTextAttachmentCell* o = object;
                ADD_CLASS_LABEL(@"NSTextAttachmentCell Info");
                ADD_OBJECT(o, attachment)
                ADD_POINT(o, cellBaselineOffset)
                ADD_SIZE(o, cellSize)
                ADD_BOOL(o, wantsToTrackMouse)
        }

        NSCell* o = object;
        ADD_CLASS_LABEL(@"NSCell Info");
        ADD_BOOL(o, acceptsFirstResponder)
        ADD_SEL_NOT_NULL([o action], @"Action")
        ADD_ENUM(o, alignment, TextAlignment)
        ADD_BOOL(o, allowsEditingTextAttributes)
        ADD_BOOL(o, allowsMixedState)
        ADD_BOOL(o, allowsUndo)
        //ADD_OBJECT(              [o attributedStringValue]              ,@"Attributed string value")
        ADD_ENUM(o, backgroundStyle, BackgroundStyle)
        ADD_ENUM(o, baseWritingDirection, WritingDirection)
        ADD_SIZE(o, cellSize)
        ADD_ENUM(o, controlSize, ControlSize)
        ADD_ENUM(o, controlTint, ControlTint)
        ADD_OBJECT_NOT_NIL(o, controlView)
        ADD_ENUM(o, focusRingType, FocusRingType)
        ADD_OBJECT(o, font)
        ADD_OBJECT_NOT_NIL(o, formatter)
        ADD_OBJECT_NOT_NIL(o, image)
        if ([(NSCell*)o type] == NSTextCellType)
                ADD_BOOL(o, importsGraphics)
        ADD_ENUM(o, interiorBackgroundStyle, BackgroundStyle)
        ADD_BOOL(o, isBezeled)
        ADD_BOOL(o, isBordered)
        ADD_BOOL(o, isContinuous)
        ADD_BOOL(o, isEditable)
        ADD_BOOL(o, isEnabled)
        ADD_BOOL(o, isHighlighted)
        ADD_BOOL(o, isOpaque)
        ADD_BOOL(o, isScrollable)
        ADD_BOOL(o, isSelectable)
        if ([[o keyEquivalent] length] != 0)
                ADD_STRING(o, keyEquivalent)
        ADD_ENUM(o, lineBreakMode, LineBreakMode)
        ADD_OBJECT_NOT_NIL(o, menu)
        if ([[o mnemonic] length] != 0)
                ADD_STRING(o, mnemonic)
        if ([o mnemonicLocation] != NSNotFound)
                ADD_NUMBER(o, mnemonicLocation)
        ADD_ENUM(o, nextState, CellStateValue)
        //ADD_OBJECT(              [o objectValue]                        ,@"Object value")
        ADD_BOOL(o, refusesFirstResponder)
        ADD_OBJECT_NOT_NIL(o, representedObject)
        ADD_BOOL(o, sendsActionOnEndEditing)
        ADD_BOOL(o, showsFirstResponder)
        ADD_ENUM(o, state, CellStateValue)
        ADD_NUMBER(o, tag)
        ADD_OBJECT_NOT_NIL(o, target)
        ADD_OPTIONS(o, type, CellType)
        ADD_BOOL(o, wantsNotificationForMarkedText)
        ADD_BOOL(o, wraps)
}

- (void)addNSCollectionViewItem:(id)object
{
        NSCollectionViewItem* o = object;
        ADD_CLASS_LABEL(@"NSCollectionViewItem Info");
        ADD_OBJECT(o, collectionView)
        ADD_BOOL(o, isSelected)
        ADD_OBJECT(o, representedObject)
        ADD_OBJECT_NOT_NIL(o, view)
}

- (void)addNSComparisonPredicate:(id)object
{
        NSComparisonPredicate* o = object;
        ADD_CLASS_LABEL(@"NSComparisonPredicate Info");
        ADD_ENUM(o, comparisonPredicateModifier, ComparisonPredicateModifier)
        ADD_SEL_NOT_NULL([o customSelector], @"Custom selector")
        ADD_OBJECT(o, leftExpression)
        ADD_ENUM(o, predicateOperatorType, PredicateOperatorType)
        ADD_OBJECT(o, rightExpression)
}

- (void)addNSCompoundPredicate:(id)object
{
        NSCompoundPredicate* o = object;
        ADD_CLASS_LABEL(@"NSCompoundPredicate Info")
        ADD_ENUM(o, compoundPredicateType, CompoundPredicateType)
        ADD_OBJECTS(o, subpredicates)
}

- (void)addNSController:(id)object
{
        if ([object isKindOfClass:[NSObjectController class]]) {
                if ([object isKindOfClass:[NSArrayController class]]) {
                        if ([object isKindOfClass:[NSDictionaryController class]]) {
                                NSDictionaryController* o = object;
                                ADD_CLASS_LABEL(@"NSDictionaryController Info");
                                ADD_OBJECTS(o, excludedKeys)
                                ADD_OBJECTS(o, includedKeys)
                                ADD_OBJECT(o, initialKey)
                                ADD_OBJECT(o, initialValue)
                                ADD_DICTIONARY(o, localizedKeyDictionary)
                                ADD_OBJECT_NOT_NIL(o, localizedKeyTable)
                        }

                        NSArrayController* o = object;
                        ADD_CLASS_LABEL(@"NSArrayController Info");
                        ADD_BOOL(o, alwaysUsesMultipleValuesMarker)
                        ADD_BOOL(o, automaticallyRearrangesObjects)
                        ADD_OBJECTS(o, automaticRearrangementKeyPaths)
                        ADD_BOOL(o, avoidsEmptySelection)
                        ADD_BOOL(o, clearsFilterPredicateOnInsertion)
                        ADD_BOOL(o, canInsert)
                        ADD_BOOL(o, canSelectNext)
                        ADD_BOOL(o, canSelectPrevious)
                        ADD_OBJECT_NOT_NIL(o, filterPredicate)
                        ADD_BOOL(o, preservesSelection)
                        if ([o selectionIndex] != NSNotFound)
                                ADD_NUMBER(o, selectionIndex)
                        ADD_OBJECT(o, selectionIndexes)
                        ADD_BOOL(o, selectsInsertedObjects)
                        ADD_OBJECTS(o, sortDescriptors)
                }
                else if ([object isKindOfClass:[NSTreeController class]]) {
                        NSTreeController* o = object;
                        ADD_CLASS_LABEL(@"NSTreeController Info");
                        ADD_BOOL(o, alwaysUsesMultipleValuesMarker)
                        ADD_BOOL(o, avoidsEmptySelection)
                        ADD_BOOL(o, canAddChild)
                        ADD_BOOL(o, canInsert)
                        ADD_BOOL(o, canInsertChild)
                        ADD_OBJECT(o, childrenKeyPath)
                        ADD_OBJECT(o, countKeyPath)
                        ADD_OBJECT(o, leafKeyPath)
                        ADD_BOOL(o, preservesSelection)
                        ADD_OBJECTS(o, selectedNodes)
                        ADD_OBJECTS(o, selectedObjects)
                        ADD_OBJECTS(o, selectionIndexPaths)
                        ADD_BOOL(o, selectsInsertedObjects)
                        ADD_OBJECTS(o, sortDescriptors)
                }

                NSObjectController* o = object;
                ADD_CLASS_LABEL(@"NSObjectController Info");
                ADD_BOOL(o, automaticallyPreparesContent)
                ADD_BOOL(o, canAdd)
                ADD_BOOL(o, canRemove)
                ADD_OBJECT(o, content)
                if ([o managedObjectContext] != nil) // Do not work when there is no managedObjectContext associated with the object
                        ADD_OBJECT_NOT_NIL(o, defaultFetchRequest)
                ADD_OBJECT_NOT_NIL(o, entityName)
                ADD_OBJECT_NOT_NIL(o, fetchPredicate)
                ADD_BOOL(o, isEditable)
                ADD_OBJECT_NOT_NIL(o, managedObjectContext)
                ADD_OBJECT(o, objectClass)
                ADD_OBJECTS(o, selectedObjects)
                ADD_OBJECT(o, selection)
                ADD_BOOL(o, usesLazyFetching)
        }
        else if ([object isKindOfClass:[NSUserDefaultsController class]]) {
                NSUserDefaultsController* o = object;
                ADD_CLASS_LABEL(@"NSUserDefaultsController Info");
                ADD_BOOL(o, appliesImmediately)
                ADD_OBJECT(o, defaults)
                ADD_BOOL(o, hasUnappliedChanges)
                ADD_OBJECT(o, initialValues)
                ADD_OBJECT(o, values)
        }

        NSController* o = object;
        ADD_CLASS_LABEL(@"NSController Info");
        ADD_BOOL(o, isEditing)
}

- (void)addNSCursor:(id)object
{
        NSCursor* o = object;
        ADD_CLASS_LABEL(@"NSCursor Info");
        ADD_POINT(o, hotSpot)
        ADD_OBJECT(o, image)
        ADD_BOOL(o, isSetOnMouseEntered)
        ADD_BOOL(o, isSetOnMouseExited)
}

- (void)addNSDockTile:(id)object
{
        NSDockTile* o = object;
        ADD_CLASS_LABEL(@"NSDockTile Info");
        ADD_OBJECT(o, badgeLabel)
        ADD_OBJECT(o, contentView)
        ADD_OBJECT(o, owner)
        ADD_BOOL(o, showsApplicationBadge)
        ADD_SIZE(o, size)
}

- (void)addNSDocument:(id)object
{
        NSDocument* o = object;
        ADD_CLASS_LABEL(@"NSDocument Info");
        ADD_OBJECT_NOT_NIL(o, autosavedContentsFileURL)
        ADD_OBJECT(o, autosavingFileType)
        ADD_OBJECT(o, displayName)
        ADD_OBJECT(o, fileModificationDate)
        ADD_BOOL(o, fileNameExtensionWasHiddenInLastRunSavePanel)
        ADD_OBJECT(o, fileType)
        ADD_OBJECT(o, fileTypeFromLastRunSavePanel)
        ADD_OBJECT_NOT_NIL(o, fileURL)
        ADD_BOOL(o, hasUnautosavedChanges)
        ADD_BOOL(o, hasUndoManager)
        ADD_BOOL(o, isDocumentEdited)
        ADD_BOOL(o, keepBackupFile)
        ADD_OBJECT(o, fileTypeFromLastRunSavePanel)
        ADD_OBJECT(o, printInfo)
        ADD_BOOL(o, shouldRunSavePanelWithAccessoryView)
        ADD_OBJECTS(o, windowControllers)
        ADD_OBJECT(o, windowForSheet)
        ADD_OBJECT(o, windowNibName)
}

- (void)addNSDocumentController:(id)object
{
        NSDocumentController* o = object;
        ADD_CLASS_LABEL(@"NSDocumentController Info");
        ADD_NUMBER(o, autosavingDelay)
        ADD_OBJECT(o, currentDirectory)
        ADD_OBJECT(o, currentDocument)
        ADD_OBJECT(o, defaultType)
        ADD_OBJECTS(o, documentClassNames)
        ADD_OBJECTS(o, documents)
        ADD_BOOL(o, hasEditedDocuments)
        ADD_NUMBER(o, maximumRecentDocumentCount)
        ADD_OBJECT(o, recentDocumentURLs)
}

- (void)addNSEntityDescription:(id)object
{
        NSEntityDescription* o = object;
        ADD_CLASS_LABEL(@"NSEntityDescription Info");
        ADD_DICTIONARY(o, attributesByName)
        ADD_BOOL(o, isAbstract)
        ADD_OBJECT(o, managedObjectClassName)
        ADD_OBJECT(o, managedObjectModel)
        ADD_OBJECT(o, name)
        ADD_DICTIONARY(o, relationshipsByName)
        if ([[o subentities] count] != 0) {
                ADD_DICTIONARY(o, subentitiesByName)
        }
        ADD_OBJECT(o, superentity)
        ADD_DICTIONARY(o, userInfo)
}

- (void)addNSEvent:(id)object
{
        NSEvent* o = object;
        NSEventType type = [o type];
        ADD_CLASS_LABEL(@"NSEvent Info");

        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype)) {
                ADD_NUMBER(o, absoluteX)
                ADD_NUMBER(o, absoluteY)
                ADD_NUMBER(o, absoluteZ)
                ADD_OPTIONS(o, buttonMask, EventButtonMask)
        }
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp)
                ADD_NUMBER(o, buttonNumber)

        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype))
                ADD_NUMBER(o, capabilityMask)

        if (type == NSKeyDown || type == NSKeyUp) {
                ADD_OBJECT(o, characters)
                ADD_OBJECT(o, charactersIgnoringModifiers)
        }
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp)
                ADD_NUMBER(o, clickCount)
        if (type == NSAppKitDefined || type == NSSystemDefined || type == NSApplicationDefined) {
                ADD_NUMBER(o, data1)
                ADD_NUMBER(o, data2)
        }
        if (type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) {
                ADD_NUMBER(o, deltaX)
                ADD_NUMBER(o, deltaY)
                ADD_NUMBER(o, deltaZ)
        }

        if (type == NSTabletPoint || type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && ([object subtype] == NSTabletProximityEventSubtype || [object subtype] == NSTabletPointEventSubtype)))
                ADD_NUMBER(o, deviceID)
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel || type == NSMouseEntered || type == NSMouseExited || type == NSCursorUpdate)
                ADD_NUMBER(o, eventNumber)
        if (type == NSKeyDown)
                ADD_BOOL(o, isARepeat)
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype))
                ADD_BOOL(o, isEnteringProximity)
        if (type == NSKeyDown || type == NSKeyUp)
                ADD_NUMBER(o, keyCode)
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel)
                ADD_POINT(o, locationInWindow)
        ADD_OPTIONS(EventModifierFlags, [o modifierFlags] & NSDeviceIndependentModifierFlagsMask, modifierFlags, setModifierFlags, @"Modifier flags")
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype)) {
                ADD_NUMBER(o, pointingDeviceID)
                ADD_NUMBER(o, pointingDeviceSerialNumber)
                ADD_ENUM(o, pointingDeviceType, PointingDeviceType)
        }
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel)
                ADD_NUMBER(o, pressure)
        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype))
                ADD_NUMBER(o, rotation)
        if (type == NSAppKitDefined || type == NSSystemDefined || type == NSApplicationDefined || type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel)
                ADD_ENUM(o, subtype, EventSubtype)
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype)) {
                ADD_NUMBER(o, systemTabletID)
                ADD_NUMBER(o, tabletID)
        }
        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype)) {
                ADD_NUMBER(o, tangentialPressure)
                ADD_POINT(o, tilt)
        }
        ADD_NUMBER(o, timestamp)
        if (type == NSMouseEntered || type == NSMouseExited || type == NSCursorUpdate) {
                ADD_OBJECT(o, trackingArea)
                ADD_NUMBER(o, trackingNumber)
        }
        ADD_ENUM(o, type, EventType)
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype))
                ADD_NUMBER(o, uniqueID)
        if (type == NSMouseEntered || type == NSMouseExited || type == NSCursorUpdate) {
                void* userData = [o userData];
                if (userData)
                        ADD_POINTER([o userData], @"User data")
        }
        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype))
                ADD_OBJECT(o, vendorDefined)
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype)) {
                ADD_NUMBER(o, vendorID)
                ADD_NUMBER(o, vendorPointingDeviceType)
        }
        if (type != NSPeriodic)
                ADD_OBJECT(o, window)
}

- (void)addNSExpression:(id)object
{
        ADD_CLASS_LABEL(@"NSExpression Info");

        @try { ADD_OBJECTS(o, arguments); } @catch (id exception) {}
        @try { ADD_OBJECT(o, collection); } @catch (id exception) {}
        @try { ADD_OBJECT(o, constantValue); } @catch (id exception) {}
        @try { ADD_ENUM(o, expressionType, ExpressionType); } @catch (id exception) {}
        @try { ADD_STRING(o, function); } @catch (id exception) {}
        @try { ADD_STRING(o, keyPath); } @catch (id exception) {}
        @try { ADD_OBJECT(o, leftExpression); } @catch (id exception) {}
        @try { ADD_OBJECT(o, operand); } @catch (id exception) {}
        @try { ADD_OBJECT(o, predicate); } @catch (id exception) {}
        @try { ADD_OBJECT(o, rightExpression); } @catch (id exception) {}
        @try { ADD_STRING(o, variable); } @catch (id exception) {}
                
}

- (void)addNSFetchRequest:(id)object
{
        NSFetchRequest* o = object;
        ADD_CLASS_LABEL(@"NSFetchRequest Info");
        ADD_OBJECTS(o, affectedStores)
        ADD_OBJECT(o, entity)
        ADD_NUMBER(o, fetchLimit)
        ADD_BOOL(o, includesPropertyValues)
        ADD_BOOL(o, includesSubentities)
        ADD_OBJECT(o, predicate)
        ADD_OBJECTS(o, relationshipKeyPathsForPrefetching)
        ADD_ENUM(o, resultType, FetchRequestResultType)
        ADD_BOOL(o, returnsObjectsAsFaults)
        ADD_OBJECTS(o, sortDescriptors)
}

- (void)addNSFileWrapper:(id)object
{
        NSFileWrapper* o = object;
        ADD_CLASS_LABEL(@"NSFileWrapper Info");
        ADD_DICTIONARY(o, fileAttributes)
        ADD_OBJECT(o, filename)
        ADD_OBJECT_NOT_NIL(o, icon)
        ADD_BOOL(o, isDirectory)
        ADD_BOOL(o, isRegularFile)
        ADD_BOOL(o, isSymbolicLink)
        ADD_OBJECT_NOT_NIL(o, preferredFilename)
        if ([o isSymbolicLink])
                ADD_OBJECT_NOT_NIL(o, symbolicLinkDestination)
}

- (void)addNSFont:(id)object
{
        NSFont* o = object;
        ADD_CLASS_LABEL(@"NSFont Info");
        ADD_NUMBER(o, ascender)
        ADD_RECT(o, boundingRectForFont)
        ADD_NUMBER(o, capHeight)
        ADD_OBJECT(o, coveredCharacterSet)
        ADD_NUMBER(o, descender)
        ADD_OBJECT(o, displayName)
        ADD_OBJECT(o, familyName)
        ADD_OBJECT(o, fontDescriptor)
        ADD_OBJECT(o, fontName)
        ADD_BOOL(o, isFixedPitch)
        ADD_NUMBER(o, italicAngle)
        ADD_NUMBER(o, leading)

        const CGFloat* matrix = [o matrix];
        NSString* matrixString = [NSString stringWithFormat:@"[%g %g %g %g %g %g]", (double)(matrix[0]), (double)(matrix[1]), (double)(matrix[2]), (double)(matrix[3]), (double)(matrix[4]), (double)(matrix[5])];
        [view addObject:matrixString withLabel:@"Matrix" toMatrix:m leaf:YES classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:0];

        ADD_SIZE(o, maximumAdvancement)
        ADD_ENUM(o, mostCompatibleStringEncoding, StringEncoding)
        ADD_NUMBER(o, numberOfGlyphs)
        ADD_NUMBER(o, pointSize)
        ADD_OBJECT(o, printerFont)
        ADD_ENUM(o, renderingMode, FontRenderingMode)
        ADD_OBJECT_NOT_NIL(o, screenFont)
        ADD_NUMBER(o, underlinePosition)
        ADD_NUMBER(o, underlineThickness)
        ADD_NUMBER(o, xHeight)
}

- (void)addNSFontDescriptor:(id)object
{
        NSFontDescriptor* o = object;
        ADD_CLASS_LABEL(@"NSFontDescriptor Info");
        ADD_DICTIONARY(o, fontAttributes)
        ADD_OBJECT(o, matrix)
        ADD_NUMBER(o, pointSize)
        ADD_OBJECT(o, postscriptName)
        ADD_NUMBER(o, symbolicTraits)
}

- (void)addNSFontManager:(id)object
{
        NSFontManager* o = object;
        ADD_CLASS_LABEL(@"NSFontManager Info");
        ADD_SEL(o, action)
        ADD_OBJECTS(o, availableFontFamilies)
        ADD_OBJECTS(o, availableFonts)
        ADD_OBJECTS(o, collectionNames)
        ADD_OBJECT_NOT_NIL(o, delegate)
        ADD_BOOL(o, isEnabled)
        ADD_BOOL(o, isMultiple)
        ADD_OBJECT(o, selectedFont)
        ADD_OBJECT(o, target)
}

- (void)addNSGlyphInfo:(id)object
{
        NSGlyphInfo* o = object;
        ADD_CLASS_LABEL(@"NSGlyphInfo Info");
        ADD_ENUM(o, characterCollection, CharacterCollection)
        if ([o characterIdentifier])
                ADD_NUMBER(o, characterIdentifier);
        ADD_OBJECT_NOT_NIL(o, glyphName)
}

- (void)addNSGlyphGenerator:(id)object
{
        //NSGlyphGenerator *o = object;
        //ADD_CLASS_LABEL(@"NSGlyphGenerator Info");
}

- (void)addNSGradient:(id)object
{
        NSGradient* o = object;
        ADD_CLASS_LABEL(@"NSGradient Info");
        ADD_OBJECT_NOT_NIL(o, colorSpace)
        ADD_NUMBER(o, numberOfColorStops)
}


- (void)addNSGraphicsContext:(id)object
{
        NSGraphicsContext* o = object;
        ADD_CLASS_LABEL(@"NSGraphicsContext Info");
        ADD_DICTIONARY(o, attributes)
        ADD_ENUM(o, colorRenderingIntent, ColorRenderingIntent)
        ADD_ENUM(o, compositingOperation, CompositingOperation)
        ADD_POINTER([o graphicsPort], @"Graphics port")
        ADD_ENUM(o, imageInterpolation, ImageInterpolation)
        ADD_BOOL(o, isDrawingToScreen)
        ADD_BOOL(o, isFlipped)
        ADD_POINT(o, patternPhase)
        ADD_BOOL(o, shouldAntialias)
}

- (void)addNSImage:(id)object
{
        NSImage* o = object;
        ADD_CLASS_LABEL(@"NSImage Info");
        ADD_RECT(o, alignmentRect)
        ADD_COLOR(o, backgroundColor)
        ADD_BOOL(o, cacheDepthMatchesImageDepth)
        ADD_ENUM(o, cacheMode, ImageCacheMode)
        ADD_OBJECT_NOT_NIL(o, delegate)
        ADD_BOOL(o, isCachedSeparately)
        ADD_BOOL(o, isDataRetained)
        ADD_BOOL(o, isFlipped)
        ADD_BOOL(o, isTemplate)
        ADD_BOOL(o, isValid)
        ADD_BOOL(o, matchesOnMultipleResolution)
        ADD_OBJECT_NOT_NIL(o, name)
        ADD_BOOL(o, prefersColorMatch)
        ADD_OBJECTS(o, representations)
        ADD_BOOL(o, scalesWhenResized)
        ADD_SIZE(o, size)
        ADD_BOOL(o, usesEPSOnResolutionMismatch)
}

- (void)addNSImageRep:(id)object
{
        if ([object isKindOfClass:[NSBitmapImageRep class]]) {
                NSBitmapImageRep* o = object;
                ADD_CLASS_LABEL(@"NSBitmapImageRep Info");
                ADD_OPTIONS(o, bitmapFormat, BitmapFormat)
                ADD_NUMBER(o, bitsPerPixel)
                ADD_NUMBER(o, bytesPerPlane)
                ADD_NUMBER(o, bytesPerRow)
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageColorSyncProfileData], @"ColorSync profile data")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageCompressionFactor], @"Compression factor")
                {
                        id compressionMethod = [o valueForProperty:NSImageCompressionMethod];
                        if ([compressionMethod isKindOfClass:[NSNumber class]])
                                ADD_ENUM(TIFFCompression, [[o valueForProperty:NSImageCompressionMethod] longValue], imageCompressionMethod, setImageCompressionMethod, @"Compression method")
                }
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageCurrentFrame], @"Current frame")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageCurrentFrameDuration], @"Current frame duration")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageDitherTransparency], @"Dither transparency")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageEXIFData], @"EXIF data")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageFallbackBackgroundColor], @"Fallback background color")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageFrameCount], @"Frame count")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageGamma], @"Gamma")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageInterlaced], @"Interlaced")
                ADD_BOOL(o, isPlanar)
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageLoopCount], @"Loop count")
                ADD_NUMBER(o, numberOfPlanes)
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageProgressive], @"Progressive")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageRGBColorTable], @"RGB color table")
                ADD_NUMBER(o, samplesPerPixel)
        }
        else if ([object isKindOfClass:[NSCIImageRep class]]) {
                NSCIImageRep* o = object;
                ADD_CLASS_LABEL(@"NSCIImageRep Info");
                ADD_OBJECT(o, CIImage)
        }
        else if ([object isKindOfClass:[NSCustomImageRep class]]) {
                NSCustomImageRep* o = object;
                ADD_CLASS_LABEL(@"NSCustomImageRep Info");
                ADD_OBJECT(o, delegate)
                ADD_SEL(o, drawSelector)
        }
        else if ([object isKindOfClass:[NSEPSImageRep class]]) {
                NSEPSImageRep* o = object;
                ADD_CLASS_LABEL(@"NSEPSImageRep Info");
                ADD_RECT(o, boundingBox)
        }
        else if ([object isKindOfClass:[NSPDFImageRep class]]) {
                NSPDFImageRep* o = object;
                ADD_CLASS_LABEL(@"NSPDFImageRep Info");
                ADD_RECT(o, bounds)
                ADD_NUMBER(o, currentPage)
                ADD_NUMBER(o, pageCount)
        }
        else if ([object isKindOfClass:[NSPICTImageRep class]]) {
                NSPICTImageRep* o = object;
                ADD_CLASS_LABEL(@"NSPICTImageRep Info");
                ADD_RECT(o, boundingBox)
        }

        NSImageRep* o = object;
        ADD_CLASS_LABEL(@"NSImageRep Info");
        ADD_NUMBER(o, bitsPerSample)
        ADD_OBJECT(o, colorSpaceName)
        ADD_BOOL(o, hasAlpha)
        ADD_BOOL(o, isOpaque)
        ADD_NUMBER(o, pixelsHigh)
        ADD_NUMBER(o, pixelsWide)
        ADD_SIZE(o, size)
}

- (void)addNSLayoutManager:(id)object
{
        NSLayoutManager* o = object;
        ADD_CLASS_LABEL(@"NSLayoutManager Info");
        ADD_BOOL(o, allowsNonContiguousLayout)
        ADD_BOOL(o, backgroundLayoutEnabled)
        ADD_ENUM(o, defaultAttachmentScaling, ImageScaling)
        ADD_OBJECT_NOT_NIL(o, delegate)
        ADD_RECT(o, extraLineFragmentRect)
        ADD_OBJECT_NOT_NIL(o, extraLineFragmentTextContainer)
        ADD_RECT(o, extraLineFragmentUsedRect)
        ADD_OBJECT(o, firstTextView)
        ADD_NUMBER(o, firstUnlaidCharacterIndex)
        ADD_NUMBER(o, firstUnlaidGlyphIndex)
        ADD_OBJECT(o, glyphGenerator)
        ADD_BOOL(o, hasNonContiguousLayout)
        ADD_NUMBER(o, hyphenationFactor)
        ADD_OPTIONS(o, layoutOptions, GlyphStorageLayoutOptions)
        ADD_BOOL(o, showsControlCharacters)
        ADD_BOOL(o, showsInvisibleCharacters)
        ADD_OBJECTS(o, textContainers)
        ADD_OBJECT(o, textStorage)
        ADD_OBJECT(o, textViewForBeginningOfSelection)
        ADD_OBJECT(o, typesetter)
        ADD_ENUM(o, typesetterBehavior, TypesetterBehavior)
        ADD_BOOL(o, usesFontLeading)
        ADD_BOOL(o, usesScreenFonts)
}

- (void)addNSManagedObjectContext:(id)object
{
        NSManagedObjectContext* o = object;
        ADD_CLASS_LABEL(@"NSManagedObjectContext Info");
        ADD_OBJECT(o, deletedObjects)
        ADD_BOOL(o, hasChanges)
        ADD_OBJECT(o, insertedObjects)
        ADD_OPTIONS(o, mergePolicy, MergePolicyMarker)
        ADD_OBJECT(o, persistentStoreCoordinator)
        ADD_BOOL(o, propagatesDeletesAtEndOfEvent)
        ADD_OBJECT(o, registeredObjects)
        ADD_BOOL(o, retainsRegisteredObjects)
        ADD_NUMBER(o, stalenessInterval)
        ADD_BOOL(o, tryLock)
        ADD_OBJECT(o, undoManager)
        ADD_OBJECT(o, updatedObjects)
}

- (void)addNSManagedObjectID:(id)object
{
        NSManagedObjectID* o = object;
        ADD_CLASS_LABEL(@"NSManagedObjectID Info");
        ADD_OBJECT(o, entity)
        ADD_BOOL(o, isTemporaryID)
        ADD_OBJECT(o, persistentStore)
        ADD_OBJECT(o, URIRepresentation)
}

- (void)addNSManagedObjectModel:(id)object
{
        NSManagedObjectModel* o = object;
        ADD_CLASS_LABEL(@"NSManagedObjectModel Info");
        ADD_OBJECTS(o, configurations)
        ADD_DICTIONARY(o, entitiesByName)
        ADD_DICTIONARY(o, fetchRequestTemplatesByName)
        ADD_OBJECTS([[o versionIdentifiers] allObjects], @"Version identifiers")
}

- (void)addNSMenu:(id)object
{
        NSMenu* o = object;
        ADD_CLASS_LABEL(@"NSMenu Info");
        ADD_BOOL(o, autoenablesItems)
        ADD_OBJECT_NOT_NIL(o, delegate)
        ADD_OBJECT_NOT_NIL(o, highlightedItem)
        ADD_BOOL(o, isTornOff)
        ADD_OBJECTS(o, itemArray)
        ADD_BOOL(o, menuChangedMessagesEnabled)
        ADD_BOOL(o, showsStateColumn)
        ADD_OBJECT_NOT_NIL(o, supermenu)
        ADD_STRING(o, title)
}

- (void)addNSMenuItem:(id)object
{
        NSMenuItem* o = object;
        ADD_CLASS_LABEL(@"NSMenuItem Info")
        ADD_SEL(o, action)
        ADD_OBJECT_NOT_NIL(o, attributedTitle)
        ADD_BOOL(o, hasSubmenu)
        ADD_OBJECT_NOT_NIL(o, image)
        ADD_NUMBER(o, indentationLevel)
        ADD_BOOL(o, isAlternate)
        ADD_BOOL(o, isEnabled)
        ADD_BOOL(o, isHidden)
        ADD_BOOL(o, isHiddenOrHasHiddenAncestor)
        ADD_BOOL(o, isHighlighted)
        ADD_BOOL(o, isSeparatorItem)
        ADD_OBJECT(o, keyEquivalent)
        ADD_OPTIONS(EventModifierFlags, [o keyEquivalentModifierMask] & NSDeviceIndependentModifierFlagsMask, keyEquivalentModifierMask, setKeyEquivalentModifierMask, @"Key equivalent modifier mask")
        ADD_OBJECT(o, menu)
        ADD_OBJECT_NOT_NIL(o, mixedStateImage)
        ADD_OBJECT_NOT_NIL(o, offStateImage)
        ADD_OBJECT_NOT_NIL(o, onStateImage)
        ADD_OBJECT_NOT_NIL(o, representedObject)
        ADD_ENUM(o, state, CellStateValue)
        ADD_OBJECT_NOT_NIL(o, submenu)
        ADD_NUMBER(o, tag)
        ADD_OBJECT_NOT_NIL(o, target)
        ADD_STRING(o, title)
        ADD_OBJECT_NOT_NIL(o, toolTip)
        ADD_OBJECT(o, userKeyEquivalent)
        ADD_OBJECT_NOT_NIL(o, view)
}

- (void)addNSOpenGLContext:(id)object
{
        NSOpenGLContext* o = object;
        ADD_CLASS_LABEL(@"NSOpenGLContext Info");
        ADD_POINTER([o CGLContextObj], @"CGL context obj")
        ADD_NUMBER(o, currentVirtualScreen)
        ADD_OBJECT_NOT_NIL(o, pixelBuffer)
        ADD_NUMBER(o, pixelBufferCubeMapFace)
        ADD_NUMBER(o, pixelBufferMipMapLevel)
        ADD_OBJECT_NOT_NIL(o, view)
}

- (void)addNSOpenGLPixelBuffer:(id)object
{
        NSOpenGLPixelBuffer* o = object;
        ADD_CLASS_LABEL(@"NSOpenGLPixelBuffer Info");
        ADD_NUMBER(o, pixelsHigh)
        ADD_NUMBER(o, pixelsWide)
        ADD_NUMBER(o, textureInternalFormat)
        ADD_NUMBER(o, textureMaxMipMapLevel)
        ADD_NUMBER(o, textureTarget)
}

- (void)addNSOpenGLPixelFormat:(id)object
{
        NSOpenGLPixelFormat* o = object;
        ADD_CLASS_LABEL(@"NSOpenGLPixelFormat Info");
        ADD_POINTER([o CGLPixelFormatObj], @"CGL pixel format obj")
        ADD_NUMBER(o, numberOfVirtualScreens)
}

- (void)addNSPageLayout:(id)object
{
        NSPageLayout* o = object;

        if ([[o accessoryControllers] count] > 0 || [o printInfo] != nil) {
                ADD_CLASS_LABEL(@"NSPageLayout Info");
                ADD_OBJECTS(o, accessoryControllers)
                ADD_OBJECT_NOT_NIL(o, printInfo)
        }
}

- (void)addNSParagraphStyle:(id)object
{
        NSParagraphStyle* o = object;
        ADD_CLASS_LABEL(@"NSParagraphStyle Info")
        ADD_ENUM(o, alignment, TextAlignment)
        ADD_ENUM(o, baseWritingDirection, WritingDirection)
        ADD_NUMBER(o, defaultTabInterval)
        ADD_NUMBER(o, firstLineHeadIndent)
        ADD_NUMBER(o, headerLevel)
        ADD_NUMBER(o, headIndent)
        ADD_NUMBER(o, hyphenationFactor)
        ADD_ENUM(o, lineBreakMode, LineBreakMode)
        ADD_NUMBER(o, lineHeightMultiple)
        ADD_NUMBER(o, lineSpacing)
        ADD_NUMBER(o, maximumLineHeight)
        ADD_NUMBER(o, minimumLineHeight)
        ADD_NUMBER(o, paragraphSpacing)
        ADD_NUMBER(o, paragraphSpacingBefore)
        ADD_OBJECTS(o, tabStops)
        ADD_NUMBER(o, tailIndent)
        ADD_OBJECTS(o, textBlocks)
        ADD_OBJECTS(o, textLists)
        ADD_NUMBER(o, tighteningFactorForTruncation)
}

- (void)addNSPersistentStoreCoordinator:(id)object
{
        NSPersistentStoreCoordinator* o = object;
        ADD_CLASS_LABEL(@"NSPersistentStoreCoordinator Info")
        ADD_OBJECT(o, managedObjectModel)
        ADD_OBJECTS(o, persistentStores)
}

- (void)addNSPredicateEditorRowTemplate:(id)object
{
        NSPredicateEditorRowTemplate* o = object;
        ADD_CLASS_LABEL(@"NSPredicateEditorRowTemplate Info")
        ADD_OBJECTS(o, compoundTypes)
        ADD_OBJECTS(o, leftExpressions)
        ADD_ENUM(o, modifier, ComparisonPredicateModifier)
        ADD_OBJECTS(o, operators)
        ADD_OPTIONS(o, options, ComparisonPredicateOptions)
        ADD_ENUM(o, rightExpressionAttributeType, AttributeType)
        ADD_OBJECTS(o, rightExpressions)
        ADD_OBJECTS(o, templateViews)
}

- (void)addNSPropertyDescription:(id)object
{
        if ([object isKindOfClass:[NSAttributeDescription class]]) {
                NSAttributeDescription* o = object;
                ADD_CLASS_LABEL(@"NSAttributeDescription Info")
                ADD_ENUM(o, attributeType, AttributeType)
                ADD_OBJECT(o, attributeValueClassName)
                ADD_OBJECT(o, defaultValue)

                if ([o attributeType] == NSTransformableAttributeType)
                        ADD_OBJECT(o, valueTransformerName)
        }
        else if ([object isKindOfClass:[NSFetchedPropertyDescription class]]) {
                NSFetchedPropertyDescription* o = object;
                ADD_CLASS_LABEL(@"NSFetchedPropertyDescription Info")
                ADD_OBJECT(o, fetchRequest)
        }
        else if ([object isKindOfClass:[NSRelationshipDescription class]]) {
                NSRelationshipDescription* o = object;
                ADD_CLASS_LABEL(@"NSRelationshipDescription Info")
                ADD_ENUM(o, deleteRule, DeleteRule)
                ADD_OBJECT(o, destinationEntity)
                ADD_OBJECT(o, inverseRelationship)
                ADD_BOOL(o, isToMany)
                ADD_NUMBER(o, maxCount)
                ADD_NUMBER(o, minCount)
        }

        NSPropertyDescription* o = object;
        ADD_CLASS_LABEL(@"NSPropertyDescription Info")
        ADD_OBJECT(o, entity)
        ADD_BOOL(o, isIndexed)
        ADD_BOOL(o, isOptional)
        ADD_BOOL(o, isTransient)
        ADD_OBJECT(o, name)
        ADD_DICTIONARY(o, userInfo)
        ADD_OBJECTS(o, validationPredicates)
        ADD_OBJECTS(o, validationWarnings)
}

- (void)addNSResponder:(id)object
{
        if ([object isKindOfClass:[NSApplication class]]) {
                
                #pragma mark ► NSApplication
                //--------------------------------------------------------------------------------
                
                NSApplication* o = object;
                ADD_CLASS_LABEL(@"NSApplication Info")
                ADD_OBJECT_NOT_NIL(o, applicationIconImage)
                ADD_OBJECT_NOT_NIL(o, context)
                ADD_OBJECT_NOT_NIL(o, currentEvent)
                ADD_OBJECT_NOT_NIL(o, delegate)
                ADD_OBJECT_NOT_NIL(o, dockTile)
                ADD_BOOL(o, isActive)
                ADD_BOOL(o, isHidden)
                ADD_BOOL(o, isRunning)
                ADD_OBJECT_NOT_NIL(o, keyWindow)
                ADD_OBJECT_NOT_NIL(o, mainMenu)
                ADD_OBJECT_NOT_NIL(o, mainWindow)
                ADD_OBJECT_NOT_NIL(o, modalWindow)
                ADD_OBJECTS(o, orderedDocuments)
                ADD_OBJECTS(o, orderedWindows)
                ADD_OBJECT_NOT_NIL(o, servicesMenu)
                ADD_OBJECT_NOT_NIL(o, servicesProvider)
                ADD_OBJECTS(o, windows)
                ADD_OBJECT_NOT_NIL(o, windowsMenu)
        }
        else if ([object isKindOfClass:[NSDrawer class]]) {
                
                
                #pragma mark ► NSDrawer
                //--------------------------------------------------------------------------------

                NSDrawer* o = object;
                ADD_CLASS_LABEL(@"NSDrawer Info");
                ADD_SIZE(o, contentSize)
                ADD_OBJECT(o, contentView)
                ADD_OBJECT(o, delegate)
                ADD_ENUM(o, edge, RectEdge)
                ADD_NUMBER(o, leadingOffset)
                ADD_SIZE(o, maxContentSize)
                ADD_SIZE(o, minContentSize)
                ADD_OBJECT(o, parentWindow)
                ADD_ENUM(o, preferredEdge, RectEdge)
                ADD_ENUM(o, state, DrawerState)
                ADD_NUMBER(o, trailingOffset)
        }
        else if ([object isKindOfClass:[NSView class]]) {
                [self processNSView:object];
        }

        if ([object isKindOfClass:[NSViewController class]]) {
                
                
                #pragma mark ► NSViewController
                //--------------------------------------------------------------------------------

                NSViewController* o = object;
                ADD_CLASS_LABEL(@"NSViewController Info")
                ADD_OBJECT_NOT_NIL(o, nibBundle)
                ADD_OBJECT_NOT_NIL(o, nibName)
                ADD_OBJECT_NOT_NIL(o, representedObject)
                ADD_STRING_NOT_NIL(o, title)
                ADD_OBJECT_NOT_NIL(o, view)
        }
        else if ([object isKindOfClass:[NSWindow class]]) {
                [self processNSWindow:object];
        }
        else if ([object isKindOfClass:[NSWindowController class]]) {
                
                
                #pragma mark ► NSWindowController
                //--------------------------------------------------------------------------------

                NSWindowController* o = object;
                ADD_CLASS_LABEL(@"NSWindowController Info");
                ADD_OBJECT(o, document)
                ADD_BOOL(o, isWindowLoaded)
                ADD_OBJECT(o, owner)
                ADD_BOOL(o, shouldCascadeWindows)
                ADD_BOOL(o, shouldCloseDocument)
                if ([o isWindowLoaded])
                        ADD_OBJECT(o, window)
                ADD_OBJECT(o, windowFrameAutosaveName)
                ADD_OBJECT(o, windowNibName)
                ADD_OBJECT(o, windowNibPath)
        }

        NSResponder* o = object;
        ADD_CLASS_LABEL(@"NSResponder Info")
        ADD_BOOL(o, acceptsFirstResponder)

        @try {
                [view addObject:[o menu] withLabel:@"Menu" toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
                // The menu method might raise if not implemented in the actual NSResponder subclass
        }
        @catch (id exception) {}

        if ([o nextResponder]) {
                NSResponder* responder = o;
                NSMutableArray* responders = [NSMutableArray array];
                while ((responder = [responder nextResponder]))
                        [responders addObject:responder];
                [view addObjects:responders withLabel:@"Next responders" toMatrix:m classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject];
        }

        ADD_OBJECT(o, undoManager)
}

- (void)addNSRulerMarker:(id)object
{
        NSRulerMarker* o = object;
        ADD_CLASS_LABEL(@"NSRulerMarker Info");
        ADD_OBJECT(o, image)
        ADD_POINT([o imageOrigin], imageOrigin, setImageOrigin, @"Image origin")
        ADD_RECT(o, imageRectInRuler)
        ADD_BOOL(o, isDragging)
        ADD_BOOL(o, isMovable)
        ADD_BOOL(o, isRemovable)
        ADD_NUMBER(o, markerLocation)
        ADD_OBJECT(o, representedObject)
        ADD_OBJECT(o, ruler)
        ADD_NUMBER(o, thicknessRequiredInRuler)
}

- (void)addNSScreen:(id)object
{
        NSScreen* o = object;
        ADD_CLASS_LABEL(@"NSScreen Info");
        ADD_NUMBER(o, depth)
        ADD_DICTIONARY(o, deviceDescription)
        ADD_RECT(o, frame)
        ADD_NUMBER(o, userSpaceScaleFactor)
        ADD_RECT(o, visibleFrame)
}

- (void)addNSShadow:(id)object
{
        NSShadow* o = object;
        ADD_CLASS_LABEL(@"NSShadow Info");
        ADD_NUMBER(o, shadowBlurRadius)
        ADD_COLOR(o, shadowColor)
        ADD_SIZE(o, shadowOffset)
}

- (void)addNSStatusBar:(id)object
{
        NSStatusBar* o = object;
        ADD_CLASS_LABEL(@"NSStatusBar Info");
        ADD_BOOL(o, isVertical)
        ADD_NUMBER(o, thickness)
}

- (void)addNSStatusItem:(id)object
{
        NSStatusItem* o = object;
        ADD_CLASS_LABEL(@"NSStatusItem Info");
        ADD_SEL(o, action)
        ADD_OBJECT_NOT_NIL(o, alternateImage)
        ADD_OBJECT_NOT_NIL(o, attributedTitle)
        ADD_SEL(o, doubleAction)
        ADD_BOOL(o, highlightMode)
        ADD_OBJECT_NOT_NIL(o, image)
        ADD_BOOL(o, isEnabled)
        ADD_ENUM(o, length, StatusItemLength)
        ADD_OBJECT_NOT_NIL(o, menu)
        ADD_OBJECT(o, statusBar)
        ADD_OBJECT(o, target)
        ADD_STRING_NOT_NIL(o, title)
        ADD_STRING_NOT_NIL(o, toolTip)
        ADD_OBJECT_NOT_NIL(o, view)
}

- (void)addNSTabViewItem:(id)object
{
        NSTabViewItem* o = object;
        ADD_CLASS_LABEL(@"NSTabViewItem Info");
        ADD_COLOR(o, color)
        ADD_OBJECT(o, identifier)
        ADD_OBJECT(o, initialFirstResponder)
        ADD_OBJECT(o, label)
        ADD_ENUM(o, tabState, TabState)
        ADD_OBJECT(o, tabView)
        ADD_OBJECT(o, view)
}

- (void)addNSTableColumn:(id)object
{
        NSTableColumn* o = object;
        ADD_CLASS_LABEL(@"NSTableColumn Info");
        ADD_OBJECT(o, dataCell)
        ADD_OBJECT(o, headerCell)
        ADD_OBJECT_NOT_NIL(o, headerToolTip)
        ADD_OBJECT(o, identifier)
        ADD_BOOL(o, isEditable)
        ADD_BOOL(o, isHidden)
        ADD_NUMBER(o, maxWidth)
        ADD_NUMBER(o, minWidth)
        ADD_OPTIONS(o, resizingMask, TableColumnResizingOptions)
        ADD_OBJECT_NOT_NIL(o, sortDescriptorPrototype)
        ADD_OBJECT(o, tableView)
        ADD_NUMBER(o, width)
}

- (void)addNSTextAttachment:(id)object
{
        NSTextAttachment* o = object;
        ADD_CLASS_LABEL(@"NSTextAttachment Info");
        ADD_OBJECT(o, attachmentCell)
        ADD_OBJECT(o, fileWrapper)
}

- (void)addNSTextBlock:(id)object
{
        if ([object isKindOfClass:[NSTextTableBlock class]]) {
                NSTextTableBlock* o = object;
                ADD_CLASS_LABEL(@"NSTextTableBlock Info");
                ADD_NUMBER(o, columnSpan)
                ADD_NUMBER(o, rowSpan)
                ADD_NUMBER(o, startingColumn)
                ADD_NUMBER(o, startingRow)
                ADD_OBJECT(o, table)
        }
        else if ([object isKindOfClass:[NSTextTable class]]) {
                NSTextTable* o = object;
                ADD_CLASS_LABEL(@"NSTextTable Info");
                ADD_BOOL(o, collapsesBorders)
                ADD_BOOL(o, hidesEmptyCells)
                ADD_ENUM(o, layoutAlgorithm, TextTableLayoutAlgorithm)
                ADD_NUMBER(o, numberOfColumns)
        }

        NSTextBlock* o = object;
        ADD_CLASS_LABEL(@"NSTextBlock Info");
        ADD_COLOR(o, backgroundColor)
        ADD_NUMBER(o, contentWidth)
        ADD_ENUM(o, contentWidthValueType, TextBlockValueType)
        ADD_ENUM(o, verticalAlignment, TextBlockVerticalAlignment)
}

- (void)addNSTextContainer:(id)object
{
        NSTextContainer* o = object;
        ADD_CLASS_LABEL(@"NSTextContainer Info");
        ADD_SIZE(o, containerSize)
        ADD_BOOL(o, heightTracksTextView)
        ADD_BOOL(o, isSimpleRectangularTextContainer)
        ADD_OBJECT_NOT_NIL(o, layoutManager)
        ADD_NUMBER(o, lineFragmentPadding)
        ADD_OBJECT_NOT_NIL(o, textView)
        ADD_BOOL(o, widthTracksTextView)
}

- (void)addNSTextList:(id)object
{
        NSTextList* o = object;
        ADD_CLASS_LABEL(@"NSTextList Info");
        ADD_OPTIONS(o, listOptions, TextListOptions)
        ADD_OBJECT(o, markerFormat)
}

- (void)addNSTextTab:(id)object
{
        NSTextTab* o = object;
        ADD_CLASS_LABEL(@"NSTextTab Info");
        ADD_ENUM(o, alignment, TextAlignment)
        ADD_NUMBER(o, location)
        ADD_OBJECT(o, options)
        ADD_ENUM(o, tabStopType, TextTabType)
}

- (void)addNSToolbar:(id)object
{
        NSToolbar* o = object;
        ADD_CLASS_LABEL(@"NSToolbar Info");
        ADD_BOOL(o, allowsUserCustomization)
        ADD_BOOL(o, autosavesConfiguration)
        ADD_DICTIONARY(o, configurationDictionary)
        ADD_BOOL(o, customizationPaletteIsRunning)
        ADD_OBJECT(o, delegate)
        ADD_ENUM(o, displayMode, ToolbarDisplayMode)
        ADD_OBJECT(o, identifier)
        ADD_BOOL(o, isVisible)
        ADD_OBJECTS(o, items)
        ADD_OBJECT_NOT_NIL(o, selectedItemIdentifier)
        ADD_BOOL(o, showsBaselineSeparator)
        ADD_ENUM(o, sizeMode, ToolbarSizeMode)
        ADD_OBJECTS(o, visibleItems)
}

- (void)addNSToolbarItem:(id)object
{
        if ([object isKindOfClass:[NSToolbarItemGroup class]]) {
                NSToolbarItemGroup* o = object;
                ADD_CLASS_LABEL(@"NSToolbarItemGroup Info");
                ADD_OBJECTS(o, subitems)
        }

        NSToolbarItem* o = object;
        ADD_CLASS_LABEL(@"NSToolbarItem Info");
        ADD_SEL(o, action)
        ADD_BOOL(o, allowsDuplicatesInToolbar)
        ADD_BOOL(o, autovalidates)
        ADD_OBJECT(o, image)
        ADD_BOOL(o, isEnabled)
        ADD_OBJECT(o, itemIdentifier)
        ADD_OBJECT(o, label)
        ADD_SIZE(o, maxSize)
        ADD_OBJECT_NOT_NIL(o, menuFormRepresentation)
        ADD_SIZE(o, minSize)
        ADD_OBJECT(o, paletteLabel)
        ADD_NUMBER(o, tag)
        ADD_OBJECT(o, target)
        ADD_OBJECT(o, toolbar)
        ADD_OBJECT_NOT_NIL(o, toolTip)
        ADD_OBJECT(o, view)
        ADD_ENUM(o, visibilityPriority, ToolbarItemVisibilityPriority)
}

- (void)addNSTrackingArea:(id)object
{
        NSTrackingArea* o = object;
        ADD_CLASS_LABEL(@"NSTrackingArea Info");
        ADD_OPTIONS(o, options, TrackingAreaOptions)
        ADD_OBJECT(o, owner)
        ADD_RECT(o, rect)
        ADD_DICTIONARY(o, userInfo)
}

- (void)addNSUndoManager:(id)object
{
        NSUndoManager* o = object;
        ADD_CLASS_LABEL(@"NSUndoManager Info");
        ADD_NUMBER(o, groupingLevel)
        ADD_BOOL(o, groupsByEvent)
        ADD_BOOL(o, isUndoRegistrationEnabled)
        ADD_NUMBER(o, levelsOfUndo)
        ADD_STRING_NOT_NIL(o, redoActionName)
        ADD_STRING_NOT_NIL(o, redoMenuItemTitle)
        ADD_OBJECTS(o, runLoopModes)
        ADD_STRING_NOT_NIL(o, undoActionName)
        ADD_STRING_NOT_NIL(o, undoMenuItemTitle)
}

- (void)addNSATSTypesetter:(id)object
{
        if ([object isKindOfClass:NSClassFromString(@"NSATSTypesetter")]) {
                //  NSATSTypesetter *o = object;
                //  ADD_CLASS_LABEL(@"NSATSTypesetter Info");
        }

        NSTypesetter* o = object;
        ADD_CLASS_LABEL(@"NSTypesetter Info");
        //ADD_OBJECT(            [o attributedString]                   ,@"Attributed string")
        ADD_DICTIONARY(o, attributesForExtraLineFragment)
        ADD_BOOL(o, bidiProcessingEnabled)
        ADD_OBJECT_NOT_NIL(o, currentTextContainer)
        ADD_NUMBER(o, hyphenationFactor)
        ADD_OBJECT_NOT_NIL(o, layoutManager)
        ADD_NUMBER(o, lineFragmentPadding)
        ADD_ENUM(o, typesetterBehavior, TypesetterBehavior)
        ADD_BOOL(o, usesFontLeading)
}

- (void)processNSView:(id)object
{

        if ([object isKindOfClass:[NSBox class]]) {
                
                
                #pragma mark ► NSBox
                //--------------------------------------------------------------------------------

                NSBox* o = object;
                ADD_CLASS_LABEL(@"NSBox Info");
                ADD_COLOR(o, borderColor)
                ADD_RECT(o, borderRect)
                ADD_ENUM(o, borderType, BorderType)
                ADD_NUMBER(o, borderWidth)
                ADD_ENUM(o, boxType, BoxType)
                ADD_OBJECT(o, contentView)
                ADD_SIZE(o, contentViewMargins)
                ADD_NUMBER(o, cornerRadius)
                ADD_COLOR(o, fillColor)
                ADD_BOOL(o, isTransparent)
                ADD_STRING(o, title)
                ADD_OBJECT(o, titleCell)
                ADD_OBJECT(o, titleFont)
                ADD_ENUM(o, titlePosition, TitlePosition)
                ADD_RECT(o, titleRect)
        }
        if ([object isKindOfClass:[NSCollectionView class]]) {
                
                
                #pragma mark ► NSCollectionView
                //--------------------------------------------------------------------------------

                NSCollectionView* o = object;
                ADD_CLASS_LABEL(@"NSCollectionView Info");
                ADD_BOOL(o, allowsMultipleSelection)
                ADD_OBJECTS(o, backgroundColors)
                ADD_OBJECT(o, content)
                ADD_BOOL(o, isFirstResponder)
                ADD_BOOL(o, isSelectable)
                ADD_OBJECT_NOT_NIL(o, itemPrototype)
                ADD_SIZE(o, maxItemSize)
                ADD_NUMBER(o, maxNumberOfColumns)
                ADD_NUMBER(o, maxNumberOfRows)
                ADD_SIZE(o, minItemSize)
                ADD_OBJECT_NOT_NIL(o, selectionIndexes)
        }
        else if ([object isKindOfClass:[NSControl class]]) {
                [self processNSControl:object];
        }
        else if ([object isKindOfClass:[NSClipView class]]) {
                
                
                #pragma mark ► NSClipView
                //--------------------------------------------------------------------------------

                NSClipView* o = object;
                ADD_CLASS_LABEL(@"NSClipView Info");
                ADD_COLOR(o, backgroundColor)
                ADD_BOOL(o, copiesOnScroll)
                ADD_OBJECT(o, documentCursor)
                ADD_RECT(o, documentRect)
                ADD_OBJECT(o, documentView)
                ADD_RECT(o, documentVisibleRect)
                ADD_BOOL(o, drawsBackground)
        }
        else if ([object isKindOfClass:[NSOpenGLView class]]) {
                
                
                #pragma mark ► NSOpenGLView
                //--------------------------------------------------------------------------------

                NSOpenGLView* o = object;
                ADD_CLASS_LABEL(@"NSOpenGLView Info");
                ADD_OBJECT(o, openGLContext)
                ADD_OBJECT(o, pixelFormat)
        }
        else if ([object isKindOfClass:[NSProgressIndicator class]]) {
                
                
                #pragma mark ► NSProgressIndicator
                //--------------------------------------------------------------------------------

                NSProgressIndicator* o = object;
                ADD_CLASS_LABEL(@"NSProgressIndicator Info");
                ADD_ENUM(o, controlSize, ControlSize)
                ADD_ENUM(o, controlTint, ControlTint)
                if ([o style] == NSProgressIndicatorBarStyle && ![o isIndeterminate])
                        ADD_NUMBER(o, doubleValue)
                ADD_BOOL(o, isBezeled)
                ADD_BOOL(o, isDisplayedWhenStopped)
                if ([o style] == NSProgressIndicatorBarStyle && ![o isIndeterminate]) {
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                }
                ADD_ENUM(o, style, ProgressIndicatorStyle)
                ADD_BOOL(o, usesThreadedAnimation)
        }
        else if ([object isKindOfClass:[NSRulerView class]]) {
                
                
                #pragma mark ► NSRulerView
                //--------------------------------------------------------------------------------

                NSRulerView* o = object;
                ADD_CLASS_LABEL(@"NSRulerView Info");
                ADD_OBJECT_NOT_NIL(o, accessoryView)
                ADD_NUMBER(o, baselineLocation)
                ADD_OBJECT(o, clientView)
                ADD_BOOL(o, isFlipped)
                ADD_OBJECTS(o, markers)
                ADD_OBJECT(o, measurementUnits)
                ADD_ENUM(o, orientation, RulerOrientation)
                ADD_NUMBER(o, originOffset)
                ADD_NUMBER(o, requiredThickness)
                ADD_NUMBER(o, reservedThicknessForAccessoryView)
                ADD_NUMBER(o, reservedThicknessForMarkers)
                ADD_NUMBER(o, ruleThickness)
                ADD_OBJECT(o, scrollView)
        }
        else if ([object isKindOfClass:[NSScrollView class]]) {
                
                
                #pragma mark ► NSScrollView
                //--------------------------------------------------------------------------------

                NSScrollView* o = object;
                ADD_CLASS_LABEL(@"NSScrollView Info");
                ADD_BOOL(o, autohidesScrollers)
                ADD_COLOR(o, backgroundColor)
                ADD_ENUM(o, borderType, BorderType)
                ADD_SIZE(o, contentSize)
                ADD_OBJECT(o, contentView)
                ADD_OBJECT(o, documentCursor)
                ADD_OBJECT(o, documentView)
                ADD_RECT(o, documentVisibleRect)
                ADD_BOOL(o, drawsBackground)
                ADD_BOOL(o, hasHorizontalRuler)
                ADD_BOOL(o, hasHorizontalScroller)
                ADD_BOOL(o, hasVerticalRuler)
                ADD_BOOL(o, hasVerticalScroller)
                ADD_NUMBER(o, horizontalLineScroll)
                ADD_NUMBER(o, horizontalPageScroll)
                ADD_OBJECT(o, horizontalRulerView)
                ADD_OBJECT(o, horizontalScroller)
                ADD_NUMBER(o, lineScroll)
                ADD_NUMBER(o, pageScroll)
                ADD_BOOL(o, rulersVisible)
                ADD_BOOL(o, scrollsDynamically)
                ADD_NUMBER(o, verticalLineScroll)
                ADD_NUMBER(o, verticalPageScroll)
                ADD_OBJECT(o, verticalRulerView)
                ADD_OBJECT(o, verticalScroller)
        }
        else if ([object isKindOfClass:[NSSplitView class]]) {
                
                
                #pragma mark ► NSSplitView
                //--------------------------------------------------------------------------------

                NSSplitView* o = object;
                ADD_CLASS_LABEL(@"NSSplitView Info");
                ADD_OBJECT_NOT_NIL(o, delegate)
                ADD_NUMBER(o, dividerThickness)
                ADD_BOOL(o, isVertical)
                ADD_OBJECT_NOT_NIL(o, autosaveName)
        }
        else if ([object isKindOfClass:[NSTabView class]]) {
                
                
                #pragma mark ► NSTabView
                //--------------------------------------------------------------------------------

                NSTabView* o = object;
                ADD_CLASS_LABEL(@"NSTabView Info");
                ADD_BOOL(o, allowsTruncatedLabels)
                ADD_RECT(o, contentRect)
                ADD_ENUM(o, controlSize, ControlSize)
                ADD_ENUM(o, controlTint, ControlTint)
                ADD_OBJECT(o, delegate)
                ADD_BOOL(o, drawsBackground)
                ADD_OBJECT(o, font)
                ADD_SIZE(o, minimumSize)
                ADD_OBJECT(o, selectedTabViewItem)
                ADD_OBJECTS(o, tabViewItems)
                ADD_ENUM(o, tabViewType, TabViewType)
        }
        else if ([object isKindOfClass:[NSTableHeaderView class]]) {
                
                
                #pragma mark ► NSTableHeaderView
                //--------------------------------------------------------------------------------

                NSTableHeaderView* o = object;
                ADD_CLASS_LABEL(@"NSTableHeaderView Info");
                ADD_OBJECT(o, tableView)
        }
        else if ([object isKindOfClass:[NSText class]]) {
                
                
                #pragma mark ► NSTextView
                //--------------------------------------------------------------------------------

                if ([object isKindOfClass:[NSTextView class]]) {
                        NSTextView* o = object;
                        ADD_CLASS_LABEL(@"NSTextView Info");
                        ADD_OBJECTS(o, acceptableDragTypes)
                        ADD_BOOL(o, acceptsGlyphInfo)
                        ADD_OBJECTS(o, allowedInputSourceLocales)
                        ADD_BOOL(o, allowsImageEditing)
                        ADD_BOOL(o, allowsDocumentBackgroundColorChange)
                        ADD_BOOL(o, allowsUndo)
                        ADD_OBJECT_NOT_NIL(o, defaultParagraphStyle)
                        ADD_BOOL(o, displaysLinkToolTips)
                        ADD_COLOR(o, insertionPointColor)
                        ADD_BOOL(o, isAutomaticLinkDetectionEnabled)
                        ADD_BOOL(o, isAutomaticQuoteSubstitutionEnabled)
                        ADD_BOOL(o, isContinuousSpellCheckingEnabled)
                        ADD_BOOL(o, isGrammarCheckingEnabled)
                        ADD_OBJECT_NOT_NIL(o, layoutManager)
                        ADD_DICTIONARY(o, linkTextAttributes)
                        ADD_DICTIONARY(o, markedTextAttributes)
                        ADD_RANGE([o rangeForUserCompletion], rangeForUserCompletion, setRangeForUserCompletion, @"Range for user completion")
                        ADD_OBJECTS(o, rangesForUserCharacterAttributeChange)
                        ADD_OBJECTS(o, rangesForUserParagraphAttributeChange)
                        ADD_OBJECTS(o, rangesForUserTextChange)
                        ADD_OBJECTS(o, readablePasteboardTypes)
                        ADD_OBJECTS(o, selectedRanges)
                        ADD_DICTIONARY(o, selectedTextAttributes)
                        ADD_ENUM(o, selectionAffinity, SelectionAffinity)
                        ADD_ENUM(o, selectionGranularity, SelectionGranularity)
                        ADD_BOOL(o, shouldDrawInsertionPoint)
                        ADD_BOOL(o, smartInsertDeleteEnabled)
                        ADD_NUMBER(o, spellCheckerDocumentTag)
                        ADD_OBJECT(o, textContainer)
                        ADD_SIZE(o, textContainerInset)
                        ADD_POINT([o textContainerOrigin], textContainerOrigin, setTextContainerOrigin, @"Text container origin")
                        ADD_OBJECT(o, textStorage)
                        ADD_DICTIONARY(o, typingAttributes)
                        ADD_BOOL(o, usesFindPanel)
                        ADD_BOOL(o, usesFontPanel)
                        ADD_BOOL(o, usesRuler)
                        ADD_OBJECT(o, writablePasteboardTypes)
                }

                
                
                #pragma mark ► NSText
                //--------------------------------------------------------------------------------

                NSText* o = object;
                ADD_CLASS_LABEL(@"NSText Info");
                ADD_ENUM(o, alignment, TextAlignment)
                ADD_COLOR(o, backgroundColor)
                ADD_ENUM(o, baseWritingDirection, WritingDirection)
                ADD_OBJECT_NOT_NIL(o, delegate)
                ADD_BOOL(o, drawsBackground)
                ADD_OBJECT(o, font)
                ADD_BOOL(o, importsGraphics)
                ADD_BOOL(o, isEditable)
                ADD_BOOL(o, isFieldEditor)
                ADD_BOOL(o, isHorizontallyResizable)
                ADD_BOOL(o, isRichText)
                ADD_BOOL(o, isRulerVisible)
                ADD_BOOL(o, isSelectable)
                ADD_BOOL(o, isVerticallyResizable)
                ADD_SIZE(o, maxSize)
                ADD_SIZE(o, minSize)
                ADD_RANGE([o selectedRange], selectedRange, setSelectedRange, @"Selected range")
                ADD_OBJECT(o, string)
                ADD_COLOR_NOT_NIL([o textColor], textColor, setTextColor, @"Text color")
                ADD_BOOL(o, usesFontPanel)
        }

        
        
        #pragma mark ► NSView
        //--------------------------------------------------------------------------------

        NSView* o = object;
        ADD_CLASS_LABEL(@"NSView Info");
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6
        ADD_BOOL(o, acceptsTouchEvents)
#endif
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10
        ADD_BOOL(o, allowsVibrancy)
#endif
        ADD_OPTIONS(o, autoresizingMask, AutoresizingMaskOptions)
        ADD_BOOL(o, autoresizesSubviews)
        ADD_RECT(o, bounds)
        ADD_NUMBER(o, boundsRotation)
        ADD_BOOL(o, canBecomeKeyView)
        ADD_BOOL(o, canDraw)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6
        ADD_BOOL(o, canDrawConcurrently)
#endif
        ADD_OBJECT_NOT_NIL(o, enclosingMenuItem)
        ADD_OBJECT_NOT_NIL(o, enclosingScrollView)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7
        ADD_RECT(o, focusRingMaskBounds)
#endif
        ADD_RECT(o, frame)
        ADD_NUMBER(o, frameRotation)
        ADD_ENUM(o, focusRingType, FocusRingType)
        ADD_NUMBER(o, gState)
        ADD_NUMBER(o, heightAdjustLimit)
        ADD_BOOL(o, isFlipped)
        ADD_BOOL(o, isHidden)
        ADD_BOOL(o, isHiddenOrHasHiddenAncestor)
        ADD_BOOL(o, isInFullScreenMode)
        ADD_BOOL(o, isOpaque)
        ADD_BOOL(o, isRotatedFromBase)
        ADD_BOOL(o, isRotatedOrScaledFromBase)
        ADD_OBJECT(o, layer)
        ADD_BOOL(o, mouseDownCanMoveWindow)
        ADD_BOOL(o, needsDisplay)
        ADD_BOOL(o, needsPanelToBecomeKey)
        ADD_OBJECT(o, nextKeyView)
        ADD_OBJECT(o, nextValidKeyView)
        ADD_OBJECT(o, opaqueAncestor)
        ADD_BOOL(o, preservesContentDuringLiveResize)
        ADD_BOOL(o, postsBoundsChangedNotifications)
        ADD_BOOL(o, postsFrameChangedNotifications)
        ADD_OBJECT(o, previousKeyView)
        ADD_OBJECT(o, previousValidKeyView)
        ADD_STRING(o, printJobTitle)
        ADD_OBJECTS(o, registeredDraggedTypes)
        ADD_BOOL(o, shouldDrawColor)
        ADD_NUMBER(o, tag)
        ADD_OBJECTS(o, trackingAreas)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7
        ADD_BOOL(o, translatesAutoresizingMaskIntoConstraints)
#endif
        ADD_RECT(o, visibleRect)
        ADD_BOOL(o, wantsDefaultClipping)
        ADD_BOOL(o, wantsLayer)
        ADD_NUMBER(o, widthAdjustLimit)
        ADD_OBJECT(o, window)
}

// Works for NSSegmentedControl and NSSegmentedCell
- (void)processSegmentedItem:(id)segmentedItem
{
        NSSegmentedCell* o = segmentedItem;
        NSUInteger segmentCount = o.segmentCount;
        for (NSInteger i = 0; i < segmentCount; i++) {
                [self addGroup:[NSString stringWithFormat:@"Segment %lu", i]];
                [self addObject:[o imageForSegment:i]
                                    valueType:FS_ITEM_OBJECT
                                    getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return [(NSSegmentedControl*)obj imageForSegment:i];
                                    }
                                    setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedControl*)obj setImage:newValue forSegment:i];
                                    }
                                    withLabel:[NSString stringWithFormat:@"Image for segment %ld", (long)i]
                                    notNil:YES];
                if ([o respondsToSelector:@selector(imageScalingForSegment:)]) {
                        [self addObject:objectFromImageScaling([o imageScalingForSegment:i])
                                            valueType:FS_ITEM_ENUM
                                            getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return @([(NSSegmentedCell*)obj imageScalingForSegment:i]);
                                            }
                                            setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedCell*)obj setImageScaling:[newValue integerValue] forSegment:i];
                                            }
                                            withLabel:[NSString stringWithFormat:@"Image scaling for segment %ld", (long)i]
                                            enumBiDict:FSObjectEnumInfo.optionsForImageScaling
                                            mask:0
                                            valueClass:nil
                                            notNil:NO];
                }
                [self addObject:[FSBoolean booleanWithBool:[o isEnabledForSegment:i]]
                                    valueType:FS_ITEM_BOOL
                                    getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return @([(NSSegmentedControl*)obj isEnabledForSegment:i]);
                                    }
                                    setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedControl*)obj setEnabled:[newValue boolValue] forSegment:i];
                                    }
                                    withLabel:[NSString stringWithFormat:@"Is enabled for segment %ld", (long)i]];
                [self addObject:[FSBoolean booleanWithBool:[o isSelectedForSegment:i]]
                                    valueType:FS_ITEM_BOOL
                                    getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return @([(NSSegmentedControl*)obj isSelectedForSegment:i]);
                                    }
                                    setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedControl*)obj setSelected:[newValue boolValue] forSegment:i];
                                    }
                                    withLabel:[NSString stringWithFormat:@"Is selected for segment %ld", (long)i]];
                [self addObject:[o labelForSegment:i]
                                    valueType:FS_ITEM_OBJECT
                                    getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return [(NSSegmentedControl*)obj labelForSegment:i];
                                    }
                                    setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedControl*)obj setLabel:newValue forSegment:i];
                                    }
                                    withLabel:[NSString stringWithFormat:@"Label for segment %ld", (long)i]
                                    enumBiDict:nil
                                    mask:0
                                    valueClass:NSString.class
                                    notNil:YES];
                [self addObject:[o menuForSegment:i]
                                    valueType:FS_ITEM_OBJECT
                                    getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return [(NSSegmentedControl*)obj menuForSegment:i];
                                    }
                                    setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedControl*)obj setMenu:newValue forSegment:i];
                                    }
                                    withLabel:[NSString stringWithFormat:@"Menu for segment %ld", (long)i]
                                    notNil:YES];
                if ([o respondsToSelector:@selector(tagForSegment:)]) {
                        [self addObject:[FSNumber numberWithDouble:[o tagForSegment:i]]
                                            valueType:FS_ITEM_NUMBER
                                            getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return @([(NSSegmentedCell*)obj tagForSegment:i]);
                                            }
                                            setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedCell*)obj setTag:[newValue integerValue] forSegment:i];
                                            }
                                            withLabel:[NSString stringWithFormat:@"Tag for segment %ld", (long)i]
                                            enumBiDict:FSObjectEnumInfo.optionsForImageScaling
                                            mask:0
                                            valueClass:nil
                                            notNil:NO];
                }
                if ([o respondsToSelector:@selector(toolTipForSegment:)]) {
                        [self addObject:[o toolTipForSegment:i]
                                            valueType:FS_ITEM_OBJECT
                                            getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return [(NSSegmentedCell*)obj toolTipForSegment:i];
                                            }
                                            setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedCell*)obj setToolTip:newValue forSegment:i];
                                            }
                                            withLabel:[NSString stringWithFormat:@"ToolTip for segment %ld", (long)i]
                                            enumBiDict:nil
                                            mask:0
                                            valueClass:NSString.class
                                            notNil:YES];
                }
                [self addObject:[FSNumber numberWithDouble:[o widthForSegment:i]]
                                    valueType:FS_ITEM_NUMBER
                                    getter:^id(id obj, FSObjectInspectorViewModelItem* item) { return @([(NSSegmentedControl*)obj widthForSegment:i]);
                                    }
                                    setter:^(id obj, id newValue, FSObjectInspectorViewModelItem* item) { [(NSSegmentedControl*)obj setWidth:[newValue floatValue] forSegment:i];
                                    }
                                    withLabel:[NSString stringWithFormat:@"Width for segment %ld", (long)i]];
                [self endGroup];
        }
}

- (void)processNSControl:(id)object
{
        {
                if ([object isKindOfClass:[NSBrowser class]]) {
                        
                        
                        #pragma mark ► NSBrowser
                        //--------------------------------------------------------------------------------

                        NSBrowser* o = object;
                        ADD_CLASS_LABEL(@"NSBrowser Info");
                        ADD_BOOL(o, allowsBranchSelection)
                        ADD_BOOL(o, allowsEmptySelection)
                        ADD_BOOL(o, allowsMultipleSelection)
                        ADD_BOOL(o, allowsTypeSelect)
                        ADD_COLOR(o, backgroundColor)
                        ADD_OBJECT(o, cellPrototype)
                        ADD_ENUM(o, columnResizingType, BrowserColumnResizingType)
                        ADD_OBJECT(o, columnsAutosaveName)
                        ADD_OBJECT(o, delegate)
                        ADD_SEL(o, doubleAction)
                        ADD_NUMBER(o, firstVisibleColumn)
                        ADD_BOOL(o, hasHorizontalScroller)
                        ADD_BOOL(o, isLoaded)
                        ADD_BOOL(o, isTitled)
                        ADD_NUMBER(o, lastColumn)
                        ADD_NUMBER(o, lastVisibleColumn)
                        ADD_OBJECT(o, matrixClass)
                        ADD_NUMBER(o, maxVisibleColumns)
                        ADD_NUMBER(o, minColumnWidth)
                        ADD_NUMBER(o, numberOfVisibleColumns)
                        ADD_OBJECT(o, path)
                        ADD_OBJECT(o, pathSeparator)
                        ADD_BOOL(o, prefersAllColumnUserResizing)
                        ADD_BOOL(o, reusesColumns)
                        ADD_OBJECTS(o, selectedCells)
                        ADD_NUMBER(o, selectedColumn)
                        ADD_BOOL(o, sendsActionOnArrowKeys)
                        ADD_BOOL(o, separatesColumns)
                        ADD_BOOL(o, takesTitleFromPreviousColumn)
                        ADD_NUMBER(o, titleHeight)
                }
                else if ([object isKindOfClass:[NSButton class]]) {
                        if ([object isKindOfClass:[NSPopUpButton class]]) {
                                
                                
                                #pragma mark ► NSPopUpButton
                                //--------------------------------------------------------------------------------

                                NSPopUpButton* o = object;
                                ADD_CLASS_LABEL(@"NSPopUpButton Info");
                                ADD_BOOL(o, autoenablesItems)
                                ADD_NUMBER(o, indexOfSelectedItem)
                                ADD_OBJECTS(o, itemArray)
                                ADD_NUMBER(o, numberOfItems)
                                ADD_OBJECT(o, objectValue)
                                ADD_ENUM(o, preferredEdge, RectEdge)
                                ADD_BOOL(o, pullsDown)
                                ADD_OBJECT(o, selectedItem)
                        }

                        
                        
                        #pragma mark ► NSButton
                        //--------------------------------------------------------------------------------

                        NSButton* o = object;
                        ADD_CLASS_LABEL(@"NSButton Info");
                        ADD_BOOL(o, allowsMixedState)
                        ADD_OBJECT_NOT_NIL(o, alternateImage)
                        ADD_STRING(o, alternateTitle)
                        ADD_OBJECT(o, attributedAlternateTitle)
                        ADD_OBJECT(o, attributedTitle)
                        ADD_ENUM(o, bezelStyle, BezelStyle)
                        ADD_OBJECT(o, image)
                        ADD_ENUM(o, imagePosition, CellImagePosition)
                        ADD_BOOL(o, isBordered)
                        ADD_BOOL(o, isTransparent)
                        ADD_OBJECT(o, keyEquivalent)
                        ADD_OPTIONS(EventModifierFlags, [o keyEquivalentModifierMask] & NSDeviceIndependentModifierFlagsMask, keyEquivalentModifierMask, setKeyEquivalentModifierMask, @"Key equivalent modifier mask")
                        ADD_BOOL(o, showsBorderOnlyWhileMouseInside)
                        ADD_OBJECT_NOT_NIL(o, sound)
                        ADD_ENUM(o, state, CellStateValue)
                        ADD_STRING(o, title)
                }
                else if ([object isKindOfClass:[NSColorWell class]]) {
                        
                        
                        #pragma mark ► NSColorWell
                        //--------------------------------------------------------------------------------

                        NSColorWell* o = object;
                        ADD_CLASS_LABEL(@"NSColorWell Info");
                        ADD_COLOR(o, color)
                        ADD_BOOL(o, isActive)
                        ADD_BOOL(o, isBordered)
                }
                else if ([object isKindOfClass:[NSDatePicker class]]) {
                        
                        
                        #pragma mark ► NSDatePicker
                        //--------------------------------------------------------------------------------

                        NSDatePicker* o = object;
                        ADD_CLASS_LABEL(@"NSDatePicker Info");
                        ADD_COLOR(o, backgroundColor)
                        ADD_OBJECT(o, calendar)
                        ADD_OPTIONS(o, datePickerElements, DatePickerElementFlags)
                        ADD_ENUM(o, datePickerMode, DatePickerMode)
                        ADD_ENUM(o, datePickerStyle, DatePickerStyle)
                        ADD_OBJECT(o, dateValue)
                        ADD_OBJECT_NOT_NIL(o, delegate)
                        ADD_BOOL(o, drawsBackground)
                        ADD_BOOL(o, isBezeled)
                        ADD_BOOL(o, isBordered)
                        ADD_OBJECT_NOT_NIL(o, locale)
                        ADD_OBJECT(o, maxDate)
                        ADD_OBJECT(o, minDate)
                        ADD_COLOR(o, textColor)
                        ADD_NUMBER(o, timeInterval)
                        ADD_OBJECT(o, timeZone)
                }
                else if ([object isKindOfClass:[NSImageView class]]) {
                        
                        
                        #pragma mark ► NSImageView
                        //--------------------------------------------------------------------------------

                        NSImageView* o = object;
                        ADD_CLASS_LABEL(@"NSImageView Info");
                        ADD_BOOL(o, allowsCutCopyPaste)
                        ADD_BOOL(o, animates)
                        ADD_OBJECT(o, image)
                        ADD_ENUM(o, imageAlignment, ImageAlignment)
                        ADD_ENUM(o, imageFrameStyle, ImageFrameStyle)
                        ADD_ENUM(o, imageScaling, ImageScaling)
                        ADD_BOOL(o, isEditable)
                }
                else if ([object isKindOfClass:[NSLevelIndicator class]]) {
                        
                        
                        #pragma mark ► NSLevelIndicator
                        //--------------------------------------------------------------------------------

                        NSLevelIndicator* o = object;
                        ADD_CLASS_LABEL(@"NSLevelIndicator Info");
                        ADD_NUMBER(o, criticalValue)
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                        ADD_NUMBER(o, numberOfMajorTickMarks)
                        ADD_NUMBER(o, numberOfTickMarks)
                        ADD_OBJECT_RO(objectFromTickMarkPosition([o tickMarkPosition], NO), @"Tick mark position")
                        ADD_NUMBER(o, warningValue)
                }
                else if ([object isKindOfClass:[NSMatrix class]]) {
                        
                        
                        #pragma mark ► NSMatrix
                        //--------------------------------------------------------------------------------

                        NSMatrix* o = object;
                        ADD_CLASS_LABEL(@"NSMatrix Info");
                        ADD_BOOL(o, allowsEmptySelection)
                        ADD_BOOL(o, autosizesCells)
                        ADD_COLOR(o, backgroundColor)
                        ADD_COLOR(o, cellBackgroundColor)
                        ADD_OBJECT(o, cellClass)
                        ADD_SIZE(o, cellSize);

                        NSInteger numberOfColumns = [o numberOfColumns];
                        NSInteger numberOfRows = [o numberOfRows];

                        if (numberOfRows != 0) {
                                for (NSInteger column = 0; column < numberOfColumns; column++) {
                                        NSMutableArray* columnArray = [NSMutableArray arrayWithCapacity:numberOfRows];
                                        for (NSInteger row = 0; row < numberOfRows; row++)
                                                [columnArray addObject:[o cellAtRow:row column:column]];
                                        ADD_OBJECT_RO([NSArray arrayWithArray:columnArray], ([NSString stringWithFormat:@"Column %ld", (long)column]))
                                }
                        }

                        ADD_OBJECT(o, delegate)
                        ADD_SEL(o, doubleAction)
                        ADD_BOOL(o, drawsBackground)
                        ADD_BOOL(o, drawsCellBackground)
                        ADD_SIZE(o, intercellSpacing)
                        ADD_BOOL(o, isAutoscroll)
                        ADD_BOOL(o, isSelectionByRect)
                        ADD_OBJECT(o, keyCell)
                        ADD_ENUM(MatrixMode, [(NSMatrix*)o mode], mode, setMode, @"Mode")
                        ADD_NUMBER(o, numberOfColumns)
                        ADD_NUMBER(o, numberOfRows)
                        ADD_OBJECT(o, prototype)
                        ADD_OBJECTS(o, selectedCells)
                        ADD_NUMBER(o, selectedColumn)
                        ADD_NUMBER(o, selectedRow)
                        ADD_BOOL(o, tabKeyTraversesCells)
                }
                else if ([object isKindOfClass:[NSPathControl class]]) {
                        
                        
                        #pragma mark ► NSPathControl
                        //--------------------------------------------------------------------------------

                        NSPathControl* o = object;
                        ADD_CLASS_LABEL(@"NSPathControl Info");
                        ADD_COLOR_NOT_NIL([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT(o, delegate)
                        ADD_SEL(o, doubleAction)
                        ADD_OBJECTS(o, pathComponentCells)
                        ADD_ENUM(o, pathStyle, PathStyle)
                        ADD_OBJECT(o, URL)
                }
                else if ([object isKindOfClass:[NSRuleEditor class]]) {
                        if ([object isKindOfClass:[NSPredicateEditor class]]) {
                                
                                
                                #pragma mark ► NSPredicateEditor
                                //--------------------------------------------------------------------------------

                                NSPredicateEditor* o = object;
                                ADD_CLASS_LABEL(@"NSPredicateEditor Info");
                                ADD_OBJECTS(o, rowTemplates)
                        }

                        
                        
                        #pragma mark ► NSRuleEditor
                        //--------------------------------------------------------------------------------

                        NSRuleEditor* o = object;
                        ADD_CLASS_LABEL(@"NSRuleEditor Info");
                        ADD_BOOL(o, canRemoveAllRows)
                        ADD_OBJECT_NOT_NIL(o, criteriaKeyPath)
                        ADD_OBJECT(o, delegate)
                        ADD_OBJECT_NOT_NIL(o, displayValuesKeyPath)
                        ADD_DICTIONARY(o, formattingDictionary)
                        ADD_OBJECT_NOT_NIL(o, formattingStringsFilename)
                        ADD_BOOL(o, isEditable)
                        ADD_ENUM(o, nestingMode, RuleEditorNestingMode)
                        ADD_NUMBER(o, numberOfRows)
                        ADD_OBJECT(o, predicate)
                        ADD_OBJECT(o, rowClass)
                        ADD_NUMBER(o, rowHeight)
                        ADD_OBJECT_NOT_NIL(o, rowTypeKeyPath)
                        ADD_OBJECT_NOT_NIL(o, selectedRowIndexes)
                        ADD_OBJECT_NOT_NIL(o, subrowsKeyPath)
                }
                else if ([object isKindOfClass:[NSScroller class]]) {
                        
                        
                        #pragma mark ► NSScroller
                        //--------------------------------------------------------------------------------

                        NSScroller* o = object;
                        ADD_CLASS_LABEL(@"NSScroller Info");
                        ADD_ENUM(o, arrowsPosition, ScrollArrowPosition)
                        ADD_ENUM(o, controlSize, ControlSize)
                        ADD_ENUM(o, controlTint, ControlTint)
                        ADD_NUMBER(o, doubleValue)
                        ADD_ENUM(o, hitPart, ScrollerPart)
                        ADD_NUMBER(o, knobProportion)
                        ADD_ENUM(o, usableParts, UsableScrollerParts)
                }
                else if ([object isKindOfClass:[NSSegmentedControl class]]) {
                        
                        
                        #pragma mark ► NSSegmentedControl
                        //--------------------------------------------------------------------------------

                        NSSegmentedControl* o = object;
                        NSInteger segmentCount = [o segmentCount];
                        ADD_CLASS_LABEL(@"NSSegmentedControl Info");

                        ADD_NUMBER(segmentCount, segmentCount, setSegmentCount, @"Segment count")
                        ADD_NUMBER(o, selectedSegment)
                                            [self processSegmentedItem:o];
                }
                else if ([object isKindOfClass:[NSSlider class]]) {
                        
                        
                        #pragma mark ► NSSlider
                        //--------------------------------------------------------------------------------

                        NSSlider* o = object;
                        ADD_CLASS_LABEL(@"NSSlider Info");
                        ADD_BOOL(o, allowsTickMarkValuesOnly)
                        ADD_NUMBER(o, altIncrementValue)
                        ADD_NUMBER([(NSSlider*)o isVertical], vertical, setVertical:, @"Is vertical")
                        ADD_NUMBER(o, knobThickness)
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                        ADD_NUMBER(o, numberOfTickMarks)
                        ADD_OBJECT_RO(objectFromTickMarkPosition([o tickMarkPosition], [(NSSlider*)o isVertical] == 1), @"Tick mark position")
                        ADD_STRING(o, title)
                }
                else if ([object isKindOfClass:[NSTableView class]]) {
                        if ([object isKindOfClass:[NSOutlineView class]]) {
                                
                                
                                #pragma mark ► NSOutlineView
                                //--------------------------------------------------------------------------------

                                NSOutlineView* o = object;
                                ADD_CLASS_LABEL(@"NSOutlineView Info");
                                ADD_BOOL(o, autoresizesOutlineColumn)
                                ADD_BOOL(o, autosaveExpandedItems)
                                ADD_BOOL(o, indentationMarkerFollowsCell)
                                ADD_NUMBER(o, indentationPerLevel)
                                ADD_OBJECT(o, outlineTableColumn)
                        }

                        
                        
                        #pragma mark ► NSTableView
                        //--------------------------------------------------------------------------------

                        NSTableView* o = object;
                        ADD_CLASS_LABEL(@"NSTableView Info");
                        ADD_BOOL(o, allowsColumnReordering)
                        ADD_BOOL(o, allowsColumnResizing)
                        ADD_BOOL(o, allowsColumnSelection)
                        ADD_BOOL(o, allowsEmptySelection)
                        ADD_BOOL(o, allowsMultipleSelection)
                        ADD_BOOL(o, allowsTypeSelect)
                        ADD_OBJECT_NOT_NIL(o, autosaveName)
                        ADD_BOOL(o, autosaveTableColumns)
                        ADD_COLOR(o, backgroundColor)
                        ADD_ENUM(o, columnAutoresizingStyle, TableViewColumnAutoresizingStyle)
                        ADD_OBJECT(o, cornerView)
                        ADD_OBJECT(o, dataSource)
                        ADD_OBJECT(o, delegate)
                        ADD_SEL(o, doubleAction)
                        ADD_COLOR(o, gridColor)
                        ADD_OPTIONS(o, gridStyleMask, TableViewGridLineStyle)
                        ADD_OBJECT(o, headerView)
                        ADD_OBJECT_NOT_NIL(o, highlightedTableColumn)
                        ADD_SIZE(o, intercellSpacing)
                        ADD_NUMBER(o, numberOfColumns)
                        ADD_NUMBER(o, numberOfRows)
                        ADD_NUMBER(o, numberOfSelectedColumns)
                        ADD_NUMBER(o, numberOfSelectedRows)
                        ADD_NUMBER(o, rowHeight)
                        ADD_NUMBER(o, selectedColumn)
                        ADD_OBJECT(o, selectedColumnIndexes)
                        ADD_NUMBER(o, selectedRow)
                        ADD_OBJECT(o, selectedRowIndexes)
                        ADD_ENUM(o, selectionHighlightStyle, TableViewSelectionHighlightStyle)
                        ADD_OBJECTS(o, sortDescriptors)
                        ADD_OBJECTS(o, tableColumns)
                        ADD_BOOL(o, usesAlternatingRowBackgroundColors)
                        ADD_BOOL(o, verticalMotionCanBeginDrag)
                }
                else if ([object isKindOfClass:[NSStepper class]]) {
                        
                        
                        #pragma mark ► NSStepper
                        //--------------------------------------------------------------------------------

                        NSStepper* o = object;
                        ADD_CLASS_LABEL(@"NSStepper Info");
                        ADD_BOOL(o, autorepeat)
                        ADD_NUMBER(o, increment)
                        ADD_NUMBER(o, maxValue)
                        ADD_NUMBER(o, minValue)
                        ADD_BOOL(o, valueWraps)
                }
                else if ([object isKindOfClass:[NSTextField class]]) {
                        if ([object isKindOfClass:[NSComboBox class]]) {
                                
                                
                                #pragma mark ► NSComboBox
                                //--------------------------------------------------------------------------------

                                NSComboBox* o = object;
                                ADD_CLASS_LABEL(@"NSComboBox Info");
                                if ([o usesDataSource])
                                        ADD_OBJECT(o, dataSource)
                                ADD_BOOL(o, hasVerticalScroller)
                                ADD_NUMBER(o, indexOfSelectedItem)
                                ADD_SIZE(o, intercellSpacing)
                                ADD_BOOL(o, isButtonBordered)
                                ADD_NUMBER(o, itemHeight)
                                ADD_NUMBER(o, numberOfItems)
                                ADD_NUMBER(o, numberOfVisibleItems)
                                if (![o usesDataSource] && [o indexOfSelectedItem] != -1)
                                        ADD_OBJECT(o, objectValueOfSelectedItem)
                                if (![o usesDataSource])
                                        ADD_OBJECTS(o, objectValues)
                                ADD_BOOL(o, usesDataSource)
                        }
                        else if ([object isKindOfClass:[NSSearchField class]]) {
                                
                                
                                #pragma mark ► NSSearchField
                                //--------------------------------------------------------------------------------

                                NSSearchField* o = object;
                                if ([[o recentSearches] count] != 0 || [o recentsAutosaveName] != nil)
                                        ADD_CLASS_LABEL(@"NSSearchField Info");
                                ADD_OBJECTS(o, recentSearches)
                                ADD_OBJECT_NOT_NIL(o, recentsAutosaveName)
                        }
                        else if ([object isKindOfClass:[NSTokenField class]]) {
                                
                                
                                #pragma mark ► NSTokenField
                                //--------------------------------------------------------------------------------

                                NSTokenField* o = object;
                                ADD_CLASS_LABEL(@"NSTokenField Info");
                                ADD_NUMBER(o, completionDelay)
                                ADD_OBJECT(o, tokenizingCharacterSet)
                                ADD_ENUM(o, tokenStyle, TokenStyle)
                        }

                        
                        
                        #pragma mark ► NSTextField
                        //--------------------------------------------------------------------------------

                        NSTextField* o = object;
                        ADD_CLASS_LABEL(@"NSTextField Info");
                        ADD_BOOL(o, allowsEditingTextAttributes)
                        ADD_COLOR(o, backgroundColor)
                        ADD_ENUM(o, bezelStyle, TextFieldBezelStyle)
                        ADD_OBJECT_NOT_NIL(o, delegate)
                        ADD_BOOL(o, drawsBackground)
                        ADD_BOOL(o, importsGraphics)
                        ADD_BOOL(o, isBezeled)
                        ADD_BOOL(o, isBordered)
                        ADD_BOOL(o, isEditable)
                        ADD_BOOL(o, isSelectable)
                        ADD_COLOR(o, textColor)
                }

                
                
                #pragma mark ► NSControl
                //--------------------------------------------------------------------------------

                NSControl* o = object;
                ADD_CLASS_LABEL(@"NSControl Info");
                ADD_SEL(o, action)
                ADD_ENUM(o, alignment, TextAlignment)
                ADD_ENUM(o, baseWritingDirection, WritingDirection)
                ADD_OBJECT(o, cell)
                ADD_ENUM(o, controlSize, ControlSize)
                ADD_OBJECT_NOT_NIL(o, currentEditor)
                ADD_OBJECT(o, font)
                ADD_OBJECT(o, formatter)
                ADD_BOOL(o, ignoresMultiClick)
                ADD_BOOL(o, isContinuous)
                ADD_BOOL(o, isEnabled)
                if ([o currentEditor] == nil)
                        ADD_OBJECT(o, objectValue) // To avoid side-effects, we only call objectValue if the control is not being edited, which is determined with the currentEditor call.
                ADD_BOOL(o, refusesFirstResponder)
                ADD_OBJECT(o, selectedCell)
                ADD_NUMBER(o, selectedTag)
                ADD_OBJECT(o, target)
        }
}

- (void)processNSWindow:(id)object
{
        {
                if ([object isKindOfClass:[NSPanel class]]) {
                        if ([object isKindOfClass:[NSColorPanel class]]) {
                                NSColorPanel* o = object;
                                ADD_CLASS_LABEL(@"NSColorPanel Info");
                                ADD_OBJECT_NOT_NIL(o, accessoryView)
                                ADD_NUMBER(o, alpha)
                                ADD_COLOR(o, color)
                                ADD_BOOL(o, isContinuous)
                                ADD_ENUM(o, mode, ColorPanelMode)
                                ADD_BOOL(o, showsAlpha)
                        }
                        else if ([object isKindOfClass:[NSFontPanel class]]) {
                                NSFontPanel* o = object;
                                ADD_CLASS_LABEL(@"NSFontPanel Info");
                                ADD_OBJECT_NOT_NIL(o, accessoryView)
                                ADD_BOOL(o, isEnabled)
                        }
                        else if ([object isKindOfClass:[NSSavePanel class]]) {
                                if ([object isKindOfClass:[NSOpenPanel class]]) {
                                        NSOpenPanel* o = object;
                                        ADD_CLASS_LABEL(@"NSOpenPanel Info");
                                        ADD_BOOL(o, allowsMultipleSelection)
                                        ADD_BOOL(o, canChooseDirectories)
                                        ADD_BOOL(o, canChooseFiles)
                                        ADD_OBJECTS(o, filenames)
                                        ADD_BOOL(o, resolvesAliases)
                                        ADD_OBJECTS(o, URLs)
                                }

                                NSSavePanel* o = object;
                                ADD_CLASS_LABEL(@"NSSavePanel Info");
                                ADD_OBJECT_NOT_NIL(o, accessoryView)
                                ADD_OBJECTS(o, allowedFileTypes)
                                ADD_BOOL(o, allowsOtherFileTypes)
                                ADD_BOOL(o, canCreateDirectories)
                                ADD_BOOL(o, canSelectHiddenExtension)
                                ADD_OBJECT_NOT_NIL(o, delegate)
                                ADD_OBJECT(o, directory)
                                ADD_OBJECT(o, filename)
                                ADD_BOOL(o, isExpanded)
                                ADD_BOOL(o, isExtensionHidden)
                                ADD_STRING(o, message)
                                ADD_STRING(o, nameFieldLabel)
                                ADD_OBJECT(o, prompt)
                                ADD_BOOL(o, treatsFilePackagesAsDirectories)
                                ADD_OBJECT(o, URL)
                        }


                        NSPanel* o = object;
                        ADD_CLASS_LABEL(@"NSPanel Info");
                        ADD_BOOL(o, becomesKeyOnlyIfNeeded)
                        ADD_BOOL(o, isFloatingPanel)
                }

                NSWindow* o = object;
                ADD_CLASS_LABEL(@"NSWindow Info");
                ADD_BOOL(o, acceptsMouseMovedEvents)
                ADD_BOOL(o, allowsToolTipsWhenApplicationIsInactive)
                ADD_NUMBER(o, alphaValue)
                ADD_BOOL(o, areCursorRectsEnabled)
                ADD_SIZE(o, aspectRatio)
                ADD_OBJECT_NOT_NIL(o, attachedSheet)
                ADD_BOOL(o, autorecalculatesKeyViewLoop)
                ADD_ENUM(o, backingLocation, WindowBackingLocation)
                ADD_COLOR(o, backgroundColor)
                ADD_ENUM(o, backingType, BackingStoreType)
                ADD_BOOL(o, canBecomeKeyWindow)
                ADD_BOOL(o, canBecomeMainWindow)
                ADD_BOOL(o, canBecomeVisibleWithoutLogin)
                ADD_BOOL(o, canHide)
                ADD_BOOL(o, canStoreColor)
                ADD_ENUM(o, collectionBehavior, WindowCollectionBehavior)
                ADD_OBJECTS(o, childWindows)
                ADD_SIZE(o, contentAspectRatio)
                ADD_SIZE(o, contentMaxSize)
                ADD_SIZE(o, contentMinSize)
                ADD_SIZE(o, contentResizeIncrements)
                ADD_OBJECT(o, contentView)
                ADD_OBJECT_NOT_NIL(o, deepestScreen)
                ADD_OBJECT(o, defaultButtonCell)
                ADD_OBJECT(o, delegate)
                ADD_NUMBER(o, depthLimit)
                ADD_DICTIONARY(o, deviceDescription)
                ADD_BOOL(o, displaysWhenScreenProfileChanges)
                ADD_OBJECTS(o, drawers)
                ADD_OBJECT(o, firstResponder)
                ADD_RECT(o, frame)
                ADD_OBJECT_NOT_NIL(o, frameAutosaveName)
                ADD_OBJECT(o, graphicsContext)
                // Call to gState fails when the window in miniaturized
                //ADD_NUMBER(            [o gState]                             ,@"gState")
                ADD_BOOL(o, hasDynamicDepthLimit)
                ADD_BOOL(o, hasShadow)
                ADD_BOOL(o, hidesOnDeactivate)
                ADD_BOOL(o, ignoresMouseEvents)
                ADD_OBJECT(o, initialFirstResponder)
                ADD_BOOL(o, isAutodisplay)
                ADD_BOOL(o, isDocumentEdited)
                ADD_BOOL(o, isExcludedFromWindowsMenu)
                ADD_BOOL(o, isFlushWindowDisabled)
                ADD_BOOL(o, isMiniaturized)
                ADD_BOOL(o, isMovableByWindowBackground)
                ADD_BOOL(o, isOneShot)
                ADD_BOOL(o, isOpaque)
                ADD_BOOL(o, isReleasedWhenClosed)
                ADD_BOOL(o, isSheet)
                ADD_BOOL(o, isVisible)
                ADD_BOOL(o, isZoomed)
                ADD_ENUM(o, keyViewSelectionDirection, SelectionDirection)
                ADD_ENUM(o, level, WindowLevel)
                ADD_SIZE(o, maxSize)
                ADD_SIZE(o, minSize)
                ADD_OBJECT_NOT_NIL(o, miniwindowImage)
                ADD_STRING(o, miniwindowTitle)
                ADD_OBJECT_NOT_NIL(o, parentWindow)
                ADD_ENUM(o, preferredBackingLocation, WindowBackingLocation)
                ADD_BOOL(o, preservesContentDuringLiveResize)
                ADD_OBJECT_NOT_NIL(o, representedFilename)
                ADD_OBJECT_NOT_NIL(o, representedURL)
                ADD_SIZE(o, resizeIncrements)
                ADD_OBJECT(o, screen)
                ADD_ENUM(o, sharingType, WindowSharingType)
                ADD_BOOL(o, showsResizeIndicator)
                ADD_BOOL(o, showsToolbarButton)
                ADD_OPTIONS(o, styleMask, WindowMask)
                ADD_STRING(o, title)
                ADD_OBJECT_NOT_NIL(o, toolbar)
                ADD_NUMBER(o, userSpaceScaleFactor)
                ADD_BOOL(o, viewsNeedDisplay)
                ADD_OBJECT_NOT_NIL(o, windowController)
                ADD_NUMBER(o, windowNumber)
                ADD_BOOL(o, worksWhenModal)
        }
}
@end
