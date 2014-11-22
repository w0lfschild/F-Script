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

@interface FSObjectBrowserViewObjectHelper ()

@property (nonatomic, retain) NSMutableArray* baseClasses;
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
        NSMutableArray* baseClasses;
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
        [baseClasses release];
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
                [self addObject:(OBJECT)valueType:VALUE_TYPE getter:^(id obj, FSObjectInspectorViewModelItem* item) { return [obj valueForKey:@ #GETTER]; } setter:^(id obj, id newVal, FSObjectInspectorViewModelItem* item) { [obj setValue:newVal forKey:@ #GETTER]; } withLabel:(LABEL)enumBiDict:BIDICT mask:MASK valueClass:VALUE_CLASS notNil:NOT_NIL]; \
        }                                                                                                                                                                                                                                                                                                                                                      \
        @catch (id exception) { NSLog(@"%@", exception); }

#define ADD_ENUM(ENUM, OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(objectFrom##ENUM(OBJECT), FS_ITEM_ENUM, GETTER, SETTER, FSObjectEnumInfo.optionsFor##ENUM, 0, nil, LABEL, NO);

#define ADD_OPTIONS(ENUM, OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(objectFrom##ENUM(OBJECT), FS_ITEM_OPTIONS, GETTER, SETTER, FSObjectEnumInfo.optionsFor##ENUM, ENUM##Mask, nil, LABEL, NO);

#define ADD_SIZE(SIZE, GETTER, SETTER, LABEL) \
        ADD_VALUE([NSValue valueWithSize:(SIZE)], FS_ITEM_SIZE, GETTER, SETTER, nil, nil, 0, LABEL, NO)

#define ADD_RECT(RECT,GETTER, SETTER, LABEL) \
        ADD_VALUE([NSValue valueWithRect:(RECT)], FS_ITEM_RECT, GETTER, SETTER, nil, nil, 0, LABEL, NO)

#define ADD_POINT(POINT,GETTER, SETTER, LABEL) \
        ADD_VALUE([NSValue valueWithPoint:(POINT)], FS_ITEM_POINT, GETTER, SETTER, nil, nil, 0, LABEL, NO)

#define ADD_RANGE(RANGE, GETTER, SETTER,LABEL) \
        ADD_VALUE([NSValue valueWithRange:(RANGE)], FS_ITEM_RANGE, GETTER, SETTER, nil, nil, 0, LABEL, NO)

#define ADD_OBJECT(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, nil, 0, LABEL, NO)


#define ADD_OBJECT_NOT_NIL(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, 0, nil, LABEL, YES);

#define ADD_OBJECT_RO(OBJECT, LABEL) ADD_OBJECT(OBJECT, nil, nil, LABEL)
#define ADD_OBJECT_RO_NOT_NIL(OBJECT, LABEL) ADD_OBJECT_NOT_NIL(OBJECT, nil, nil, LABEL)

#define ADD_COLOR(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, 0, NSColor.class, LABEL, NO)

#define ADD_COLOR_NOT_NIL(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, 0, NSColor.class, LABEL, YES)

#define ADD_STRING(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, 0, NSString.class, LABEL, NO)

#define ADD_STRING_NOT_NIL(OBJECT, GETTER, SETTER, LABEL) \
        ADD_VALUE(OBJECT, FS_ITEM_OBJECT, GETTER, SETTER, nil, 0, NSString.class, LABEL, YES)

#define ADD_BOOL(B, GETTER, SETTER, LABEL) \
        ADD_VALUE([FSBoolean booleanWithBool:(B)], FS_ITEM_BOOL, GETTER, SETTER, nil, 0, nil, LABEL, NO);

#define ADD_NUMBER(NUMBER, GETTER, SETTER, LABEL) \
        ADD_VALUE([FSNumber numberWithDouble:(NUMBER)], FS_ITEM_NUMBER, GETTER, SETTER, nil, 0, nil, LABEL, NO);

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

@synthesize baseClasses;


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
                        ADD_OBJECT([o valueForKey:key], key, fs_setterForProperty(key), key)
                }

                NSArray* relationshipKeys = [[[[o entity] relationshipsByName] allKeys] sortedArrayUsingSelector:@selector(compare:)];
                [view addPropertyLabel:@"Relationships" toMatrix:m];
                for (NSUInteger i = 0, count = [relationshipKeys count]; i < count; i++) {
                        NSString* key = [relationshipKeys objectAtIndex:i];
                        ADD_OBJECT([o valueForKey:key], key, fs_setterForProperty(key), key)
                }

                ADD_CLASS_LABEL(@"NSManagedObject Info");
                ADD_OBJECT([o entity], entity, setEntity, @"Entity")
                ADD_BOOL([o isDeleted], deleted, setisDeleted, @"Is deleted")
                ADD_BOOL([o isInserted], inserted, setisInserted, @"Is inserted")
                ADD_BOOL([o isUpdated], updated, setisUpdated, @"Is updated")
                ADD_OBJECT([o managedObjectContext], managedObjectContext, setManagedObjectContext, @"Managed object context")
                ADD_OBJECT([o objectID], objectID, setObjectID, @"Object ID")
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
                                                ADD_OBJECT(propertyValue, propertyName, fs_setterForProperty(propertyName), propertyName)
                                }
                                free(properties);
                        }
                        if (cls == [cls superclass]) // Defensive programming against flawed class hierarchies with infinite loops.
                                cls = nil;
                        else
                                cls = [cls superclass];
                }
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
        for (Class baseClass in self.baseClasses) {
                if ([object isKindOfClass:baseClass]) {
                        NSString* method = [NSString stringWithFormat:@"add%@:", [baseClass className]];
                        SEL selector = NSSelectorFromString(method);

                        NSAssert([self respondsToSelector:selector], @"Missing base class method");

                        [self performSelector:selector withObject:object];
                        break;
                }
        }
}

- (NSMutableArray*)baseClasses
{
        if (!baseClasses) {
                baseClasses = [[NSMutableArray alloc] initWithObjects:
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
        return baseClasses;
}
- (void)addFSGenericPointer:(id)object
{
        FSGenericPointer* o = object;
        NSArray* memoryContent = [o memoryContent];

        if (memoryContent) {
                ADD_CLASS_LABEL(@"FSGenericPointer Info");
                ADD_OBJECT(memoryContent, memoryContent, setMemoryContent, @"Memory content")
                ADD_OBJECT_NOT_NIL([o memoryContentUTF8], memoryContentUTF8, setMemoryContentUTF8, @"Memory content as UTF8 string")
        }
}

- (void)addFSObjectPointer:(id)object
{
        FSObjectPointer* o = object;
        NSArray* memoryContent = [o memoryContent];

        if (memoryContent) {
                ADD_CLASS_LABEL(@"FSObjectPointer Info");
                ADD_OBJECT(memoryContent, memoryContent, setMemoryContent, @"Memory content")
        }
}

- (void)addNSAffineTransform:(id)object
{
        NSAffineTransform* o = object;
        NSAffineTransformStruct s = [o transformStruct];
        ADD_CLASS_LABEL(@"NSAffineTransform Info");
        ADD_NUMBER(s.m11, transformStruct.m11, setTransformStruct.m11, @"m11")
        ADD_NUMBER(s.m12, transformStruct.m12, setTransformStruct.m12, @"m12")
        ADD_NUMBER(s.m21, transformStruct.m21, setTransformStruct.m21, @"m21")
        ADD_NUMBER(s.m22, transformStruct.m22, setTransformStruct.m22, @"m22")
        ADD_NUMBER(s.tX, transformStruct.tX, setTransformStruct.tX, @"tX")
        ADD_NUMBER(s.tY, transformStruct.tY, setTransformStruct.tY, @"tY")
}

- (void)addNSAlert:(id)object
{
        NSAlert* o = object;
        ADD_CLASS_LABEL(@"NSAlert Info");
        ADD_OBJECT([o accessoryView], accessoryView, setAccessoryView, @"Accessory view")
        ADD_ENUM(AlertStyle, [o alertStyle], alertStyle, setalertStyle, @"Alert style")
        ADD_OBJECTS([o buttons], @"Buttons")
        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
        ADD_OBJECT_NOT_NIL([o helpAnchor], helpAnchor, setHelpAnchor, @"Help anchor")
        ADD_OBJECT([o icon], icon, setIcon, @"Icon")
        ADD_STRING([o informativeText], informativeText, setInformativeText, @"Informative text")
        ADD_STRING([o messageText], messageText, setMessageText, @"Message text")
        ADD_BOOL([o showsHelp], showsHelp, setshowsHelp, @"Shows help")
        ADD_BOOL([o showsSuppressionButton], showsSuppressionButton, setshowsSuppressionButton, @"Shows suppression button")
        ADD_OBJECT([o suppressionButton], suppressionButton, setSuppressionButton, @"Suppression button")
        ADD_OBJECT([o window], window, setWindow, @"Window")
}

- (void)addNSAnimation:(id)object
{
        if ([object isKindOfClass:[NSViewAnimation class]]) {
                NSViewAnimation* o = object;

                if ([o viewAnimations] != nil) {
                        ADD_CLASS_LABEL(@"NSViewAnimation Info");
                        ADD_OBJECTS([o viewAnimations], @"View animations")
                }
        }

        NSAnimation* o = object;
        ADD_CLASS_LABEL(@"NSAnimation Info");
        ADD_ENUM(AnimationBlockingMode, [o animationBlockingMode], animationBlockingMode, setanimationBlockingMode, @"Animation blocking mode")
        ADD_ENUM(AnimationCurve, [o animationCurve], animationCurve, setanimationCurve, @"Animation curve")
        ADD_NUMBER([o currentProgress], currentProgress, setCurrentProgress, @"Current progress")
        ADD_NUMBER([o currentValue], currentValue, setCurrentValue, @"Current value")
        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
        ADD_NUMBER([o duration], duration, setDuration, @"Duration (in seconds)")
        ADD_NUMBER([o frameRate], frameRate, setFrameRate, @"Frame rate")
        ADD_BOOL([o isAnimating], animating, setisAnimating, @"Is animating")
        ADD_OBJECTS([o progressMarks], @"Progress marks")
        ADD_OBJECT([o runLoopModesForAnimating], runLoopModesForAnimating, setRunLoopModesForAnimating, @"Run loop modes for animating")
}

- (void)addNSAnimationContext:(id)object
{
        NSAnimationContext* o = object;
        ADD_CLASS_LABEL(@"NSAnimationContext Info");
        ADD_NUMBER([o duration], duration, setDuration, @"Duration (in seconds)")
}

- (void)addNSAttributedString:(id)object
{
        if ([object isKindOfClass:[NSMutableAttributedString class]]) {
                if ([object isKindOfClass:[NSTextStorage class]]) {
                        NSTextStorage* o = object;
                        ADD_CLASS_LABEL(@"NSTextStorage Info");
                        //ADD_OBJECT(          [o attributeRuns]                      ,@"Attribute runs")
                        ADD_NUMBER([o changeInLength], changeInLength, setChangeInLength, @"Change in length")
                        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_OPTIONS(TextStorageEditedOptions, [o editedMask], editedMask, seteditedMask, @"Edited mask")
                        ADD_RANGE([o editedRange], editedRange, setEditedRange, @"Edited range")
                        ADD_BOOL([o fixesAttributesLazily], fixesAttributesLazily, setfixesAttributesLazily, @"Fixes attributes lazily")
                        ADD_OBJECT([o font], font, setFont, @"Font")
                        ADD_COLOR([o foregroundColor], foregroundColor, setForegroundColor, @"Foreground color")
                        ADD_OBJECTS([o layoutManagers], @"Layout managers")
                        // Note: invoking "paragraphs" and retaining the result cause the result of "layoutManager" to become trash !
                }
        }
}

- (void)addNSBezierPath:(id)object
{
        NSBezierPath* o = object;
        ADD_CLASS_LABEL(@"NSBezierPath Info");
        ADD_RECT([o bounds], bounds, setBounds, @"Bounds")
        ADD_RECT([o controlPointBounds], controlPointBounds, setControlPointBounds, @"Control point bounds")
        if (![o isEmpty])
                ADD_POINT([o currentPoint], currentPoint, setCurrentPoint, @"Current point")
        ADD_NUMBER([o elementCount], elementCount, setElementCount, @"Element count")
        ADD_NUMBER([o flatness], flatness, setFlatness, @"Flatness")
        ADD_BOOL([o isEmpty], empty, setisEmpty, @"Is empty")
        ADD_ENUM(LineCapStyle, [o lineCapStyle], lineCapStyle, setlineCapStyle, @"Line cap style")
        ADD_ENUM(LineJoinStyle, [o lineJoinStyle], lineJoinStyle, setlineJoinStyle, @"Line join style")
        ADD_NUMBER([o lineWidth], lineWidth, setLineWidth, @"Line width")
        ADD_NUMBER([o miterLimit], miterLimit, setMiterLimit, @"Miter limit")
        ADD_ENUM(WindingRule, [o windingRule], windingRule, setwindingRule, @"Winding rule")
}

- (void)addNSCell:(id)object
{
        if ([object isKindOfClass:[NSActionCell class]]) {
                if ([object isKindOfClass:[NSButtonCell class]]) {
                        if ([object isKindOfClass:[NSMenuItemCell class]]) {
                                if ([object isKindOfClass:[NSPopUpButtonCell class]]) {
                                        NSPopUpButtonCell* o = object;
                                        ADD_CLASS_LABEL(@"NSPopUpButtonCell Info");
                                        ADD_BOOL([o altersStateOfSelectedItem], altersStateOfSelectedItem, setaltersStateOfSelectedItem, @"Alters state of selected item")
                                        ADD_ENUM(PopUpArrowPosition, [o arrowPosition], arrowPosition, setarrowPosition, @"Arrow position")
                                        ADD_BOOL([o autoenablesItems], autoenablesItems, setautoenablesItems, @"Autoenables Items")
                                        ADD_NUMBER([o indexOfSelectedItem], indexOfSelectedItem, setIndexOfSelectedItem, @"Index of selected item")
                                        ADD_OBJECTS([o itemArray], @"Item array")
                                        ADD_NUMBER([o numberOfItems], numberOfItems, setNumberOfItems, @"Number of items")
                                        ADD_OBJECT([o objectValue], objectValue, setObjectValue, @"Object value")
                                        ADD_ENUM(RectEdge, [o preferredEdge], preferredEdge, setpreferredEdge, @"Preferred edge")
                                        ADD_BOOL([o pullsDown], pullsDown, setpullsDown, @"Pulls down")
                                        ADD_OBJECT([o selectedItem], selectedItem, setSelectedItem, @"Selected item")
                                        ADD_BOOL([o usesItemFromMenu], usesItemFromMenu, setusesItemFromMenu, @"Uses item from menu")
                                }

                                NSMenuItemCell* o = object;
                                ADD_CLASS_LABEL(@"NSMenuItemCell Info");
                                if ([[o menuItem] image])
                                        ADD_NUMBER([o imageWidth], imageWidth, setImageWidth, @"Image width")
                                ADD_BOOL([o isHighlighted], highlighted, setisHighlighted, @"Is highlighted")
                                if (![[[o menuItem] keyEquivalent] isEqualToString:@""])
                                        ADD_NUMBER([o keyEquivalentWidth], keyEquivalentWidth, setKeyEquivalentWidth, @"Key equivalent width")
                                ADD_OBJECT([o menuItem], menuItem, setMenuItem, @"Menu item")
                                ADD_BOOL([o needsDisplay], needsDisplay, setneedsDisplay, @"Needs display")
                                ADD_BOOL([o needsSizing], needsSizing, setneedsSizing, @"Needs sizing")
                                ADD_NUMBER([o stateImageWidth], stateImageWidth, setStateImageWidth, @"State image width")
                                ADD_NUMBER([o titleWidth], titleWidth, setTitleWidth, @"Title width")
                        }

                        NSButtonCell* o = object;
                        ADD_CLASS_LABEL(@"NSButtonCell Info");
                        ADD_OBJECT_NOT_NIL([o alternateImage], alternateImage, setAlternateImage, @"Alternate image")
                        ADD_STRING([o alternateTitle], alternateTitle, setAlternateTitle, @"Alternate title")
                        ADD_OBJECT([o attributedAlternateTitle], attributedAlternateTitle, setAttributedAlternateTitle, @"Attributed alternate title")
                        ADD_OBJECT([o attributedTitle], attributedTitle, setAttributedTitle, @"Attributed title")
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_ENUM(BezelStyle, [o bezelStyle], bezelStyle, setbezelStyle, @"Bezel style")
                        ADD_ENUM(GradientType, [o gradientType], gradientType, setgradientType, @"Gradient type")
                        ADD_OPTIONS(CellStyleMask, [o highlightsBy], highlightsBy, sethighlightsBy, @"Highlights by")
                        ADD_BOOL([o imageDimsWhenDisabled], imageDimsWhenDisabled, setimageDimsWhenDisabled, @"Image dims when disabled")
                        ADD_ENUM(CellImagePosition, [o imagePosition], imagePosition, setimagePosition, @"Image position")
                        ADD_ENUM(ImageScaling, [o imageScaling], imageScaling, setimageScaling, @"Image scaling")
                        ADD_BOOL([o isTransparent], transparent, setisTransparent, @"Is transparent")
                        ADD_OBJECT_NOT_NIL([o keyEquivalentFont], keyEquivalentFont, setKeyEquivalentFont, @"Key equivalent font")
                        ADD_OPTIONS(EventModifierFlags, [o keyEquivalentModifierMask] & NSDeviceIndependentModifierFlagsMask, keyEquivalentModifierMask, setKeyEquivalentModifierMask, @"Key equivalent modifier mask")
                        ADD_BOOL([o showsBorderOnlyWhileMouseInside], showsBorderOnlyWhileMouseInside, setshowsBorderOnlyWhileMouseInside, @"Shows border only while mouse inside")
                        ADD_OPTIONS(CellStyleMask, [o showsStateBy], showsStateBy, setshowsStateBy, @"Shows state by")
                        ADD_OBJECT_NOT_NIL([o sound], sound, setSound, @"Sound")
                        ADD_STRING([o title], title, setTitle, @"Title")
                }
                else if ([object isKindOfClass:[NSDatePickerCell class]]) {
                        NSDatePickerCell* o = object;
                        ADD_CLASS_LABEL(@"NSDatePickerCell Info");
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT([o calendar], calendar, setCalendar, @"Calendar")
                        ADD_OPTIONS(DatePickerElementFlags, [o datePickerElements], datePickerElements, setdatePickerElements, @"Date picker elements")
                        ADD_ENUM(DatePickerMode, [o datePickerMode], datePickerMode, setdatePickerMode, @"Date picker mode")
                        ADD_ENUM(DatePickerStyle, [o datePickerStyle], datePickerStyle, setdatePickerStyle, @"Date picker style")
                        ADD_OBJECT([o dateValue], dateValue, setDateValue, @"Date value")
                        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                        ADD_OBJECT_NOT_NIL([o locale], locale, setLocale, @"Locale")
                        ADD_OBJECT([o maxDate], maxDate, setMaxDate, @"Max date")
                        ADD_OBJECT([o minDate], minDate, setMinDate, @"Min date")
                        ADD_COLOR([o textColor], textColor, setTextColor, @"Text Color")
                        ADD_NUMBER([o timeInterval], timeInterval, setTimeInterval, @"Time interval")
                        ADD_OBJECT([o timeZone], timeZone, setTimeZone, @"Time zone")
                }
                else if ([object isKindOfClass:[NSFormCell class]]) {
                        NSFormCell* o = object;
                        ADD_CLASS_LABEL(@"NSFormCell Info");
                        ADD_OBJECT([o attributedTitle], attributedTitle, setAttributedTitle, @"Attributed title")
                        ADD_OBJECT_NOT_NIL([o placeholderAttributedString], placeholderAttributedString, setPlaceholderAttributedString, @"Placeholder attributed string")
                        ADD_STRING_NOT_NIL([o placeholderString], placeholderString, setPlaceholderString, @"Placeholder string")
                        ADD_ENUM(TextAlignment, [o titleAlignment], titleAlignment, settitleAlignment, @"Title alignment")
                        ADD_ENUM(WritingDirection, [o titleBaseWritingDirection], titleBaseWritingDirection, settitleBaseWritingDirection, @"Title base writing direction")
                        ADD_OBJECT([o titleFont], titleFont, setTitleFont, @"Title font")
                        ADD_NUMBER([o titleWidth], titleWidth, setTitleWidth, @"Title width")
                }
                else if ([object isKindOfClass:[NSLevelIndicatorCell class]]) {
                        NSLevelIndicatorCell* o = object;
                        ADD_CLASS_LABEL(@"NSLevelIndicatorCell Info");
                        ADD_NUMBER([o criticalValue], criticalValue, setCriticalValue, @"Critical value")
                        ADD_ENUM(LevelIndicatorStyle, [o levelIndicatorStyle], levelIndicatorStyle, setlevelIndicatorStyle, @"Level indicator style")
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                        ADD_NUMBER([o numberOfMajorTickMarks], numberOfMajorTickMarks, setNumberOfMajorTickMarks, @"Number of major tick marks")
                        ADD_NUMBER([o numberOfTickMarks], numberOfTickMarks, setNumberOfTickMarks, @"Number of tick marks")
                        ADD_OBJECT(objectFromTickMarkPosition([o tickMarkPosition], NO), tickMarkPosition, setTickMarkPosition, @"Tick mark position")
                        ADD_NUMBER([o warningValue], warningValue, setWarningValue, @"Warning value")
                }
                else if ([object isKindOfClass:[NSPathCell class]]) {
                        NSPathCell* o = object;
                        ADD_CLASS_LABEL(@"NSPathCell Info");
                        ADD_OBJECTS([o allowedTypes], @"Allowed types")
                        ADD_COLOR_NOT_NIL([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_SEL([o doubleAction], @"Double action")
                        ADD_OBJECTS([o pathComponentCells], @"Path component cells")
                        ADD_ENUM(PathStyle, [o pathStyle], pathStyle, setpathStyle, @"Path style")
                        ADD_OBJECT_NOT_NIL([o placeholderAttributedString], placeholderAttributedString, setPlaceholderAttributedString, @"Placeholder attributed string")
                        ADD_STRING_NOT_NIL([o placeholderString], placeholderString, setPlaceholderString, @"Placeholder string")
                        ADD_OBJECT_NOT_NIL([o URL], URL, setURL, @"URL")
                }
                else if ([object isKindOfClass:[NSSegmentedCell class]]) {
                        NSSegmentedCell* o = object;
                        NSInteger segmentCount = [o segmentCount];
                        ADD_CLASS_LABEL(@"NSSegmentedCell Info");

                        ADD_NUMBER(segmentCount, segmentCount, setSegmentCount, @"Segment count")
                        ADD_NUMBER([o selectedSegment], selectedSegment, setSelectedSegment, @"Selected segment")
                        ADD_ENUM(SegmentSwitchTracking, [o trackingMode], trackingMode, settrackingMode, @"Tracking mode")

                                            [self processSegmentedItem:o];
                }
                else if ([object isKindOfClass:[NSSliderCell class]]) {
                        NSSliderCell* o = object;
                        ADD_CLASS_LABEL(@"NSSliderCell Info");
                        ADD_BOOL([o allowsTickMarkValuesOnly], allowsTickMarkValuesOnly, setallowsTickMarkValuesOnly, @"Allows tick mark values only")
                        ADD_NUMBER([o altIncrementValue], altIncrementValue, setAltIncrementValue, @"Alt increment value")
                        ADD_NUMBER([(NSSliderCell*)o isVertical], vertical, setVertical:, @"Is vertical")
                        ADD_NUMBER([o knobThickness], knobThickness, setKnobThickness, @"Knob thickness")
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                        ADD_NUMBER([o numberOfTickMarks], numberOfTickMarks, setNumberOfTickMarks, @"Number of tick marks")
                        ADD_ENUM(SliderType, [o sliderType], sliderType, setsliderType, @"Slider type")
                        ADD_OBJECT(objectFromTickMarkPosition([o tickMarkPosition], [(NSSliderCell*)o isVertical] == 1), tickMarkPosition, setTickMarkPosition, @"Tick mark position")
                        ADD_RECT([o trackRect], trackRect, setTrackRect, @"Track rect")
                }
                else if ([object isKindOfClass:[NSStepperCell class]]) {
                        NSStepperCell* o = object;
                        ADD_CLASS_LABEL(@"NSStepperCell Info");
                        ADD_BOOL([o autorepeat], autorepeat, setautorepeat, @"Autorepeat")
                        ADD_NUMBER([o increment], increment, setIncrement, @"Increment")
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                        ADD_BOOL([o valueWraps], valueWraps, setvalueWraps, @"Value wraps")
                }
                else if ([object isKindOfClass:[NSTextFieldCell class]]) {
                        if ([object isKindOfClass:[NSComboBoxCell class]]) {
                                NSComboBoxCell* o = object;
                                ADD_CLASS_LABEL(@"NSComboBoxCell Info");
                                if ([o usesDataSource])
                                        ADD_OBJECT([o dataSource], dataSource, setDataSource, @"Data source")
                                ADD_BOOL([o hasVerticalScroller], hasVerticalScroller, sethasVerticalScroller, @"Has vertical scroller")
                                ADD_NUMBER([o indexOfSelectedItem], indexOfSelectedItem, setIndexOfSelectedItem, @"Index of selected item")
                                ADD_SIZE([o intercellSpacing], intercellSpacing, setIntercellSpacing, @"Intercell spacing")
                                ADD_BOOL([o isButtonBordered], buttonBordered, setisButtonBordered, @"Is button bordered")
                                ADD_NUMBER([o itemHeight], itemHeight, setItemHeight, @"Item height")
                                ADD_NUMBER([o numberOfItems], numberOfItems, setNumberOfItems, @"Number of items")
                                ADD_NUMBER([o numberOfVisibleItems], numberOfVisibleItems, setNumberOfVisibleItems, @"Number of visible items")
                                if (![o usesDataSource] && [o indexOfSelectedItem] != -1)
                                        ADD_OBJECT([o objectValueOfSelectedItem], objectValueOfSelectedItem, setObjectValueOfSelectedItem, @"Object value of selected item")
                                if (![o usesDataSource])
                                        ADD_OBJECTS([o objectValues], @"Object values")
                                ADD_BOOL([o usesDataSource], usesDataSource, setusesDataSource, @"Uses data source")
                        }
                        else if ([object isKindOfClass:[NSPathComponentCell class]]) {
                                NSPathComponentCell* o = object;
                                ADD_CLASS_LABEL(@"NSPathComponentCell Info");
                                ADD_OBJECT_NOT_NIL([o image], image, setImage, @"Image")
                                ADD_OBJECT_NOT_NIL([o URL], URL, setURL, @"URL")
                        }
                        else if ([object isKindOfClass:[NSSearchFieldCell class]]) {
                                NSSearchFieldCell* o = object;
                                ADD_CLASS_LABEL(@"NSSearchFieldCell Info");
                                ADD_OBJECT([o cancelButtonCell], cancelButtonCell, setCancelButtonCell, @"Cancel button cell")
                                ADD_NUMBER([o maximumRecents], maximumRecents, setMaximumRecents, @"Maximum recents")
                                ADD_OBJECTS([o recentSearches], @"Recent searches")
                                ADD_OBJECT_NOT_NIL([o recentsAutosaveName], recentsAutosaveName, setRecentsAutosaveName, @"Recents autosave name")
                                ADD_OBJECT([o searchButtonCell], searchButtonCell, setSearchButtonCell, @"Search button cell")
                                ADD_OBJECT_NOT_NIL([o searchMenuTemplate], searchMenuTemplate, setSearchMenuTemplate, @"Search menu template")
                                ADD_BOOL([o sendsSearchStringImmediately], sendsSearchStringImmediately, setsendsSearchStringImmediately, @"Sends search string immediately")
                                ADD_BOOL([o sendsWholeSearchString], sendsWholeSearchString, setsendsWholeSearchString, @"Sends whole search string")
                        }
                        else if ([object isKindOfClass:[NSTokenFieldCell class]]) {
                                NSTokenField* o = object;
                                ADD_CLASS_LABEL(@"NSTokenField Info");
                                ADD_NUMBER([o completionDelay], completionDelay, setCompletionDelay, @"Completion delay")
                                ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                                ADD_OBJECT([o tokenizingCharacterSet], tokenizingCharacterSet, setTokenizingCharacterSet, @"Tokenizing character set")
                                ADD_ENUM(TokenStyle, [o tokenStyle], tokenStyle, settokenStyle, @"Token style")
                        }

                        NSTextFieldCell* o = object;
                        ADD_CLASS_LABEL(@"NSTextFieldCell Info");
                        ADD_OBJECTS([o allowedInputSourceLocales], @"Allowed input source locales")
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_ENUM(TextFieldBezelStyle, [o bezelStyle], bezelStyle, setbezelStyle, @"Bezel style")
                        ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                        ADD_OBJECT_NOT_NIL([o placeholderAttributedString], placeholderAttributedString, setPlaceholderAttributedString, @"Placeholder attributed string")
                        ADD_STRING_NOT_NIL([o placeholderString], placeholderString, setPlaceholderString, @"Placeholder string")
                        ADD_COLOR([o textColor], textColor, setTextColor, @"Text color")
                }
        }
        else if ([object isKindOfClass:[NSBrowserCell class]]) {
                NSBrowserCell* o = object;
                ADD_CLASS_LABEL(@"NSBrowserCell Info");
                ADD_OBJECT_NOT_NIL([o alternateImage], alternateImage, setAlternateImage, @"Alternate image")
                ADD_BOOL([o isLeaf], leaf, setisLeaf, @"Is leaf")
                ADD_BOOL([o isLoaded], loaded, setisLoaded, @"Is loaded")
        }
        else if ([object isKindOfClass:[NSImageCell class]]) {
                NSImageCell* o = object;
                ADD_CLASS_LABEL(@"NSImageCell Info");
                ADD_ENUM(ImageAlignment, [o imageAlignment], imageAlignment, setimageAlignment, @"Image alignment")
                ADD_ENUM(ImageScaling, [o imageScaling], imageScaling, setimageScaling, @"Image scaling")
        }
        else if ([object isKindOfClass:[NSTextAttachmentCell class]]) {
                NSTextAttachmentCell* o = object;
                ADD_CLASS_LABEL(@"NSTextAttachmentCell Info");
                ADD_OBJECT([o attachment], attachment, setAttachment, @"Attachment")
                ADD_POINT([o cellBaselineOffset], cellBaselineOffset, setCellBaselineOffset, @"Cell baseline offset")
                ADD_SIZE([o cellSize], cellSize, setCellSize, @"Cell size")
                ADD_BOOL([o wantsToTrackMouse], wantsToTrackMouse, setwantsToTrackMouse, @"Wants to track mouse")
        }

        NSCell* o = object;
        ADD_CLASS_LABEL(@"NSCell Info");
        ADD_BOOL([o acceptsFirstResponder], acceptsFirstResponder, setacceptsFirstResponder, @"Accepts first responder")
        ADD_SEL_NOT_NULL([o action], @"Action")
        ADD_ENUM(TextAlignment, [o alignment], alignment, setalignment, @"Alignment")
        ADD_BOOL([o allowsEditingTextAttributes], allowsEditingTextAttributes, setallowsEditingTextAttributes, @"Allows editing text attributes")
        ADD_BOOL([o allowsMixedState], allowsMixedState, setallowsMixedState, @"Allows mixed state")
        ADD_BOOL([o allowsUndo], allowsUndo, setallowsUndo, @"Allows undo")
        //ADD_OBJECT(              [o attributedStringValue]              ,@"Attributed string value")
        ADD_ENUM(BackgroundStyle, [o backgroundStyle], backgroundStyle, setbackgroundStyle, @"Background style")
        ADD_ENUM(WritingDirection, [o baseWritingDirection], baseWritingDirection, setbaseWritingDirection, @"Base writing direction")
        ADD_SIZE([o cellSize], cellSize, setCellSize, @"Cell size")
        ADD_ENUM(ControlSize, [o controlSize], controlSize, setcontrolSize, @"Control size")
        ADD_ENUM(ControlTint, [o controlTint], controlTint, setcontrolTint, @"Control tint")
        ADD_OBJECT_NOT_NIL([o controlView], controlView, setControlView, @"Control view")
        ADD_ENUM(FocusRingType, [o focusRingType], focusRingType, setfocusRingType, @"Focus ring type")
        ADD_OBJECT([o font], font, setFont, @"Font")
        ADD_OBJECT_NOT_NIL([o formatter], formatter, setFormatter, @"Formatter")
        ADD_OBJECT_NOT_NIL([o image], image, setImage, @"Image")
        if ([(NSCell*)o type] == NSTextCellType)
                ADD_BOOL([o importsGraphics], importsGraphics, setimportsGraphics, @"Imports graphics")
        ADD_ENUM(BackgroundStyle, [o interiorBackgroundStyle], interiorBackgroundStyle, setinteriorBackgroundStyle, @"Interior background style")
        ADD_BOOL([o isBezeled], bezeled, setisBezeled, @"Is bezeled")
        ADD_BOOL([o isBordered], bordered, setisBordered, @"Is bordered")
        ADD_BOOL([o isContinuous], continuous, setisContinuous, @"Is continuous")
        ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
        ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
        ADD_BOOL([o isHighlighted], highlighted, setisHighlighted, @"Is highlighted")
        ADD_BOOL([o isOpaque], opaque, setisOpaque, @"Is opaque")
        ADD_BOOL([o isScrollable], scrollable, setisScrollable, @"Is scrollable")
        ADD_BOOL([o isSelectable], selectable, setisSelectable, @"Is selectable")
        if ([[o keyEquivalent] length] != 0)
                ADD_STRING([o keyEquivalent], keyEquivalent, setKeyEquivalent, @"Key equivalent")
        ADD_ENUM(LineBreakMode, [o lineBreakMode], lineBreakMode, setlineBreakMode, @"Line break mode")
        ADD_OBJECT_NOT_NIL([o menu], menu, setMenu, @"Menu")
        if ([[o mnemonic] length] != 0)
                ADD_STRING([o mnemonic], mnemonic, setMnemonic, @"Mnemonic")
        if ([o mnemonicLocation] != NSNotFound)
                ADD_NUMBER([o mnemonicLocation], mnemonicLocation, setMnemonicLocation, @"Mnemonic location")
        ADD_ENUM(CellStateValue, [o nextState], nextState, setnextState, @"Next state")
        //ADD_OBJECT(              [o objectValue]                        ,@"Object value")
        ADD_BOOL([o refusesFirstResponder], refusesFirstResponder, setrefusesFirstResponder, @"Refuses first responder")
        ADD_OBJECT_NOT_NIL([o representedObject], representedObject, setRepresentedObject, @"Represented object")
        ADD_BOOL([o sendsActionOnEndEditing], sendsActionOnEndEditing, setsendsActionOnEndEditing, @"Sends action on end editing")
        ADD_BOOL([o showsFirstResponder], showsFirstResponder, setshowsFirstResponder, @"Shows first responder")
        ADD_ENUM(CellStateValue, [o state], state, setstate, @"State")
        ADD_NUMBER([o tag], tag, setTag, @"Tag")
        ADD_OBJECT_NOT_NIL([o target], target, setTarget, @"Target")
        ADD_OPTIONS(CellType, [(NSCell*)o type], type, setType, @"Type")
        ADD_BOOL([o wantsNotificationForMarkedText], wantsNotificationForMarkedText, setwantsNotificationForMarkedText, @"Wants notification for marked text")
        ADD_BOOL([o wraps], wraps, setwraps, @"Wraps")
}

- (void)addNSCollectionViewItem:(id)object
{
        NSCollectionViewItem* o = object;
        ADD_CLASS_LABEL(@"NSCollectionViewItem Info");
        ADD_OBJECT([o collectionView], collectionView, setCollectionView, @"Collection view")
        ADD_BOOL([o isSelected], selected, setisSelected, @"Is selected")
        ADD_OBJECT([o representedObject], representedObject, setRepresentedObject, @"Represented object")
        ADD_OBJECT_NOT_NIL([o view], view, setView, @"View")
}

- (void)addNSComparisonPredicate:(id)object
{
        NSComparisonPredicate* o = object;
        ADD_CLASS_LABEL(@"NSComparisonPredicate Info");
        ADD_ENUM(ComparisonPredicateModifier, [o comparisonPredicateModifier], comparisonPredicateModifier, setcomparisonPredicateModifier, @"Comparison predicate modifier")
        ADD_SEL_NOT_NULL([o customSelector], @"Custom selector")
        ADD_OBJECT([o leftExpression], leftExpression, setLeftExpression, @"Left expression")
        ADD_ENUM(PredicateOperatorType, [o predicateOperatorType], predicateOperatorType, setpredicateOperatorType, @"Predicate operator type")
        ADD_OBJECT([o rightExpression], rightExpression, setRightExpression, @"Right expression")
}

- (void)addNSCompoundPredicate:(id)object
{
        NSCompoundPredicate* o = object;
        ADD_CLASS_LABEL(@"NSCompoundPredicate Info")
        ADD_ENUM(CompoundPredicateType, [o compoundPredicateType], compoundPredicateType, setcompoundPredicateType, @"Compound predicate type")
        ADD_OBJECTS([o subpredicates], @"Subpredicates")
}

- (void)addNSController:(id)object
{
        if ([object isKindOfClass:[NSObjectController class]]) {
                if ([object isKindOfClass:[NSArrayController class]]) {
                        if ([object isKindOfClass:[NSDictionaryController class]]) {
                                NSDictionaryController* o = object;
                                ADD_CLASS_LABEL(@"NSDictionaryController Info");
                                ADD_OBJECTS([o excludedKeys], @"Excluded keys")
                                ADD_OBJECTS([o includedKeys], @"Included keys")
                                ADD_OBJECT([o initialKey], initialKey, setInitialKey, @"Initial key")
                                ADD_OBJECT([o initialValue], initialValue, setInitialValue, @"Initial value")
                                ADD_DICTIONARY([o localizedKeyDictionary], @"Localized key dictionary")
                                ADD_OBJECT_NOT_NIL([o localizedKeyTable], localizedKeyTable, setLocalizedKeyTable, @"Localized key table")
                        }

                        NSArrayController* o = object;
                        ADD_CLASS_LABEL(@"NSArrayController Info");
                        ADD_BOOL([o alwaysUsesMultipleValuesMarker], alwaysUsesMultipleValuesMarker, setalwaysUsesMultipleValuesMarker, @"Always uses multiple values marker")
                        ADD_BOOL([o automaticallyRearrangesObjects], automaticallyRearrangesObjects, setautomaticallyRearrangesObjects, @"Automatically rearranges objects")
                        ADD_OBJECTS([o automaticRearrangementKeyPaths], @"Automatic rearrangement key paths")
                        ADD_BOOL([o avoidsEmptySelection], avoidsEmptySelection, setavoidsEmptySelection, @"Avoids empty selection")
                        ADD_BOOL([o clearsFilterPredicateOnInsertion], clearsFilterPredicateOnInsertion, setclearsFilterPredicateOnInsertion, @"Clears filter predicate on insertion")
                        ADD_BOOL([o canInsert], canInsert, setcanInsert, @"Can insert")
                        ADD_BOOL([o canSelectNext], canSelectNext, setcanSelectNext, @"Can select next")
                        ADD_BOOL([o canSelectPrevious], canSelectPrevious, setcanSelectPrevious, @"Can select previous")
                        ADD_OBJECT_NOT_NIL([o filterPredicate], filterPredicate, setFilterPredicate, @"Filter predicate")
                        ADD_BOOL([o preservesSelection], preservesSelection, setpreservesSelection, @"Preserves selection")
                        if ([o selectionIndex] != NSNotFound)
                                ADD_NUMBER([o selectionIndex], selectionIndex, setSelectionIndex, @"Selection index")
                        ADD_OBJECT([o selectionIndexes], selectionIndexes, setSelectionIndexes, @"Selection indexes")
                        ADD_BOOL([o selectsInsertedObjects], selectsInsertedObjects, setselectsInsertedObjects, @"Selects inserted Objects")
                        ADD_OBJECTS([o sortDescriptors], @"Sort descriptors")
                }
                else if ([object isKindOfClass:[NSTreeController class]]) {
                        NSTreeController* o = object;
                        ADD_CLASS_LABEL(@"NSTreeController Info");
                        ADD_BOOL([o alwaysUsesMultipleValuesMarker], alwaysUsesMultipleValuesMarker, setalwaysUsesMultipleValuesMarker, @"Always uses multiple values marker")
                        ADD_BOOL([o avoidsEmptySelection], avoidsEmptySelection, setavoidsEmptySelection, @"Avoids empty selection")
                        ADD_BOOL([o canAddChild], canAddChild, setcanAddChild, @"Can add child")
                        ADD_BOOL([o canInsert], canInsert, setcanInsert, @"Can insert")
                        ADD_BOOL([o canInsertChild], canInsertChild, setcanInsertChild, @"Can insert child")
                        ADD_OBJECT([o childrenKeyPath], childrenKeyPath, setChildrenKeyPath, @"Children key path")
                        ADD_OBJECT([o countKeyPath], countKeyPath, setCountKeyPath, @"Count key path")
                        ADD_OBJECT([o leafKeyPath], leafKeyPath, setLeafKeyPath, @"Leaf key path")
                        ADD_BOOL([o preservesSelection], preservesSelection, setpreservesSelection, @"Preserves selection")
                        ADD_OBJECTS([o selectedNodes], @"Selected nodes")
                        ADD_OBJECTS([o selectedObjects], @"Selected objects")
                        ADD_OBJECTS([o selectionIndexPaths], @"Selection index paths")
                        ADD_BOOL([o selectsInsertedObjects], selectsInsertedObjects, setselectsInsertedObjects, @"Selects inserted Objects")
                        ADD_OBJECTS([o sortDescriptors], @"Sort descriptors")
                }

                NSObjectController* o = object;
                ADD_CLASS_LABEL(@"NSObjectController Info");
                ADD_BOOL([o automaticallyPreparesContent], automaticallyPreparesContent, setautomaticallyPreparesContent, @"Automatically prepares content")
                ADD_BOOL([o canAdd], canAdd, setcanAdd, @"Can add")
                ADD_BOOL([o canRemove], canRemove, setcanRemove, @"Can remove")
                ADD_OBJECT([o content], content, setContent, @"Content")
                if ([o managedObjectContext] != nil) // Do not work when there is no managedObjectContext associated with the object
                        ADD_OBJECT_NOT_NIL([o defaultFetchRequest], defaultFetchRequest, setDefaultFetchRequest, @"Default fetch request")
                ADD_OBJECT_NOT_NIL([o entityName], entityName, setEntityName, @"Entity name")
                ADD_OBJECT_NOT_NIL([o fetchPredicate], fetchPredicate, setFetchPredicate, @"Fetch predicate")
                ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
                ADD_OBJECT_NOT_NIL([o managedObjectContext], managedObjectContext, setManagedObjectContext, @"Managed object context")
                ADD_OBJECT([o objectClass], objectClass, setObjectClass, @"Object class")
                ADD_OBJECTS([o selectedObjects], @"Selected objects")
                ADD_OBJECT([o selection], selection, setSelection, @"Selection")
                ADD_BOOL([o usesLazyFetching], usesLazyFetching, setusesLazyFetching, @"Uses lazy fetching")
        }
        else if ([object isKindOfClass:[NSUserDefaultsController class]]) {
                NSUserDefaultsController* o = object;
                ADD_CLASS_LABEL(@"NSUserDefaultsController Info");
                ADD_BOOL([o appliesImmediately], appliesImmediately, setappliesImmediately, @"Applies immediately")
                ADD_OBJECT([o defaults], defaults, setDefaults, @"Defaults")
                ADD_BOOL([o hasUnappliedChanges], hasUnappliedChanges, sethasUnappliedChanges, @"Has unapplied changes")
                ADD_OBJECT([o initialValues], initialValues, setInitialValues, @"Initial values")
                ADD_OBJECT([o values], values, setValues, @"Values")
        }

        NSController* o = object;
        ADD_CLASS_LABEL(@"NSController Info");
        ADD_BOOL([o isEditing], editing, setisEditing, @"Is editing")
}

- (void)addNSCursor:(id)object
{
        NSCursor* o = object;
        ADD_CLASS_LABEL(@"NSCursor Info");
        ADD_POINT([o hotSpot], hotSpot, setHotSpot, @"HotSpot")
        ADD_OBJECT([o image], image, setImage, @"Image")
        ADD_BOOL([o isSetOnMouseEntered], setOnMouseEntered, setisSetOnMouseEntered, @"Is set on mouse entered")
        ADD_BOOL([o isSetOnMouseExited], setOnMouseExited, setisSetOnMouseExited, @"Is set on mouse exited")
}

- (void)addNSDockTile:(id)object
{
        NSDockTile* o = object;
        ADD_CLASS_LABEL(@"NSDockTile Info");
        ADD_OBJECT([o badgeLabel], badgeLabel, setBadgeLabel, @"Badge label")
        ADD_OBJECT([o contentView], contentView, setContentView, @"Content view")
        ADD_OBJECT([o owner], owner, setOwner, @"Owner")
        ADD_BOOL([o showsApplicationBadge], showsApplicationBadge, setshowsApplicationBadge, @"Shows application badge")
        ADD_SIZE([o size], size, setSize, @"Size")
}

- (void)addNSDocument:(id)object
{
        NSDocument* o = object;
        ADD_CLASS_LABEL(@"NSDocument Info");
        ADD_OBJECT_NOT_NIL([o autosavedContentsFileURL], autosavedContentsFileURL, setAutosavedContentsFileURL, @"Autosaved contents file URL")
        ADD_OBJECT([o autosavingFileType], autosavingFileType, setAutosavingFileType, @"Autosaving file type")
        ADD_OBJECT([o displayName], displayName, setDisplayName, @"Display name")
        ADD_OBJECT([o fileModificationDate], fileModificationDate, setFileModificationDate, @"File modification date")
        ADD_BOOL([o fileNameExtensionWasHiddenInLastRunSavePanel], fileNameExtensionWasHiddenInLastRunSavePanel, setfileNameExtensionWasHiddenInLastRunSavePanel, @"File name extension was hidden in last run save panel")
        ADD_OBJECT([o fileType], fileType, setFileType, @"File type")
        ADD_OBJECT([o fileTypeFromLastRunSavePanel], fileTypeFromLastRunSavePanel, setFileTypeFromLastRunSavePanel, @"File type from last run save panel")
        ADD_OBJECT_NOT_NIL([o fileURL], fileURL, setFileURL, @"File URL")
        ADD_BOOL([o hasUnautosavedChanges], hasUnautosavedChanges, sethasUnautosavedChanges, @"Has unautosaved changes")
        ADD_BOOL([o hasUndoManager], hasUndoManager, sethasUndoManager, @"Has undo manager")
        ADD_BOOL([o isDocumentEdited], documentEdited, setisDocumentEdited, @"Is document edited")
        ADD_BOOL([o keepBackupFile], keepBackupFile, setkeepBackupFile, @"Keep backup file")
        ADD_OBJECT([o fileTypeFromLastRunSavePanel], fileTypeFromLastRunSavePanel, setFileTypeFromLastRunSavePanel, @"File type from last run save panel")
        ADD_OBJECT([o printInfo], printInfo, setPrintInfo, @"Print info")
        ADD_BOOL([o shouldRunSavePanelWithAccessoryView], shouldRunSavePanelWithAccessoryView, setshouldRunSavePanelWithAccessoryView, @"Should run save panel with accessory view")
        ADD_OBJECTS([o windowControllers], @"Window controllers")
        ADD_OBJECT([o windowForSheet], windowForSheet, setWindowForSheet, @"Window for sheet")
        ADD_OBJECT([o windowNibName], windowNibName, setWindowNibName, @"Window nib name")
}

- (void)addNSDocumentController:(id)object
{
        NSDocumentController* o = object;
        ADD_CLASS_LABEL(@"NSDocumentController Info");
        ADD_NUMBER([o autosavingDelay], autosavingDelay, setAutosavingDelay, @"Autosaving delay")
        ADD_OBJECT([o currentDirectory], currentDirectory, setCurrentDirectory, @"Current directory")
        ADD_OBJECT([o currentDocument], currentDocument, setCurrentDocument, @"Current document")
        ADD_OBJECT([o defaultType], defaultType, setDefaultType, @"Default type")
        ADD_OBJECTS([o documentClassNames], @"Document class names")
        ADD_OBJECTS([o documents], @"Documents")
        ADD_BOOL([o hasEditedDocuments], hasEditedDocuments, sethasEditedDocuments, @"Has edited documents")
        ADD_NUMBER([o maximumRecentDocumentCount], maximumRecentDocumentCount, setMaximumRecentDocumentCount, @"Maximum recent document count")
        ADD_OBJECT([o recentDocumentURLs], recentDocumentURLs, setRecentDocumentURLs, @"Recent document URLs")
}

- (void)addNSEntityDescription:(id)object
{
        NSEntityDescription* o = object;
        ADD_CLASS_LABEL(@"NSEntityDescription Info");
        ADD_DICTIONARY([o attributesByName], @"Attributes by name")
        ADD_BOOL([o isAbstract], abstract, setisAbstract, @"Is abstract")
        ADD_OBJECT([o managedObjectClassName], managedObjectClassName, setManagedObjectClassName, @"Managed object class name")
        ADD_OBJECT([o managedObjectModel], managedObjectModel, setManagedObjectModel, @"Managed object model")
        ADD_OBJECT([o name], name, setName, @"Name")
        ADD_DICTIONARY([o relationshipsByName], @"Relationships by name")
        if ([[o subentities] count] != 0) {
                ADD_DICTIONARY([o subentitiesByName], @"Subentities by Name")
        }
        ADD_OBJECT([o superentity], superentity, setSuperentity, @"Superentity")
        ADD_DICTIONARY([o userInfo], @"User info")
}

- (void)addNSEvent:(id)object
{
        NSEvent* o = object;
        NSEventType type = [o type];
        ADD_CLASS_LABEL(@"NSEvent Info");

        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype)) {
                ADD_NUMBER([o absoluteX], absoluteX, setAbsoluteX, @"Absolute x")
                ADD_NUMBER([o absoluteY], absoluteY, setAbsoluteY, @"Absolute y")
                ADD_NUMBER([o absoluteZ], absoluteZ, setAbsoluteZ, @"Absolute z")
                ADD_OPTIONS(EventButtonMask, [o buttonMask], buttonMask, setbuttonMask, @"Button mask")
        }
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp)
                ADD_NUMBER([o buttonNumber], buttonNumber, setButtonNumber, @"Button number")

        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype))
                ADD_NUMBER([o capabilityMask], capabilityMask, setCapabilityMask, @"Capability mask")

        if (type == NSKeyDown || type == NSKeyUp) {
                ADD_OBJECT([(NSEvent*)o characters], characters, setCharacters, @"Characters")
                ADD_OBJECT([o charactersIgnoringModifiers], charactersIgnoringModifiers, setCharactersIgnoringModifiers, @"Characters ignoring modifiers")
        }
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp)
                ADD_NUMBER([o clickCount], clickCount, setClickCount, @"Click count")
        if (type == NSAppKitDefined || type == NSSystemDefined || type == NSApplicationDefined) {
                ADD_NUMBER([o data1], data1, setData1, @"Data1")
                ADD_NUMBER([o data2], data2, setData2, @"Data2")
        }
        if (type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) {
                ADD_NUMBER([o deltaX], deltaX, setDeltaX, @"Delta x")
                ADD_NUMBER([o deltaY], deltaY, setDeltaY, @"Delta y")
                ADD_NUMBER([o deltaZ], deltaZ, setDeltaZ, @"Delta z")
        }

        if (type == NSTabletPoint || type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && ([object subtype] == NSTabletProximityEventSubtype || [object subtype] == NSTabletPointEventSubtype)))
                ADD_NUMBER([o deviceID], deviceID, setDeviceID, @"Device ID")
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel || type == NSMouseEntered || type == NSMouseExited || type == NSCursorUpdate)
                ADD_NUMBER([o eventNumber], eventNumber, setEventNumber, @"Event number")
        if (type == NSKeyDown)
                ADD_BOOL([o isARepeat], aRepeat, setisARepeat, @"Is a repeat")
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype))
                ADD_BOOL([o isEnteringProximity], enteringProximity, setisEnteringProximity, @"Is entering proximity")
        if (type == NSKeyDown || type == NSKeyUp)
                ADD_NUMBER([o keyCode], keyCode, setKeyCode, @"Key code")
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel)
                ADD_POINT([o locationInWindow], locationInWindow, setLocationInWindow, @"Location in window")
        ADD_OPTIONS(EventModifierFlags, [o modifierFlags] & NSDeviceIndependentModifierFlagsMask, modifierFlags, setModifierFlags, @"Modifier flags")
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype)) {
                ADD_NUMBER([o pointingDeviceID], pointingDeviceID, setPointingDeviceID, @"Pointing device ID")
                ADD_NUMBER([o pointingDeviceSerialNumber], pointingDeviceSerialNumber, setPointingDeviceSerialNumber, @"Pointing device serial number")
                ADD_ENUM(PointingDeviceType, [o pointingDeviceType], pointingDeviceType, setpointingDeviceType, @"Pointing device type")
        }
        if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel)
                ADD_NUMBER([o pressure], pressure, setPressure, @"Pressure")
        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype))
                ADD_NUMBER([o rotation], rotation, setRotation, @"Rotation")
        if (type == NSAppKitDefined || type == NSSystemDefined || type == NSApplicationDefined || type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel)
                ADD_ENUM(EventSubtype, [o subtype], subtype, setsubtype, @"Subtype")
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype)) {
                ADD_NUMBER([o systemTabletID], systemTabletID, setSystemTabletID, @"System tablet ID")
                ADD_NUMBER([o tabletID], tabletID, setTabletID, @"Tablet ID")
        }
        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype)) {
                ADD_NUMBER([o tangentialPressure], tangentialPressure, setTangentialPressure, @"Tangential pressure")
                ADD_POINT([o tilt], tilt, setTilt, @"Tilt")
        }
        ADD_NUMBER([o timestamp], timestamp, setTimestamp, @"Timestamp")
        if (type == NSMouseEntered || type == NSMouseExited || type == NSCursorUpdate) {
                ADD_OBJECT([o trackingArea], trackingArea, setTrackingArea, @"Tracking area")
                ADD_NUMBER([o trackingNumber], trackingNumber, setTrackingNumber, @"Tracking number")
        }
        ADD_ENUM(EventType, [(NSEvent*)o type], type, setType, @"Type")
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype))
                ADD_NUMBER([o uniqueID], uniqueID, setUniqueID, @"Unique ID")
        if (type == NSMouseEntered || type == NSMouseExited || type == NSCursorUpdate) {
                void* userData = [o userData];
                if (userData)
                        ADD_POINTER([o userData], @"User data")
        }
        if (type == NSTabletPoint || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletPointEventSubtype))
                ADD_OBJECT([o vendorDefined], vendorDefined, setVendorDefined, @"Vendor defined")
        if (type == NSTabletProximity || ((type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSOtherMouseDown || type == NSOtherMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSOtherMouseDragged || type == NSScrollWheel) && [object subtype] == NSTabletProximityEventSubtype)) {
                ADD_NUMBER([o vendorID], vendorID, setVendorID, @"Vendor ID")
                ADD_NUMBER([o vendorPointingDeviceType], vendorPointingDeviceType, setVendorPointingDeviceType, @"Vendor pointing device type")
        }
        if (type != NSPeriodic)
                ADD_OBJECT([o window], window, setWindow, @"Window")
}

- (void)addNSExpression:(id)object
{
        NSExpression* o = object;
        NSArray* arguments = nil;
        id collection = nil;
        id constantValue = nil;
        NSExpressionType expressionType = 0;
        NSString* function = nil;
        NSString* keyPath = nil;
        NSExpression* leftExpression = nil;
        NSExpression* operand = nil;
        NSPredicate* predicate = nil;
        NSExpression* rightExpression = nil;
        NSString* variable = nil;

        BOOL argumentsIsInitialized = NO;
        BOOL collectionIsInitialized = NO;
        BOOL constantValueIsInitialized = NO;
        BOOL expressionTypeIsInitialized = NO;
        BOOL functionIsInitialized = NO;
        BOOL keyPathIsInitialized = NO;
        BOOL leftExpressionIsInitialized = NO;
        BOOL operandIsInitialized = NO;
        BOOL predicateIsInitialized = NO;
        BOOL rightExpressionIsInitialized = NO;
        BOOL variableIsInitialized = NO;

        @try {
                arguments = [o arguments];
                argumentsIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                collection = [o collection];
                collectionIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                constantValue = [o constantValue];
                constantValueIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                expressionType = [o expressionType];
                expressionTypeIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                function = [o function];
                functionIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                keyPath = [o keyPath];
                keyPathIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                leftExpression = [o leftExpression];
                leftExpressionIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                operand = [o operand];
                operandIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                predicate = [o predicate];
                predicateIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                rightExpression = [o rightExpression];
                rightExpressionIsInitialized = YES;
        }
        @catch (id exception) {}
        @try {
                variable = [o variable];
                variableIsInitialized = YES;
        }
        @catch (id exception) {}

        ADD_CLASS_LABEL(@"NSExpression Info");

        if (argumentsIsInitialized)
                ADD_OBJECTS(arguments, @"Arguments");
        if (collectionIsInitialized)
                ADD_OBJECT_RO(collection, @"Collection");
        if (constantValueIsInitialized)
                ADD_OBJECT_RO(constantValue, @"Constant value");
        if (expressionTypeIsInitialized)
                ADD_ENUM(ExpressionType, expressionType, expressionType, setExpressionType, @"Expression type");
        if (functionIsInitialized)
                ADD_OBJECT_RO(function, @"Function");
        if (keyPathIsInitialized)
                ADD_OBJECT_RO(keyPath, @"Key path");
        if (leftExpressionIsInitialized)
                ADD_OBJECT_RO(leftExpression, @"Left expression");
        if (operandIsInitialized)
                ADD_OBJECT_RO(operand, @"Operand");
        if (predicateIsInitialized)
                ADD_OBJECT_RO(predicate, @"Predicate");
        if (rightExpressionIsInitialized)
                ADD_OBJECT_RO(leftExpression, @"Right expression");
        if (variableIsInitialized)
                ADD_OBJECT_RO(variable, @"Variable");
}

- (void)addNSFetchRequest:(id)object
{
        NSFetchRequest* o = object;
        ADD_CLASS_LABEL(@"NSFetchRequest Info");
        ADD_OBJECTS([o affectedStores], @"Affected stores")
        ADD_OBJECT([o entity], entity, setEntity, @"Entity")
        ADD_NUMBER([o fetchLimit], fetchLimit, setFetchLimit, @"Fetch limit")
        ADD_BOOL([o includesPropertyValues], includesPropertyValues, setincludesPropertyValues, @"Includes property values")
        ADD_BOOL([o includesSubentities], includesSubentities, setincludesSubentities, @"Includes bubentities")
        ADD_OBJECT([o predicate], predicate, setPredicate, @"Predicate")
        ADD_OBJECTS([o relationshipKeyPathsForPrefetching], @"Relationship key paths for prefetching")
        ADD_ENUM(FetchRequestResultType, [o resultType], resultType, setresultType, @"Result type")
        ADD_BOOL([o returnsObjectsAsFaults], returnsObjectsAsFaults, setreturnsObjectsAsFaults, @"Returns objects as faults")
        ADD_OBJECTS([o sortDescriptors], @"Sort descriptors")
}

- (void)addNSFileWrapper:(id)object
{
        NSFileWrapper* o = object;
        ADD_CLASS_LABEL(@"NSFileWrapper Info");
        ADD_DICTIONARY([o fileAttributes], @"File attributes")
        ADD_OBJECT([o filename], filename, setFilename, @"Filename")
        ADD_OBJECT_NOT_NIL([o icon], icon, setIcon, @"Icon")
        ADD_BOOL([o isDirectory], directory, setisDirectory, @"Is directory")
        ADD_BOOL([o isRegularFile], regularFile, setisRegularFile, @"Is regularFile")
        ADD_BOOL([o isSymbolicLink], symbolicLink, setisSymbolicLink, @"Is symbolic link")
        ADD_OBJECT_NOT_NIL([o preferredFilename], preferredFilename, setPreferredFilename, @"Preferred filename")
        if ([o isSymbolicLink])
                ADD_OBJECT_NOT_NIL([o symbolicLinkDestination], symbolicLinkDestination, setSymbolicLinkDestination, @"Symbolic link destination")
}

- (void)addNSFont:(id)object
{
        NSFont* o = object;
        ADD_CLASS_LABEL(@"NSFont Info");
        ADD_NUMBER([o ascender], ascender, setAscender, @"Ascender")
        ADD_RECT([o boundingRectForFont], boundingRectForFont, setBoundingRectForFont, @"Bounding rect for font")
        ADD_NUMBER([o capHeight], capHeight, setCapHeight, @"Cap height")
        ADD_OBJECT([o coveredCharacterSet], coveredCharacterSet, setCoveredCharacterSet, @"Covered character set")
        ADD_NUMBER([o descender], descender, setDescender, @"Descender")
        ADD_OBJECT([o displayName], displayName, setDisplayName, @"Display name")
        ADD_OBJECT([o familyName], familyName, setFamilyName, @"Family name")
        ADD_OBJECT([o fontDescriptor], fontDescriptor, setFontDescriptor, @"Font descriptor")
        ADD_OBJECT([o fontName], fontName, setFontName, @"Font name")
        ADD_BOOL([o isFixedPitch], fixedPitch, setisFixedPitch, @"Is fixedPitch")
        ADD_NUMBER([o italicAngle], italicAngle, setItalicAngle, @"Italic angle")
        ADD_NUMBER([o leading], leading, setLeading, @"Leading")

        const CGFloat* matrix = [o matrix];
        NSString* matrixString = [NSString stringWithFormat:@"[%g %g %g %g %g %g]", (double)(matrix[0]), (double)(matrix[1]), (double)(matrix[2]), (double)(matrix[3]), (double)(matrix[4]), (double)(matrix[5])];
        [view addObject:matrixString withLabel:@"Matrix" toMatrix:m leaf:YES classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:0];

        ADD_SIZE([o maximumAdvancement], maximumAdvancement, setMaximumAdvancement, @"Maximum advancement")
        ADD_ENUM(StringEncoding, [o mostCompatibleStringEncoding], mostCompatibleStringEncoding, setmostCompatibleStringEncoding, @"Most compatible string encoding")
        ADD_NUMBER([o numberOfGlyphs], numberOfGlyphs, setNumberOfGlyphs, @"Number of glyphs")
        ADD_NUMBER([o pointSize], pointSize, setPointSize, @"Point size")
        ADD_OBJECT([o printerFont], printerFont, setPrinterFont, @"Printer font")
        ADD_ENUM(FontRenderingMode, [o renderingMode], renderingMode, setrenderingMode, @"Rendering mode")
        ADD_OBJECT_NOT_NIL([o screenFont], screenFont, setScreenFont, @"Screen font")
        ADD_NUMBER([o underlinePosition], underlinePosition, setUnderlinePosition, @"Underline position")
        ADD_NUMBER([o underlineThickness], underlineThickness, setUnderlineThickness, @"Underline thickness")
        ADD_NUMBER([o xHeight], xHeight, setXHeight, @"xHeight")
}

- (void)addNSFontDescriptor:(id)object
{
        NSFontDescriptor* o = object;
        ADD_CLASS_LABEL(@"NSFontDescriptor Info");
        ADD_DICTIONARY([o fontAttributes], @"Font attributes")
        ADD_OBJECT([o matrix], matrix, setMatrix, @"Matrix")
        ADD_NUMBER([o pointSize], pointSize, setPointSize, @"Point size")
        ADD_OBJECT([o postscriptName], postscriptName, setPostscriptName, @"Postscript name")
        ADD_NUMBER([o symbolicTraits], symbolicTraits, setSymbolicTraits, @"Symbolic traits")
}

- (void)addNSFontManager:(id)object
{
        NSFontManager* o = object;
        ADD_CLASS_LABEL(@"NSFontManager Info");
        ADD_SEL([o action], @"Action")
        ADD_OBJECTS([o availableFontFamilies], @"Available font families")
        ADD_OBJECTS([o availableFonts], @"Available fonts")
        ADD_OBJECTS([o collectionNames], @"Collection names")
        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
        ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
        ADD_BOOL([o isMultiple], multiple, setisMultiple, @"IsMultiple")
        ADD_OBJECT([o selectedFont], selectedFont, setSelectedFont, @"Selected font")
        ADD_OBJECT([o target], target, setTarget, @"Target")
}

- (void)addNSGlyphInfo:(id)object
{
        NSGlyphInfo* o = object;
        ADD_CLASS_LABEL(@"NSGlyphInfo Info");
        ADD_ENUM(CharacterCollection, [o characterCollection], characterCollection, setcharacterCollection, @"Character collection")
        if ([o characterIdentifier])
                ADD_NUMBER([o characterIdentifier], characterIdentifier, setCharacterIdentifier, @"Character identifier");
        ADD_OBJECT_NOT_NIL([o glyphName], glyphName, setGlyphName, @"Glyph name")
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
        ADD_OBJECT_NOT_NIL([o colorSpace], colorSpace, setColorSpace, @"Color space")
        ADD_NUMBER([o numberOfColorStops], numberOfColorStops, setNumberOfColorStops, @"Number of color stops")
}


- (void)addNSGraphicsContext:(id)object
{
        NSGraphicsContext* o = object;
        ADD_CLASS_LABEL(@"NSGraphicsContext Info");
        ADD_DICTIONARY([o attributes], @"Attributes")
        ADD_ENUM(ColorRenderingIntent, [o colorRenderingIntent], colorRenderingIntent, setcolorRenderingIntent, @"Color rendering intent")
        ADD_ENUM(CompositingOperation, [o compositingOperation], compositingOperation, setcompositingOperation, @"Compositing operation")
        ADD_POINTER([o graphicsPort], @"Graphics port")
        ADD_ENUM(ImageInterpolation, [o imageInterpolation], imageInterpolation, setimageInterpolation, @"Image interpolation")
        ADD_BOOL([o isDrawingToScreen], drawingToScreen, setisDrawingToScreen, @"Is drawing to screen")
        ADD_BOOL([o isFlipped], flipped, setisFlipped, @"Is flipped")
        ADD_POINT([o patternPhase], patternPhase, setPatternPhase, @"Pattern phase")
        ADD_BOOL([o shouldAntialias], shouldAntialias, setshouldAntialias, @"Should antialias")
}

- (void)addNSImage:(id)object
{
        NSImage* o = object;
        ADD_CLASS_LABEL(@"NSImage Info");
        ADD_RECT([o alignmentRect], alignmentRect, setAlignmentRect, @"Alignment rect")
        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
        ADD_BOOL([o cacheDepthMatchesImageDepth], cacheDepthMatchesImageDepth, setcacheDepthMatchesImageDepth, @"Cache depth matches image depth")
        ADD_ENUM(ImageCacheMode, [o cacheMode], cacheMode, setcacheMode, @"Cache mode")
        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
        ADD_BOOL([o isCachedSeparately], cachedSeparately, setisCachedSeparately, @"Is cached separately")
        ADD_BOOL([o isDataRetained], dataRetained, setisDataRetained, @"Is data retained")
        ADD_BOOL([o isFlipped], flipped, setisFlipped, @"Is flipped")
        ADD_BOOL([o isTemplate], template, setisTemplate, @"Is template")
        ADD_BOOL([o isValid], valid, setisValid, @"Is valid")
        ADD_BOOL([o matchesOnMultipleResolution], matchesOnMultipleResolution, setmatchesOnMultipleResolution, @"Matches on multiple resolution")
        ADD_OBJECT_NOT_NIL([o name], name, setName, @"Name")
        ADD_BOOL([o prefersColorMatch], prefersColorMatch, setprefersColorMatch, @"Prefers color match")
        ADD_OBJECTS([o representations], @"Representations")
        ADD_BOOL([o scalesWhenResized], scalesWhenResized, setscalesWhenResized, @"Scales when resized")
        ADD_SIZE([o size], size, setSize, @"Size")
        ADD_BOOL([o usesEPSOnResolutionMismatch], usesEPSOnResolutionMismatch, setusesEPSOnResolutionMismatch, @"Uses EPS on resolution mismatch")
}

- (void)addNSImageRep:(id)object
{
        if ([object isKindOfClass:[NSBitmapImageRep class]]) {
                NSBitmapImageRep* o = object;
                ADD_CLASS_LABEL(@"NSBitmapImageRep Info");
                ADD_OPTIONS(BitmapFormat, [o bitmapFormat], bitmapFormat, setbitmapFormat, @"Bitmap format")
                ADD_NUMBER([o bitsPerPixel], bitsPerPixel, setBitsPerPixel, @"Bits per pixel")
                ADD_NUMBER([o bytesPerPlane], bytesPerPlane, setBytesPerPlane, @"Bytes per plane")
                ADD_NUMBER([o bytesPerRow], bytesPerRow, setBytesPerRow, @"Bytes per row")
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
                ADD_BOOL([o isPlanar], planar, setisPlanar, @"Is planar")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageLoopCount], @"Loop count")
                ADD_NUMBER([o numberOfPlanes], numberOfPlanes, setNumberOfPlanes, @"Number of planes")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageProgressive], @"Progressive")
                ADD_OBJECT_RO_NOT_NIL([o valueForProperty:NSImageRGBColorTable], @"RGB color table")
                ADD_NUMBER([o samplesPerPixel], samplesPerPixel, setSamplesPerPixel, @"Samples per pixel")
        }
        else if ([object isKindOfClass:[NSCIImageRep class]]) {
                NSCIImageRep* o = object;
                ADD_CLASS_LABEL(@"NSCIImageRep Info");
                ADD_OBJECT([o CIImage], CIImage, setCIImage, @"CIImage")
        }
        else if ([object isKindOfClass:[NSCustomImageRep class]]) {
                NSCustomImageRep* o = object;
                ADD_CLASS_LABEL(@"NSCustomImageRep Info");
                ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                ADD_SEL([o drawSelector], @"Draw selector")
        }
        else if ([object isKindOfClass:[NSEPSImageRep class]]) {
                NSEPSImageRep* o = object;
                ADD_CLASS_LABEL(@"NSEPSImageRep Info");
                ADD_RECT([o boundingBox], boundingBox, setBoundingBox, @"Bounding box")
        }
        else if ([object isKindOfClass:[NSPDFImageRep class]]) {
                NSPDFImageRep* o = object;
                ADD_CLASS_LABEL(@"NSPDFImageRep Info");
                ADD_RECT([o bounds], bounds, setBounds, @"Bounding box")
                ADD_NUMBER([o currentPage], currentPage, setCurrentPage, @"Current page")
                ADD_NUMBER([o pageCount], pageCount, setPageCount, @"Page count")
        }
        else if ([object isKindOfClass:[NSPICTImageRep class]]) {
                NSPICTImageRep* o = object;
                ADD_CLASS_LABEL(@"NSPICTImageRep Info");
                ADD_RECT([o boundingBox], boundingBox, setBoundingBox, @"Bounding box")
        }

        NSImageRep* o = object;
        ADD_CLASS_LABEL(@"NSImageRep Info");
        ADD_NUMBER([o bitsPerSample], bitsPerSample, setBitsPerSample, @"Bits per sample")
        ADD_OBJECT([o colorSpaceName], colorSpaceName, setColorSpaceName, @"Color space name")
        ADD_BOOL([o hasAlpha], hasAlpha, sethasAlpha, @"Has alpha")
        ADD_BOOL([o isOpaque], opaque, setisOpaque, @"Is opaque")
        ADD_NUMBER([o pixelsHigh], pixelsHigh, setPixelsHigh, @"Pixels high")
        ADD_NUMBER([o pixelsWide], pixelsWide, setPixelsWide, @"Pixels wide")
        ADD_SIZE([o size], size, setSize, @"Size")
}

- (void)addNSLayoutManager:(id)object
{
        NSLayoutManager* o = object;
        ADD_CLASS_LABEL(@"NSLayoutManager Info");
        ADD_BOOL([o allowsNonContiguousLayout], allowsNonContiguousLayout, setallowsNonContiguousLayout, @"Allows non contiguous layout")
        ADD_BOOL([o backgroundLayoutEnabled], backgroundLayoutEnabled, setbackgroundLayoutEnabled, @"Background layout enabled")
        ADD_ENUM(ImageScaling, [o defaultAttachmentScaling], defaultAttachmentScaling, setdefaultAttachmentScaling, @"Default attachment scaling")
        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
        ADD_RECT([o extraLineFragmentRect], extraLineFragmentRect, setExtraLineFragmentRect, @"Extra line fragment rect")
        ADD_OBJECT_NOT_NIL([o extraLineFragmentTextContainer], extraLineFragmentTextContainer, setExtraLineFragmentTextContainer, @"Extra line fragment text container")
        ADD_RECT([o extraLineFragmentUsedRect], extraLineFragmentUsedRect, setExtraLineFragmentUsedRect, @"Extra line fragment used rect")
        ADD_OBJECT([o firstTextView], firstTextView, setFirstTextView, @"First text view")
        ADD_NUMBER([o firstUnlaidCharacterIndex], firstUnlaidCharacterIndex, setFirstUnlaidCharacterIndex, @"First unlaid character index")
        ADD_NUMBER([o firstUnlaidGlyphIndex], firstUnlaidGlyphIndex, setFirstUnlaidGlyphIndex, @"First unlaid glyph index")
        ADD_OBJECT([o glyphGenerator], glyphGenerator, setGlyphGenerator, @"Glyph generator")
        ADD_BOOL([o hasNonContiguousLayout], hasNonContiguousLayout, sethasNonContiguousLayout, @"Has non contiguous layout")
        ADD_NUMBER([o hyphenationFactor], hyphenationFactor, setHyphenationFactor, @"Hyphenation factor")
        ADD_OPTIONS(GlyphStorageLayoutOptions, [o layoutOptions], layoutOptions, setlayoutOptions, @"Layout options")
        ADD_BOOL([o showsControlCharacters], showsControlCharacters, setshowsControlCharacters, @"Shows control characters")
        ADD_BOOL([o showsInvisibleCharacters], showsInvisibleCharacters, setshowsInvisibleCharacters, @"Shows invisible characters")
        ADD_OBJECTS([o textContainers], @"Text containers")
        ADD_OBJECT([o textStorage], textStorage, setTextStorage, @"Text storage")
        ADD_OBJECT([o textViewForBeginningOfSelection], textViewForBeginningOfSelection, setTextViewForBeginningOfSelection, @"Text view for beginning of selection")
        ADD_OBJECT([o typesetter], typesetter, setTypesetter, @"Typesetter")
        ADD_ENUM(TypesetterBehavior, [o typesetterBehavior], typesetterBehavior, settypesetterBehavior, @"Typesetter behavior")
        ADD_BOOL([o usesFontLeading], usesFontLeading, setusesFontLeading, @"Uses font leading")
        ADD_BOOL([o usesScreenFonts], usesScreenFonts, setusesScreenFonts, @"Uses screen fonts")
}

- (void)addNSManagedObjectContext:(id)object
{
        NSManagedObjectContext* o = object;
        ADD_CLASS_LABEL(@"NSManagedObjectContext Info");
        ADD_OBJECT([o deletedObjects], deletedObjects, setDeletedObjects, @"Deleted objects")
        ADD_BOOL([o hasChanges], hasChanges, sethasChanges, @"Has changes")
        ADD_OBJECT([o insertedObjects], insertedObjects, setInsertedObjects, @"Inserted objects")
        ADD_OPTIONS(MergePolicyMarker, [o mergePolicy], mergePolicy, setmergePolicy, @"Merge policy")
        ADD_OBJECT([o persistentStoreCoordinator], persistentStoreCoordinator, setPersistentStoreCoordinator, @"Persistent store coordinator")
        ADD_BOOL([o propagatesDeletesAtEndOfEvent], propagatesDeletesAtEndOfEvent, setpropagatesDeletesAtEndOfEvent, @"Propagates deletes at end of event")
        ADD_OBJECT([o registeredObjects], registeredObjects, setRegisteredObjects, @"Registered objects")
        ADD_BOOL([o retainsRegisteredObjects], retainsRegisteredObjects, setretainsRegisteredObjects, @"Retains registered objects")
        ADD_NUMBER([o stalenessInterval], stalenessInterval, setStalenessInterval, @"Staleness interval")
        ADD_BOOL([o tryLock], tryLock, settryLock, @"Try lock")
        ADD_OBJECT([o undoManager], undoManager, setUndoManager, @"Undo manager")
        ADD_OBJECT([o updatedObjects], updatedObjects, setUpdatedObjects, @"Updated objects")
}

- (void)addNSManagedObjectID:(id)object
{
        NSManagedObjectID* o = object;
        ADD_CLASS_LABEL(@"NSManagedObjectID Info");
        ADD_OBJECT([o entity], entity, setEntity, @"Entity")
        ADD_BOOL([o isTemporaryID], temporaryID, setisTemporaryID, @"Is temporary ID")
        ADD_OBJECT([o persistentStore], persistentStore, setPersistentStore, @"Persistent store")
        ADD_OBJECT([o URIRepresentation], URIRepresentation, setURIRepresentation, @"URI representation")
}

- (void)addNSManagedObjectModel:(id)object
{
        NSManagedObjectModel* o = object;
        ADD_CLASS_LABEL(@"NSManagedObjectModel Info");
        ADD_OBJECTS([o configurations], @"Configurations")
        ADD_DICTIONARY([o entitiesByName], @"Entities by name")
        ADD_DICTIONARY([o fetchRequestTemplatesByName], @"Fetch request templates by name")
        ADD_OBJECTS([[o versionIdentifiers] allObjects], @"Version identifiers")
}

- (void)addNSMenu:(id)object
{
        NSMenu* o = object;
        ADD_CLASS_LABEL(@"NSMenu Info");
        ADD_BOOL([o autoenablesItems], autoenablesItems, setautoenablesItems, @"Autoenables Items")
        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
        ADD_OBJECT_NOT_NIL([o highlightedItem], highlightedItem, setHighlightedItem, @"Highlighted item")
        ADD_BOOL([o isTornOff], tornOff, setisTornOff, @"Is torn off")
        ADD_OBJECTS([o itemArray], @"Items")
        ADD_BOOL([o menuChangedMessagesEnabled], menuChangedMessagesEnabled, setmenuChangedMessagesEnabled, @"Menu changed messages enabled")
        ADD_BOOL([o showsStateColumn], showsStateColumn, setshowsStateColumn, @"Shows state column")
        ADD_OBJECT_NOT_NIL([o supermenu], supermenu, setSupermenu, @"Supermenu")
        ADD_STRING([o title], title, setTitle, @"Title")
}

- (void)addNSMenuItem:(id)object
{
        NSMenuItem* o = object;
        ADD_CLASS_LABEL(@"NSMenuItem Info")
        ADD_SEL([o action], @"Action")
        ADD_OBJECT_NOT_NIL([o attributedTitle], attributedTitle, setAttributedTitle, @"Attributed title")
        ADD_BOOL([o hasSubmenu], hasSubmenu, sethasSubmenu, @"Has submenu")
        ADD_OBJECT_NOT_NIL([o image], image, setImage, @"Image")
        ADD_NUMBER([o indentationLevel], indentationLevel, setIndentationLevel, @"Indentation level")
        ADD_BOOL([o isAlternate], alternate, setisAlternate, @"Is alternate")
        ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
        ADD_BOOL([o isHidden], hidden, setisHidden, @"Is hidden")
        ADD_BOOL([o isHiddenOrHasHiddenAncestor], hiddenOrHasHiddenAncestor, setisHiddenOrHasHiddenAncestor, @"Is hidden or has hidden ancestor")
        ADD_BOOL([o isHighlighted], highlighted, setisHighlighted, @"Is highlighted")
        ADD_BOOL([o isSeparatorItem], separatorItem, setisSeparatorItem, @"Is separatorItem")
        ADD_OBJECT([o keyEquivalent], keyEquivalent, setKeyEquivalent, @"Key equivalent")
        ADD_OPTIONS(EventModifierFlags, [o keyEquivalentModifierMask] & NSDeviceIndependentModifierFlagsMask, keyEquivalentModifierMask, setKeyEquivalentModifierMask, @"Key equivalent modifier mask")
        ADD_OBJECT([o menu], menu, setMenu, @"Menu")
        ADD_OBJECT_NOT_NIL([o mixedStateImage], mixedStateImage, setMixedStateImage, @"Mixed state image")
        ADD_OBJECT_NOT_NIL([o offStateImage], offStateImage, setOffStateImage, @"Off state image")
        ADD_OBJECT_NOT_NIL([o onStateImage], onStateImage, setOnStateImage, @"On state image")
        ADD_OBJECT_NOT_NIL([o representedObject], representedObject, setRepresentedObject, @"Represented object")
        ADD_ENUM(CellStateValue, [o state], state, setstate, @"State")
        ADD_OBJECT_NOT_NIL([o submenu], submenu, setSubmenu, @"Submenu")
        ADD_NUMBER([o tag], tag, setTag, @"Tag")
        ADD_OBJECT_NOT_NIL([o target], target, setTarget, @"Target")
        ADD_STRING([o title], title, setTitle, @"Title")
        ADD_OBJECT_NOT_NIL([o toolTip], toolTip, setToolTip, @"Tool tip")
        ADD_OBJECT([o userKeyEquivalent], userKeyEquivalent, setUserKeyEquivalent, @"User key equivalent")
        ADD_OBJECT_NOT_NIL([o view], view, setView, @"View")
}

- (void)addNSOpenGLContext:(id)object
{
        NSOpenGLContext* o = object;
        ADD_CLASS_LABEL(@"NSOpenGLContext Info");
        ADD_POINTER([o CGLContextObj], @"CGL context obj")
        ADD_NUMBER([o currentVirtualScreen], currentVirtualScreen, setCurrentVirtualScreen, @"Current virtual screen")
        ADD_OBJECT_NOT_NIL([o pixelBuffer], pixelBuffer, setPixelBuffer, @"Pixel buffer")
        ADD_NUMBER([o pixelBufferCubeMapFace], pixelBufferCubeMapFace, setPixelBufferCubeMapFace, @"Pixel buffer cube map face")
        ADD_NUMBER([o pixelBufferMipMapLevel], pixelBufferMipMapLevel, setPixelBufferMipMapLevel, @"Pixel buffer mipmap level")
        ADD_OBJECT_NOT_NIL([o view], view, setView, @"View")
}

- (void)addNSOpenGLPixelBuffer:(id)object
{
        NSOpenGLPixelBuffer* o = object;
        ADD_CLASS_LABEL(@"NSOpenGLPixelBuffer Info");
        ADD_NUMBER([o pixelsHigh], pixelsHigh, setPixelsHigh, @"Pixels high")
        ADD_NUMBER([o pixelsWide], pixelsWide, setPixelsWide, @"Pixels wide")
        ADD_NUMBER([o textureInternalFormat], textureInternalFormat, setTextureInternalFormat, @"Texture internal format")
        ADD_NUMBER([o textureMaxMipMapLevel], textureMaxMipMapLevel, setTextureMaxMipMapLevel, @"Texture max mipmap level")
        ADD_NUMBER([o textureTarget], textureTarget, setTextureTarget, @"Texture target")
}

- (void)addNSOpenGLPixelFormat:(id)object
{
        NSOpenGLPixelFormat* o = object;
        ADD_CLASS_LABEL(@"NSOpenGLPixelFormat Info");
        ADD_POINTER([o CGLPixelFormatObj], @"CGL pixel format obj")
        ADD_NUMBER([o numberOfVirtualScreens], numberOfVirtualScreens, setNumberOfVirtualScreens, @"Number of virtual screens")
}

- (void)addNSPageLayout:(id)object
{
        NSPageLayout* o = object;

        if ([[o accessoryControllers] count] > 0 || [o printInfo] != nil) {
                ADD_CLASS_LABEL(@"NSPageLayout Info");
                ADD_OBJECTS([o accessoryControllers], @"Accessory controllers")
                ADD_OBJECT_NOT_NIL([o printInfo], printInfo, setPrintInfo, @"Print info")
        }
}

- (void)addNSParagraphStyle:(id)object
{
        NSParagraphStyle* o = object;
        ADD_CLASS_LABEL(@"NSParagraphStyle Info")
        ADD_ENUM(TextAlignment, [o alignment], alignment, setalignment, @"Alignment")
        ADD_ENUM(WritingDirection, [o baseWritingDirection], baseWritingDirection, setbaseWritingDirection, @"Base writing direction")
        ADD_NUMBER([o defaultTabInterval], defaultTabInterval, setDefaultTabInterval, @"Default tab interval")
        ADD_NUMBER([o firstLineHeadIndent], firstLineHeadIndent, setFirstLineHeadIndent, @"First line head indent")
        ADD_NUMBER([o headerLevel], headerLevel, setHeaderLevel, @"HeaderLevel")
        ADD_NUMBER([o headIndent], headIndent, setHeadIndent, @"Head indent")
        ADD_NUMBER([o hyphenationFactor], hyphenationFactor, setHyphenationFactor, @"hyphenationFactor")
        ADD_ENUM(LineBreakMode, [o lineBreakMode], lineBreakMode, setlineBreakMode, @"Line break mode")
        ADD_NUMBER([o lineHeightMultiple], lineHeightMultiple, setLineHeightMultiple, @"Line height multiple")
        ADD_NUMBER([o lineSpacing], lineSpacing, setLineSpacing, @"Line spacing")
        ADD_NUMBER([o maximumLineHeight], maximumLineHeight, setMaximumLineHeight, @"Maximum line height")
        ADD_NUMBER([o minimumLineHeight], minimumLineHeight, setMinimumLineHeight, @"Minimum line height")
        ADD_NUMBER([o paragraphSpacing], paragraphSpacing, setParagraphSpacing, @"Paragraph spacing")
        ADD_NUMBER([o paragraphSpacingBefore], paragraphSpacingBefore, setParagraphSpacingBefore, @"Paragraph spacing before")
        ADD_OBJECTS([o tabStops], @"Tab stops")
        ADD_NUMBER([o tailIndent], tailIndent, setTailIndent, @"Tail indent")
        ADD_OBJECTS([o textBlocks], @"Text blocks")
        ADD_OBJECTS([o textLists], @"Text lists")
        ADD_NUMBER([o tighteningFactorForTruncation], tighteningFactorForTruncation, setTighteningFactorForTruncation, @"Tightening factor for truncation")
}

- (void)addNSPersistentStoreCoordinator:(id)object
{
        NSPersistentStoreCoordinator* o = object;
        ADD_CLASS_LABEL(@"NSPersistentStoreCoordinator Info")
        ADD_OBJECT([o managedObjectModel], managedObjectModel, setManagedObjectModel, @"Managed object model")
        ADD_OBJECTS([o persistentStores], @"Persistent stores")
}

- (void)addNSPredicateEditorRowTemplate:(id)object
{
        NSPredicateEditorRowTemplate* o = object;
        ADD_CLASS_LABEL(@"NSPredicateEditorRowTemplate Info")
        ADD_OBJECTS([o compoundTypes], @"Compound types")
        ADD_OBJECTS([o leftExpressions], @"Left expressions")
        ADD_ENUM(ComparisonPredicateModifier, [o modifier], modifier, setmodifier, @"Modifier")
        ADD_OBJECTS([o operators], @"Operators")
        ADD_OPTIONS(ComparisonPredicateOptions, [o options], options, setoptions, @"Options")
        ADD_ENUM(AttributeType, [o rightExpressionAttributeType], rightExpressionAttributeType, setrightExpressionAttributeType, @"Right expression attribute type")
        ADD_OBJECTS([o rightExpressions], @"Right expressions")
        ADD_OBJECTS([o templateViews], @"Template views")
}

- (void)addNSPropertyDescription:(id)object
{
        if ([object isKindOfClass:[NSAttributeDescription class]]) {
                NSAttributeDescription* o = object;
                ADD_CLASS_LABEL(@"NSAttributeDescription Info")
                ADD_ENUM(AttributeType, [o attributeType], attributeType, setattributeType, @"Attribute type")
                ADD_OBJECT([o attributeValueClassName], attributeValueClassName, setAttributeValueClassName, @"Attribute value class name")
                ADD_OBJECT([o defaultValue], defaultValue, setDefaultValue, @"Default value")

                if ([o attributeType] == NSTransformableAttributeType)
                        ADD_OBJECT([o valueTransformerName], valueTransformerName, setValueTransformerName, @"Value transformer name")
        }
        else if ([object isKindOfClass:[NSFetchedPropertyDescription class]]) {
                NSFetchedPropertyDescription* o = object;
                ADD_CLASS_LABEL(@"NSFetchedPropertyDescription Info")
                ADD_OBJECT([o fetchRequest], fetchRequest, setFetchRequest, @"Fetch request")
        }
        else if ([object isKindOfClass:[NSRelationshipDescription class]]) {
                NSRelationshipDescription* o = object;
                ADD_CLASS_LABEL(@"NSRelationshipDescription Info")
                ADD_ENUM(DeleteRule, [o deleteRule], deleteRule, setdeleteRule, @"Delete rule")
                ADD_OBJECT([o destinationEntity], destinationEntity, setDestinationEntity, @"Destination entity")
                ADD_OBJECT([o inverseRelationship], inverseRelationship, setInverseRelationship, @"Inverse relationship")
                ADD_BOOL([o isToMany], toMany, setisToMany, @"Is to many")
                ADD_NUMBER([o maxCount], maxCount, setMaxCount, @"Max count")
                ADD_NUMBER([o minCount], minCount, setMinCount, @"Min count")
        }

        NSPropertyDescription* o = object;
        ADD_CLASS_LABEL(@"NSPropertyDescription Info")
        ADD_OBJECT([o entity], entity, setEntity, @"Entity")
        ADD_BOOL([o isIndexed], indexed, setisIndexed, @"Is indexed")
        ADD_BOOL([o isOptional], optional, setisOptional, @"Is optional")
        ADD_BOOL([o isTransient], transient, setisTransient, @"Is transient")
        ADD_OBJECT([o name], name, setName, @"Name")
        ADD_DICTIONARY([o userInfo], @"User info")
        ADD_OBJECTS([o validationPredicates], @"Validation predicates")
        ADD_OBJECTS([o validationWarnings], @"Validation warnings")
}

- (void)addNSResponder:(id)object
{
        if ([object isKindOfClass:[NSApplication class]]) {
                NSApplication* o = object;
                ADD_CLASS_LABEL(@"NSApplication Info")
                ADD_OBJECT_NOT_NIL([o applicationIconImage], applicationIconImage, setApplicationIconImage, @"Application icon image")
                ADD_OBJECT_NOT_NIL([o context], context, setContext, @"Context")
                ADD_OBJECT_NOT_NIL([o currentEvent], currentEvent, setCurrentEvent, @"Current event")
                ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                ADD_OBJECT_NOT_NIL([o dockTile], dockTile, setDockTile, @"Dock tile")
                ADD_BOOL([o isActive], active, setisActive, @"Is active")
                ADD_BOOL([o isHidden], hidden, setisHidden, @"Is hidden")
                ADD_BOOL([o isRunning], running, setisRunning, @"Is running")
                ADD_OBJECT_NOT_NIL([o keyWindow], keyWindow, setKeyWindow, @"Key window")
                ADD_OBJECT_NOT_NIL([o mainMenu], mainMenu, setMainMenu, @"Main menu")
                ADD_OBJECT_NOT_NIL([o mainWindow], mainWindow, setMainWindow, @"Main window")
                ADD_OBJECT_NOT_NIL([o modalWindow], modalWindow, setModalWindow, @"Modal window")
                ADD_OBJECTS([o orderedDocuments], @"Ordered documents")
                ADD_OBJECTS([o orderedWindows], @"Ordered windows")
                ADD_OBJECT_NOT_NIL([o servicesMenu], servicesMenu, setServicesMenu, @"Services menu")
                ADD_OBJECT_NOT_NIL([o servicesProvider], servicesProvider, setServicesProvider, @"Services provider")
                ADD_OBJECTS([o windows], @"Windows")
                ADD_OBJECT_NOT_NIL([o windowsMenu], windowsMenu, setWindowsMenu, @"Windows menu")
        }
        else if ([object isKindOfClass:[NSDrawer class]]) {
                NSDrawer* o = object;
                ADD_CLASS_LABEL(@"NSDrawer Info");
                ADD_SIZE([o contentSize], contentSize, setContentSize, @"Content size")
                ADD_OBJECT([o contentView], contentView, setContentView, @"Content view")
                ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                ADD_ENUM(RectEdge, [o edge], edge, setedge, @"Edge")
                ADD_NUMBER([o leadingOffset], leadingOffset, setLeadingOffset, @"Leading offset")
                ADD_SIZE([o maxContentSize], maxContentSize, setMaxContentSize, @"Max content size")
                ADD_SIZE([o minContentSize], minContentSize, setMinContentSize, @"Min content size")
                ADD_OBJECT([o parentWindow], parentWindow, setParentWindow, @"Parent window")
                ADD_ENUM(RectEdge, [o preferredEdge], preferredEdge, setpreferredEdge, @"Preferred edge")
                ADD_ENUM(DrawerState, [o state], state, setstate, @"State")
                ADD_NUMBER([o trailingOffset], trailingOffset, setTrailingOffset, @"Trailing offset")
        }
        else if ([object isKindOfClass:[NSView class]]) {
                [self processNSView:object];
        }

        if ([object isKindOfClass:[NSViewController class]]) {
                NSViewController* o = object;
                ADD_CLASS_LABEL(@"NSViewController Info")
                ADD_OBJECT_NOT_NIL([o nibBundle], nibBundle, setNibBundle, @"Nib bundle")
                ADD_OBJECT_NOT_NIL([o nibName], nibName, setNibName, @"Nib name")
                ADD_OBJECT_NOT_NIL([o representedObject], representedObject, setRepresentedObject, @"Represented object")
                ADD_STRING_NOT_NIL([o title], title, setTitle, @"Title")
                ADD_OBJECT_NOT_NIL([o view], view, setView, @"View")
        }
        else if ([object isKindOfClass:[NSWindow class]]) {
                [self processNSWindow:object];
        }
        else if ([object isKindOfClass:[NSWindowController class]]) {
                NSWindowController* o = object;
                ADD_CLASS_LABEL(@"NSWindowController Info");
                ADD_OBJECT([o document], document, setDocument, @"Document")
                ADD_BOOL([o isWindowLoaded], windowLoaded, setisWindowLoaded, @"Is window loaded")
                ADD_OBJECT([o owner], owner, setOwner, @"Owner")
                ADD_BOOL([o shouldCascadeWindows], shouldCascadeWindows, setshouldCascadeWindows, @"Should cascade windows")
                ADD_BOOL([o shouldCloseDocument], shouldCloseDocument, setshouldCloseDocument, @"Should close document")
                if ([o isWindowLoaded])
                        ADD_OBJECT([o window], window, setWindow, @"Window")
                ADD_OBJECT([o windowFrameAutosaveName], windowFrameAutosaveName, setWindowFrameAutosaveName, @"Window frame autosave name")
                ADD_OBJECT([o windowNibName], windowNibName, setWindowNibName, @"Window nib name")
                ADD_OBJECT([o windowNibPath], windowNibPath, setWindowNibPath, @"Window nib path")
        }

        NSResponder* o = object;
        ADD_CLASS_LABEL(@"NSResponder Info")
        ADD_BOOL([o acceptsFirstResponder], acceptsFirstResponder, setacceptsFirstResponder, @"Accepts first responder")

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

        ADD_OBJECT([o undoManager], undoManager, setUndoManager, @"Undo Manager")
}

- (void)addNSRulerMarker:(id)object
{
        NSRulerMarker* o = object;
        ADD_CLASS_LABEL(@"NSRulerMarker Info");
        ADD_OBJECT([o image], image, setImage, @"Image")
        ADD_POINT([o imageOrigin], imageOrigin, setImageOrigin, @"Image origin")
        ADD_RECT([o imageRectInRuler], imageRectInRuler, setImageRectInRuler, @"Image rect in ruler")
        ADD_BOOL([o isDragging], dragging, setisDragging, @"Is dragging")
        ADD_BOOL([o isMovable], movable, setisMovable, @"Is movable")
        ADD_BOOL([o isRemovable], removable, setisRemovable, @"Is removable")
        ADD_NUMBER([o markerLocation], markerLocation, setMarkerLocation, @"Marker location")
        ADD_OBJECT([o representedObject], representedObject, setRepresentedObject, @"Represented object")
        ADD_OBJECT([o ruler], ruler, setRuler, @"Ruler")
        ADD_NUMBER([o thicknessRequiredInRuler], thicknessRequiredInRuler, setThicknessRequiredInRuler, @"Thickness required in ruler")
}

- (void)addNSScreen:(id)object
{
        NSScreen* o = object;
        ADD_CLASS_LABEL(@"NSScreen Info");
        ADD_NUMBER([o depth], depth, setDepth, @"Depth")
        ADD_DICTIONARY([o deviceDescription], @"Device description")
        ADD_RECT([o frame], frame, setFrame, @"Frame")
        ADD_NUMBER([o userSpaceScaleFactor], userSpaceScaleFactor, setUserSpaceScaleFactor, @"User space scale factor")
        ADD_RECT([o visibleFrame], visibleFrame, setVisibleFrame, @"Visible frame")
}

- (void)addNSShadow:(id)object
{
        NSShadow* o = object;
        ADD_CLASS_LABEL(@"NSShadow Info");
        ADD_NUMBER([o shadowBlurRadius], shadowBlurRadius, setShadowBlurRadius, @"Shadow blur radius")
        ADD_COLOR([o shadowColor], shadowColor, setShadowColor, @"Shadow color")
        ADD_SIZE([o shadowOffset], shadowOffset, setShadowOffset,       @"Shadow offset")
}

- (void)addNSStatusBar:(id)object
{
        NSStatusBar* o = object;
        ADD_CLASS_LABEL(@"NSStatusBar Info");
        ADD_BOOL([o isVertical], vertical, setisVertical, @"Is vertical")
        ADD_NUMBER([o thickness], thickness, setThickness, @"Thickness")
}

- (void)addNSStatusItem:(id)object
{
        NSStatusItem* o = object;
        ADD_CLASS_LABEL(@"NSStatusItem Info");
        ADD_SEL([o action], @"Action")
        ADD_OBJECT_NOT_NIL([o alternateImage], alternateImage, setAlternateImage, @"Alternate image")
        ADD_OBJECT_NOT_NIL([o attributedTitle], attributedTitle, setAttributedTitle, @"Attributed title")
        ADD_SEL([o doubleAction], @"Double action")
        ADD_BOOL([o highlightMode], highlightMode, sethighlightMode, @"Highlight mode")
        ADD_OBJECT_NOT_NIL([o image], image, setImage, @"Image")
        ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
        ADD_ENUM(StatusItemLength, [o length], length, setlength, @"Length")
        ADD_OBJECT_NOT_NIL([o menu], menu, setMenu, @"Menu")
        ADD_OBJECT([o statusBar], statusBar, setStatusBar, @"Status bar")
        ADD_OBJECT([o target], target, setTarget, @"Target")
        ADD_STRING_NOT_NIL([o title], title, setTitle, @"Title")
        ADD_STRING_NOT_NIL([o toolTip], toolTip, setToolTip, @"Tool tip")
        ADD_OBJECT_NOT_NIL([o view], view, setView, @"View")
}

- (void)addNSTabViewItem:(id)object
{
        NSTabViewItem* o = object;
        ADD_CLASS_LABEL(@"NSTabViewItem Info");
        ADD_COLOR([o color], color, setColor, @"Color")
        ADD_OBJECT([(NSTabViewItem*)o identifier], identifier, setIdentifier, @"Identifier")
        ADD_OBJECT([o initialFirstResponder], initialFirstResponder, setInitialFirstResponder, @"Initial first responder")
        ADD_OBJECT([o label], label, setLabel, @"Label")
        ADD_ENUM(TabState, [o tabState], tabState, settabState, @"Tab state")
        ADD_OBJECT([o tabView], tabView, setTabView, @"Parent tab view")
        ADD_OBJECT([o view], view, setView, @"View")
}

- (void)addNSTableColumn:(id)object
{
        NSTableColumn* o = object;
        ADD_CLASS_LABEL(@"NSTableColumn Info");
        ADD_OBJECT([o dataCell], dataCell, setDataCell, @"Data cell")
        ADD_OBJECT([o headerCell], headerCell, setHeaderCell, @"Header cell")
        ADD_OBJECT_NOT_NIL([o headerToolTip], headerToolTip, setHeaderToolTip, @"Header tool tip")
        ADD_OBJECT([(NSTableColumn*)o identifier], identifier, setIdentifier, @"Identifier")
        ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
        ADD_BOOL([o isHidden], hidden, setisHidden, @"Is hidden")
        ADD_NUMBER([o maxWidth], maxWidth, setMaxWidth, @"Max width")
        ADD_NUMBER([o minWidth], minWidth, setMinWidth, @"Min width")
        ADD_OPTIONS(TableColumnResizingOptions, [o resizingMask], resizingMask, setresizingMask, @"Resizing mask")
        ADD_OBJECT_NOT_NIL([o sortDescriptorPrototype], sortDescriptorPrototype, setSortDescriptorPrototype, @"Sort descriptor prototype")
        ADD_OBJECT([o tableView], tableView, setTableView, @"Table view")
        ADD_NUMBER([o width], width, setWidth, @"Width")
}

- (void)addNSTextAttachment:(id)object
{
        NSTextAttachment* o = object;
        ADD_CLASS_LABEL(@"NSTextAttachment Info");
        ADD_OBJECT([o attachmentCell], attachmentCell, setAttachmentCell, @"Attachment cell")
        ADD_OBJECT([o fileWrapper], fileWrapper, setFileWrapper, @"File wrapper")
}

- (void)addNSTextBlock:(id)object
{
        if ([object isKindOfClass:[NSTextTableBlock class]]) {
                NSTextTableBlock* o = object;
                ADD_CLASS_LABEL(@"NSTextTableBlock Info");
                ADD_NUMBER([o columnSpan], columnSpan, setColumnSpan, @"Column span")
                ADD_NUMBER([o rowSpan], rowSpan, setRowSpan, @"Row span")
                ADD_NUMBER([o startingColumn], startingColumn, setStartingColumn, @"Starting column")
                ADD_NUMBER([o startingRow], startingRow, setStartingRow, @"Starting row")
                ADD_OBJECT([o table], table, setTable, @"Table")
        }
        else if ([object isKindOfClass:[NSTextTable class]]) {
                NSTextTable* o = object;
                ADD_CLASS_LABEL(@"NSTextTable Info");
                ADD_BOOL([o collapsesBorders], collapsesBorders, setcollapsesBorders, @"Collapses borders")
                ADD_BOOL([o hidesEmptyCells], hidesEmptyCells, sethidesEmptyCells, @"Hides empty cells")
                ADD_ENUM(TextTableLayoutAlgorithm, [o layoutAlgorithm], layoutAlgorithm, setlayoutAlgorithm, @"Layout algorithm")
                ADD_NUMBER([o numberOfColumns], numberOfColumns, setNumberOfColumns, @"Number of columns")
        }

        NSTextBlock* o = object;
        ADD_CLASS_LABEL(@"NSTextBlock Info");
        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
        ADD_NUMBER([o contentWidth], contentWidth, setContentWidth, @"Content width")
        ADD_ENUM(TextBlockValueType, [o contentWidthValueType], contentWidthValueType, setcontentWidthValueType, @"Content width value type")
        ADD_ENUM(TextBlockVerticalAlignment, [o verticalAlignment], verticalAlignment, setverticalAlignment, @"Vertical alignment")
}

- (void)addNSTextContainer:(id)object
{
        NSTextContainer* o = object;
        ADD_CLASS_LABEL(@"NSTextContainer Info");
        ADD_SIZE([o containerSize], containerSize, setContainerSize, @"Container size")
        ADD_BOOL([o heightTracksTextView], heightTracksTextView, setheightTracksTextView, @"Height tracks text view")
        ADD_BOOL([o isSimpleRectangularTextContainer], simpleRectangularTextContainer, setisSimpleRectangularTextContainer, @"Is simple rectangular text container")
        ADD_OBJECT_NOT_NIL([o layoutManager], layoutManager, setLayoutManager, @"Layout manager")
        ADD_NUMBER([o lineFragmentPadding], lineFragmentPadding, setLineFragmentPadding, @"Line fragment padding")
        ADD_OBJECT_NOT_NIL([o textView], textView, setTextView, @"Text view")
        ADD_BOOL([o widthTracksTextView], widthTracksTextView, setwidthTracksTextView, @"Width tracks text view")
}

- (void)addNSTextList:(id)object
{
        NSTextList* o = object;
        ADD_CLASS_LABEL(@"NSTextList Info");
        ADD_OPTIONS(TextListOptions, [o listOptions], listOptions, setlistOptions, @"List options")
        ADD_OBJECT([o markerFormat], markerFormat, setMarkerFormat, @"Marker format")
}

- (void)addNSTextTab:(id)object
{
        NSTextTab* o = object;
        ADD_CLASS_LABEL(@"NSTextTab Info");
        ADD_ENUM(TextAlignment, [o alignment], alignment, setalignment, @"Alignment")
        ADD_NUMBER([o location], location, setLocation, @"Location")
        ADD_OBJECT([o options], options, setOptions, @"Options")
        ADD_ENUM(TextTabType, [o tabStopType], tabStopType, settabStopType, @"Tab stop type")
}

- (void)addNSToolbar:(id)object
{
        NSToolbar* o = object;
        ADD_CLASS_LABEL(@"NSToolbar Info");
        ADD_BOOL([o allowsUserCustomization], allowsUserCustomization, setallowsUserCustomization, @"Allows user customization")
        ADD_BOOL([o autosavesConfiguration], autosavesConfiguration, setautosavesConfiguration, @"Autosaves configuration")
        ADD_DICTIONARY([o configurationDictionary], @"Configuration dictionary")
        ADD_BOOL([o customizationPaletteIsRunning], customizationPaletteIsRunning, setcustomizationPaletteIsRunning, @"Customization palette is running")
        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
        ADD_ENUM(ToolbarDisplayMode, [o displayMode], displayMode, setdisplayMode, @"Display mode")
        ADD_OBJECT([(NSToolbar*)o identifier], identifier, setIdentifier, @"Identifier")
        ADD_BOOL([o isVisible], visible, setisVisible, @"Is visible")
        ADD_OBJECTS([o items], @"Items")
        ADD_OBJECT_NOT_NIL([o selectedItemIdentifier], selectedItemIdentifier, setSelectedItemIdentifier, @"Selected item identifier")
        ADD_BOOL([o showsBaselineSeparator], showsBaselineSeparator, setshowsBaselineSeparator, @"Shows baseline separator")
        ADD_ENUM(ToolbarSizeMode, [o sizeMode], sizeMode, setsizeMode, @"Identifier")
        ADD_OBJECTS([o visibleItems], @"Visible items")
}

- (void)addNSToolbarItem:(id)object
{
        if ([object isKindOfClass:[NSToolbarItemGroup class]]) {
                NSToolbarItemGroup* o = object;
                ADD_CLASS_LABEL(@"NSToolbarItemGroup Info");
                ADD_OBJECTS([o subitems], @"Subitems")
        }

        NSToolbarItem* o = object;
        ADD_CLASS_LABEL(@"NSToolbarItem Info");
        ADD_SEL([o action], @"Action")
        ADD_BOOL([o allowsDuplicatesInToolbar], allowsDuplicatesInToolbar, setallowsDuplicatesInToolbar, @"Allows duplicates in toolbar")
        ADD_BOOL([o autovalidates], autovalidates, setautovalidates, @"Autovalidates")
        ADD_OBJECT([o image], image, setImage, @"Image")
        ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
        ADD_OBJECT([(NSToolbarItem*)o itemIdentifier], itemIdentifier, setItemIdentifier, @"Item identifier")
        ADD_OBJECT([o label], label, setLabel, @"Label")
        ADD_SIZE([o maxSize], maxSize, setMaxSize, @"Max size")
        ADD_OBJECT_NOT_NIL([o menuFormRepresentation], menuFormRepresentation, setMenuFormRepresentation, @"Menu form representation")
        ADD_SIZE([o minSize], minSize, setMinSize,  @"Min size")
        ADD_OBJECT([o paletteLabel], paletteLabel, setPaletteLabel, @"Palette label")
        ADD_NUMBER([o tag], tag, setTag, @"Tag")
        ADD_OBJECT([o target], target, setTarget, @"Target")
        ADD_OBJECT([o toolbar], toolbar, setToolbar, @"Toolbar")
        ADD_OBJECT_NOT_NIL([o toolTip], toolTip, setToolTip, @"Tool tip")
        ADD_OBJECT([o view], view, setView, @"View")
        ADD_ENUM(ToolbarItemVisibilityPriority, [o visibilityPriority], visibilityPriority, setvisibilityPriority, @"Visibility priority")
}

- (void)addNSTrackingArea:(id)object
{
        NSTrackingArea* o = object;
        ADD_CLASS_LABEL(@"NSTrackingArea Info");
        ADD_OPTIONS(TrackingAreaOptions, [o options], options, setoptions, @"Options")
        ADD_OBJECT([o owner], owner, setOwner, @"Owner")
        ADD_RECT([o rect], rect, setRect, @"Rect")
        ADD_DICTIONARY([o userInfo], @"User info")
}

- (void)addNSUndoManager:(id)object
{
        NSUndoManager* o = object;
        ADD_CLASS_LABEL(@"NSUndoManager Info");
        ADD_NUMBER([o groupingLevel], groupingLevel, setGroupingLevel, @"Grouping level")
        ADD_BOOL([o groupsByEvent], groupsByEvent, setgroupsByEvent, @"Groups by event")
        ADD_BOOL([o isUndoRegistrationEnabled], undoRegistrationEnabled, setisUndoRegistrationEnabled, @"Is undo registration enabled")
        ADD_NUMBER([o levelsOfUndo], levelsOfUndo, setLevelsOfUndo, @"Levels of undo")
        ADD_STRING_NOT_NIL([o redoActionName], redoActionName, setRedoActionName, @"Redo action name")
        ADD_STRING_NOT_NIL([o redoMenuItemTitle], redoMenuItemTitle, setRedoMenuItemTitle, @"Redo menu item title")
        ADD_OBJECTS([o runLoopModes], @"Run loop modes")
        ADD_STRING_NOT_NIL([o undoActionName], undoActionName, setUndoActionName, @"Undo action name")
        ADD_STRING_NOT_NIL([o undoMenuItemTitle], undoMenuItemTitle, setUndoMenuItemTitle, @"Undo menu item title")
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
        ADD_DICTIONARY([o attributesForExtraLineFragment], @"Attributes for extra line fragment")
        ADD_BOOL([o bidiProcessingEnabled], bidiProcessingEnabled, setbidiProcessingEnabled, @"Bidi processing enabled")
        ADD_OBJECT_NOT_NIL([o currentTextContainer], currentTextContainer, setCurrentTextContainer, @"Current text container")
        ADD_NUMBER([o hyphenationFactor], hyphenationFactor, setHyphenationFactor, @"Hyphenation factor")
        ADD_OBJECT_NOT_NIL([o layoutManager], layoutManager, setLayoutManager, @"Layout manager")
        ADD_NUMBER([o lineFragmentPadding], lineFragmentPadding, setLineFragmentPadding, @"Line fragment padding")
        ADD_ENUM(TypesetterBehavior, [o typesetterBehavior], typesetterBehavior, settypesetterBehavior, @"Typesetter behavior")
        ADD_BOOL([o usesFontLeading], usesFontLeading, setusesFontLeading, @"Uses font leading")
}

- (void)processNSView:(id)object
{

        if ([object isKindOfClass:[NSBox class]]) {
                NSBox* o = object;
                ADD_CLASS_LABEL(@"NSBox Info");
                ADD_COLOR([o borderColor], borderColor, setBorderColor, @"Border color")
                ADD_RECT([o borderRect], borderRect, setBorderRect, @"Border rect")
                ADD_ENUM(BorderType, [o borderType], borderType, setborderType, @"Border type")
                ADD_NUMBER([o borderWidth], borderWidth, setBorderWidth, @"Border width")
                ADD_ENUM(BoxType, [o boxType], boxType, setboxType, @"Box type")
                ADD_OBJECT([o contentView], contentView, setContentView, @"Content view")
                ADD_SIZE([o contentViewMargins], contentViewMargins, setContentViewMargins, @"Content view margins")
                ADD_NUMBER([o cornerRadius], cornerRadius, setCornerRadius, @"Corner radius")
                ADD_COLOR([o fillColor], fillColor, setFillColor, @"Fill color")
                ADD_BOOL([o isTransparent], transparent, setisTransparent, @"Is transparent")
                ADD_STRING([o title], title, setTitle, @"Title")
                ADD_OBJECT([o titleCell], titleCell, setTitleCell, @"Title cell")
                ADD_OBJECT([o titleFont], titleFont, setTitleFont, @"Title font")
                ADD_ENUM(TitlePosition, [o titlePosition], titlePosition, settitlePosition, @"Title position")
                ADD_RECT([o titleRect], titleRect, setTitleRect, @"Title rect")
        }
        if ([object isKindOfClass:[NSCollectionView class]]) {
                NSCollectionView* o = object;
                ADD_CLASS_LABEL(@"NSCollectionView Info");
                ADD_BOOL([o allowsMultipleSelection], allowsMultipleSelection, setallowsMultipleSelection, @"Allows multiple selection")
                ADD_OBJECTS([o backgroundColors], @"Background colors")
                ADD_OBJECT([o content], content, setContent, @"Content")
                ADD_BOOL([o isFirstResponder], firstResponder, setisFirstResponder, @"Is first responder")
                ADD_BOOL([o isSelectable], selectable, setisSelectable, @"Is selectable")
                ADD_OBJECT_NOT_NIL([o itemPrototype], itemPrototype, setItemPrototype, @"Item prototype")
                ADD_SIZE([o maxItemSize],  maxItemSize, setMaxItemSize, @"Max item size")
                ADD_NUMBER([o maxNumberOfColumns], maxNumberOfColumns, setMaxNumberOfColumns, @"Max number of columns")
                ADD_NUMBER([o maxNumberOfRows], maxNumberOfRows, setMaxNumberOfRows, @"Max number of rows")
                ADD_SIZE([o minItemSize], minItemSize, setMinItemSize, @"Min item size")
                ADD_OBJECT_NOT_NIL([o selectionIndexes], selectionIndexes, setSelectionIndexes, @"Selection indexes")
        }
        else if ([object isKindOfClass:[NSControl class]]) {
                [self processNSControl:object];
        }
        else if ([object isKindOfClass:[NSClipView class]]) {
                NSClipView* o = object;
                ADD_CLASS_LABEL(@"NSClipView Info");
                ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                ADD_BOOL([o copiesOnScroll], copiesOnScroll, setcopiesOnScroll, @"Copies on scroll")
                ADD_OBJECT([o documentCursor], documentCursor, setDocumentCursor, @"Document cursor")
                ADD_RECT([o documentRect], documentRect, setDocumentRect, @"Document rect")
                ADD_OBJECT([o documentView], documentView, setDocumentView, @"Document view")
                ADD_RECT([o documentVisibleRect], documentVisibleRect, setDocumentVisibleRect, @"Document visible rect")
                ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
        }
        else if ([object isKindOfClass:[NSOpenGLView class]]) {
                NSOpenGLView* o = object;
                ADD_CLASS_LABEL(@"NSOpenGLView Info");
                ADD_OBJECT([o openGLContext], openGLContext, setOpenGLContext, @"OpenGL context")
                ADD_OBJECT([o pixelFormat], pixelFormat, setPixelFormat, @"Pixel format")
        }
        else if ([object isKindOfClass:[NSProgressIndicator class]]) {
                NSProgressIndicator* o = object;
                ADD_CLASS_LABEL(@"NSProgressIndicator Info");
                ADD_ENUM(ControlSize, [o controlSize], controlSize, setcontrolSize, @"Control size")
                ADD_ENUM(ControlTint, [o controlTint], controlTint, setcontrolTint, @"Control tint")
                if ([o style] == NSProgressIndicatorBarStyle && ![o isIndeterminate])
                        ADD_NUMBER([o doubleValue], doubleValue, setDoubleValue, @"Double value")
                ADD_BOOL([o isBezeled], bezeled, setisBezeled, @"Is bezeled")
                ADD_BOOL([o isDisplayedWhenStopped], displayedWhenStopped, setisDisplayedWhenStopped, @"Is displayed when stopped")
                if ([o style] == NSProgressIndicatorBarStyle && ![o isIndeterminate]) {
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                }
                ADD_ENUM(ProgressIndicatorStyle, [o style], style, setstyle, @"Style")
                ADD_BOOL([o usesThreadedAnimation], usesThreadedAnimation, setusesThreadedAnimation, @"Uses threaded animation")
        }
        else if ([object isKindOfClass:[NSRulerView class]]) {
                NSRulerView* o = object;
                ADD_CLASS_LABEL(@"NSRulerView Info");
                ADD_OBJECT_NOT_NIL([o accessoryView], accessoryView, setAccessoryView, @"Accessory view")
                ADD_NUMBER([o baselineLocation], baselineLocation, setBaselineLocation, @"Baseline location")
                ADD_OBJECT([o clientView], clientView, setClientView, @"Client view")
                ADD_BOOL([o isFlipped], flipped, setisFlipped, @"Is flipped")
                ADD_OBJECTS([o markers], @"Markers")
                ADD_OBJECT([o measurementUnits], measurementUnits, setMeasurementUnits, @"Measurement units")
                ADD_ENUM(RulerOrientation, [o orientation], orientation, setorientation, @"Orientation")
                ADD_NUMBER([o originOffset], originOffset, setOriginOffset, @"Origin offset")
                ADD_NUMBER([o requiredThickness], requiredThickness, setRequiredThickness, @"Required thickness")
                ADD_NUMBER([o reservedThicknessForAccessoryView], reservedThicknessForAccessoryView, setReservedThicknessForAccessoryView, @"Reserved thickness for accessory view")
                ADD_NUMBER([o reservedThicknessForMarkers], reservedThicknessForMarkers, setReservedThicknessForMarkers, @"Reserved thickness for markers")
                ADD_NUMBER([o ruleThickness], ruleThickness, setRuleThickness, @"Rule thickness")
                ADD_OBJECT([o scrollView], scrollView, setScrollView, @"ScrollView")
        }
        else if ([object isKindOfClass:[NSScrollView class]]) {
                NSScrollView* o = object;
                ADD_CLASS_LABEL(@"NSScrollView Info");
                ADD_BOOL([o autohidesScrollers], autohidesScrollers, setautohidesScrollers, @"Autohides scrollers")
                ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                ADD_ENUM(BorderType, [o borderType], borderType, setborderType, @"Border type")
                ADD_SIZE([o contentSize], contentSize, setContentSize, @"Content size")
                ADD_OBJECT([o contentView], contentView, setContentView, @"Content view")
                ADD_OBJECT([o documentCursor], documentCursor, setDocumentCursor, @"Document cursor")
                ADD_OBJECT([o documentView], documentView, setDocumentView, @"Document view")
                ADD_RECT([o documentVisibleRect], documentVisibleRect, setDocumentVisibleRect, @"Document visible rect")
                ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                ADD_BOOL([o hasHorizontalRuler], hasHorizontalRuler, sethasHorizontalRuler, @"Has horizontal ruler")
                ADD_BOOL([o hasHorizontalScroller], hasHorizontalScroller, sethasHorizontalScroller, @"Has horizontal scroller")
                ADD_BOOL([o hasVerticalRuler], hasVerticalRuler, sethasVerticalRuler, @"Has vertical ruler")
                ADD_BOOL([o hasVerticalScroller], hasVerticalScroller, sethasVerticalScroller, @"Has vertical scroller")
                ADD_NUMBER([o horizontalLineScroll], horizontalLineScroll, setHorizontalLineScroll, @"Horizontal line scroll")
                ADD_NUMBER([o horizontalPageScroll], horizontalPageScroll, setHorizontalPageScroll, @"Horizontal page scroll")
                ADD_OBJECT([o horizontalRulerView], horizontalRulerView, setHorizontalRulerView, @"Horizontal ruler view")
                ADD_OBJECT([o horizontalScroller], horizontalScroller, setHorizontalScroller, @"Horizontal scroller")
                ADD_NUMBER([o lineScroll], lineScroll, setLineScroll, @"Line scroll")
                ADD_NUMBER([o pageScroll], pageScroll, setPageScroll, @"Page scroll")
                ADD_BOOL([o rulersVisible], rulersVisible, setrulersVisible, @"Ruller visible")
                ADD_BOOL([o scrollsDynamically], scrollsDynamically, setscrollsDynamically, @"Scrolls dynamically")
                ADD_NUMBER([o verticalLineScroll], verticalLineScroll, setVerticalLineScroll, @"Vertical line scroll")
                ADD_NUMBER([o verticalPageScroll], verticalPageScroll, setVerticalPageScroll, @"Vertical page scroll")
                ADD_OBJECT([o verticalRulerView], verticalRulerView, setVerticalRulerView, @"Vertical ruler view")
                ADD_OBJECT([o verticalScroller], verticalScroller, setVerticalScroller, @"Vertical scroller")
        }
        else if ([object isKindOfClass:[NSSplitView class]]) {
                NSSplitView* o = object;
                ADD_CLASS_LABEL(@"NSSplitView Info");
                ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                ADD_NUMBER([o dividerThickness], dividerThickness, setDividerThickness, @"Divider thickness")
                ADD_BOOL([o isVertical], vertical, setisVertical, @"Is vertical")
                ADD_OBJECT_NOT_NIL([o autosaveName], autosaveName, setAutosaveName, @"Autosave name")
        }
        else if ([object isKindOfClass:[NSTabView class]]) {
                NSTabView* o = object;
                ADD_CLASS_LABEL(@"NSTabView Info");
                ADD_BOOL([o allowsTruncatedLabels], allowsTruncatedLabels, setallowsTruncatedLabels, @"Allows truncated labels")
                ADD_RECT([o contentRect], contentRect, setContentRect, @"Content rect")
                ADD_ENUM(ControlSize, [o controlSize], controlSize, setcontrolSize, @"Control size")
                ADD_ENUM(ControlTint, [o controlTint], controlTint, setcontrolTint, @"Control tint")
                ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                ADD_OBJECT([o font], font, setFont, @"Font")
                ADD_SIZE([o minimumSize], minimumSize, setMinimumSize, @"Minimum size")
                ADD_OBJECT([o selectedTabViewItem], selectedTabViewItem, setSelectedTabViewItem, @"Selected tab view item")
                ADD_OBJECTS([o tabViewItems], @"Tab view items")
                ADD_ENUM(TabViewType, [o tabViewType], tabViewType, settabViewType, @"Tab view type")
        }
        else if ([object isKindOfClass:[NSTableHeaderView class]]) {
                NSTableHeaderView* o = object;
                ADD_CLASS_LABEL(@"NSTableHeaderView Info");
                ADD_OBJECT([o tableView], tableView, setTableView, @"Table view")
        }
        else if ([object isKindOfClass:[NSText class]]) {
                if ([object isKindOfClass:[NSTextView class]]) {
                        NSTextView* o = object;
                        ADD_CLASS_LABEL(@"NSTextView Info");
                        ADD_OBJECTS([o acceptableDragTypes], @"Acceptable drag types")
                        ADD_BOOL([o acceptsGlyphInfo], acceptsGlyphInfo, setacceptsGlyphInfo, @"Accepts glyph info")
                        ADD_OBJECTS([o allowedInputSourceLocales], @"Allowed input source locales")
                        ADD_BOOL([o allowsImageEditing], allowsImageEditing, setallowsImageEditing, @"Allows image editing")
                        ADD_BOOL([o allowsDocumentBackgroundColorChange], allowsDocumentBackgroundColorChange, setallowsDocumentBackgroundColorChange, @"Allows document background color change")
                        ADD_BOOL([o allowsUndo], allowsUndo, setallowsUndo, @"Allows undo")
                        ADD_OBJECT_NOT_NIL([o defaultParagraphStyle], defaultParagraphStyle, setDefaultParagraphStyle, @"Default paragraph style")
                        ADD_BOOL([o displaysLinkToolTips], displaysLinkToolTips, setdisplaysLinkToolTips, @"Displays link tool tips")
                        ADD_COLOR([o insertionPointColor], insertionPointColor, setInsertionPointColor, @"Insertion point color")
                        ADD_BOOL([o isAutomaticLinkDetectionEnabled], automaticLinkDetectionEnabled, setisAutomaticLinkDetectionEnabled, @"Is automatic link detection enabled")
                        ADD_BOOL([o isAutomaticQuoteSubstitutionEnabled], automaticQuoteSubstitutionEnabled, setisAutomaticQuoteSubstitutionEnabled, @"Is automatic quote substitution enabled")
                        ADD_BOOL([o isContinuousSpellCheckingEnabled], continuousSpellCheckingEnabled, setisContinuousSpellCheckingEnabled, @"Is continuous spell checking enabled")
                        ADD_BOOL([o isGrammarCheckingEnabled], grammarCheckingEnabled, setisGrammarCheckingEnabled, @"Is grammar checking enabled")
                        ADD_OBJECT_NOT_NIL([o layoutManager], layoutManager, setLayoutManager, @"Layout manager")
                        ADD_DICTIONARY([o linkTextAttributes], @"Link text attributes")
                        ADD_DICTIONARY([o markedTextAttributes], @"Marked text attributes")
                        ADD_RANGE([o rangeForUserCompletion], rangeForUserCompletion, setRangeForUserCompletion, @"Range for user completion")
                        ADD_OBJECTS([o rangesForUserCharacterAttributeChange], @"Ranges for user character attribute change")
                        ADD_OBJECTS([o rangesForUserParagraphAttributeChange], @"Ranges for user paragraph attribute change")
                        ADD_OBJECTS([o rangesForUserTextChange], @"Ranges for user text change")
                        ADD_OBJECTS([o readablePasteboardTypes], @"Readable pasteboard types")
                        ADD_OBJECTS([o selectedRanges], @"Selected ranges")
                        ADD_DICTIONARY([o selectedTextAttributes], @"Selected text attributes")
                        ADD_ENUM(SelectionAffinity, [o selectionAffinity], selectionAffinity, setselectionAffinity, @"Selection affinity")
                        ADD_ENUM(SelectionGranularity, [o selectionGranularity], selectionGranularity, setselectionGranularity, @"Selection granularity")
                        ADD_BOOL([o shouldDrawInsertionPoint], shouldDrawInsertionPoint, setshouldDrawInsertionPoint, @"Should draw insertion point")
                        ADD_BOOL([o smartInsertDeleteEnabled], smartInsertDeleteEnabled, setsmartInsertDeleteEnabled, @"Smart insert delete enabled")
                        ADD_NUMBER([o spellCheckerDocumentTag], spellCheckerDocumentTag, setSpellCheckerDocumentTag, @"Spell checker document tag")
                        ADD_OBJECT([o textContainer], textContainer, setTextContainer, @"Text container")
                        ADD_SIZE([o textContainerInset], textContainerInset, setTextContainerInset, @"Text container inset")
                        ADD_POINT([o textContainerOrigin], textContainerOrigin, setTextContainerOrigin, @"Text container origin")
                        ADD_OBJECT([o textStorage], textStorage, setTextStorage, @"Text storage")
                        ADD_DICTIONARY([o typingAttributes], @"Typing attributes")
                        ADD_BOOL([o usesFindPanel], usesFindPanel, setusesFindPanel, @"Uses find panel")
                        ADD_BOOL([o usesFontPanel], usesFontPanel, setusesFontPanel, @"Uses font panel")
                        ADD_BOOL([o usesRuler], usesRuler, setusesRuler, @"Uses ruler")
                        ADD_OBJECT([o writablePasteboardTypes], writablePasteboardTypes, setWritablePasteboardTypes, @"Writable pasteboard types")
                }

                NSText* o = object;
                ADD_CLASS_LABEL(@"NSText Info");
                ADD_ENUM(TextAlignment, [o alignment], alignment, setalignment, @"Alignment")
                ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                ADD_ENUM(WritingDirection, [o baseWritingDirection], baseWritingDirection, setbaseWritingDirection, @"Base writing direction")
                ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                ADD_OBJECT([o font], font, setFont, @"Font")
                ADD_BOOL([o importsGraphics], importsGraphics, setimportsGraphics, @"Imports graphics")
                ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
                ADD_BOOL([o isFieldEditor], fieldEditor, setisFieldEditor, @"Is field editor")
                ADD_BOOL([o isHorizontallyResizable], horizontallyResizable, setisHorizontallyResizable, @"Is horizontally resizable")
                ADD_BOOL([o isRichText], richText, setisRichText, @"Is rich text")
                ADD_BOOL([o isRulerVisible], rulerVisible, setisRulerVisible, @"Is ruler visible")
                ADD_BOOL([o isSelectable], selectable, setisSelectable, @"Is selectable")
                ADD_BOOL([o isVerticallyResizable], verticallyResizable, setisVerticallyResizable, @"Is vertically resizable")
                ADD_SIZE([o maxSize], maxSize, setMaxSize, @"Max size")
                ADD_SIZE([o minSize], minSize, setMinSize, @"Min size")
                ADD_RANGE([o selectedRange], selectedRange, setSelectedRange, @"Selected range")
                ADD_OBJECT([o string], string, setString, @"String")
                ADD_COLOR_NOT_NIL([o textColor], textColor, setTextColor, @"Text color")
                ADD_BOOL([o usesFontPanel], usesFontPanel, setusesFontPanel, @"Uses font panel")
        }

        NSView* o = object;
        ADD_CLASS_LABEL(@"NSView Info");
        ADD_OPTIONS(AutoresizingMaskOptions, [o autoresizingMask], autoresizingMask, setautoresizingMask, @"Autoresizing mask")
        ADD_BOOL([o autoresizesSubviews], autoresizesSubviews, setautoresizesSubviews, @"Autoresizes subviews")
        ADD_RECT([o bounds], bounds, setBounds, @"Bounds")
        ADD_NUMBER([o boundsRotation], boundsRotation, setBoundsRotation, @"Bounds rotation")
        ADD_BOOL([o canBecomeKeyView], canBecomeKeyView, setcanBecomeKeyView, @"Can become key view")
        ADD_BOOL([o canDraw], canDraw, setcanDraw, @"Can draw")
        ADD_OBJECT_NOT_NIL([o enclosingMenuItem], enclosingMenuItem, setEnclosingMenuItem, @"Enclosing menu item")
        ADD_OBJECT_NOT_NIL([o enclosingScrollView], enclosingScrollView, setEnclosingScrollView, @"Enclosing scroll view")
        ADD_RECT([o frame], frame, setFrame, @"Frame")
        ADD_NUMBER([o frameRotation], frameRotation, setFrameRotation, @"Frame rotation")
        ADD_ENUM(FocusRingType, [o focusRingType], focusRingType, setfocusRingType, @"Focus ring type")
        ADD_NUMBER([o gState], gState, setGState, @"gState")
        ADD_NUMBER([o heightAdjustLimit], heightAdjustLimit, setHeightAdjustLimit, @"Height adjust limit")
        ADD_BOOL([o isFlipped], flipped, setisFlipped, @"Is flipped")
        ADD_BOOL([o isHidden], hidden, setisHidden, @"Is hidden")
        ADD_BOOL([o isHiddenOrHasHiddenAncestor], hiddenOrHasHiddenAncestor, setisHiddenOrHasHiddenAncestor, @"Is hidden or has hidden ancestor")
        ADD_BOOL([o isInFullScreenMode], inFullScreenMode, setisInFullScreenMode, @"Is in full screen mode")
        ADD_BOOL([o isOpaque], opaque, setisOpaque, @"Is opaque")
        ADD_BOOL([o isRotatedFromBase], rotatedFromBase, setisRotatedFromBase, @"Is rotated from base")
        ADD_BOOL([o isRotatedOrScaledFromBase], rotatedOrScaledFromBase, setisRotatedOrScaledFromBase, @"Is rotated or scaled from base")
        ADD_OBJECT([o layer], layer, setLayer, @"Layer")
        ADD_BOOL([o mouseDownCanMoveWindow], mouseDownCanMoveWindow, setmouseDownCanMoveWindow, @"Mouse down can move window")
        ADD_BOOL([o needsDisplay], needsDisplay, setneedsDisplay, @"Needs display")
        ADD_BOOL([o needsPanelToBecomeKey], needsPanelToBecomeKey, setneedsPanelToBecomeKey, @"Needs panel to become key")
        ADD_OBJECT([o nextKeyView], nextKeyView, setNextKeyView, @"Next key view")
        ADD_OBJECT([o nextValidKeyView], nextValidKeyView, setNextValidKeyView, @"Next valid key view")
        ADD_OBJECT([o opaqueAncestor], opaqueAncestor, setOpaqueAncestor, @"Opaque ancestor")
        ADD_BOOL([o preservesContentDuringLiveResize], preservesContentDuringLiveResize, setpreservesContentDuringLiveResize, @"Preserves content during live resize")
        ADD_BOOL([o postsBoundsChangedNotifications], postsBoundsChangedNotifications, setpostsBoundsChangedNotifications, @"Posts bounds changed notifications")
        ADD_BOOL([o postsFrameChangedNotifications], postsFrameChangedNotifications, setpostsFrameChangedNotifications, @"Posts frame changed notifications")
        ADD_OBJECT([o previousKeyView], previousKeyView, setPreviousKeyView, @"Previous key view")
        ADD_OBJECT([o previousValidKeyView], previousValidKeyView, setPreviousValidKeyView, @"Previous valid key view")
        ADD_STRING([o printJobTitle], printJobTitle, setPrintJobTitle, @"Print job title")
        ADD_OBJECTS([o registeredDraggedTypes], @"Registered dragged types")
        ADD_BOOL([o shouldDrawColor], shouldDrawColor, setshouldDrawColor, @"Should draw color")
        ADD_NUMBER([o tag], tag, setTag, @"Tag")
        ADD_OBJECTS([o trackingAreas], @"Tracking areas")
        ADD_RECT([o visibleRect], visibleRect, setVisibleRect, @"Visible rect")
        ADD_BOOL([o wantsDefaultClipping], wantsDefaultClipping, setwantsDefaultClipping, @"Wants default clipping")
        ADD_BOOL([o wantsLayer], wantsLayer, setwantsLayer, @"Wants layer")
        ADD_NUMBER([o widthAdjustLimit], widthAdjustLimit, setWidthAdjustLimit, @"Width adjust limit")
        ADD_OBJECT([o window], window, setWindow, @"Window")
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
                        NSBrowser* o = object;
                        ADD_CLASS_LABEL(@"NSBrowser Info");
                        ADD_BOOL([o allowsBranchSelection], allowsBranchSelection, setallowsBranchSelection, @"Allows branch selection")
                        ADD_BOOL([o allowsEmptySelection], allowsEmptySelection, setallowsEmptySelection, @"Allows empty selection")
                        ADD_BOOL([o allowsMultipleSelection], allowsMultipleSelection, setallowsMultipleSelection, @"Allows multiple selection")
                        ADD_BOOL([o allowsTypeSelect], allowsTypeSelect, setallowsTypeSelect, @"Allows type select")
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT([o cellPrototype], cellPrototype, setCellPrototype, @"Cell prototype")
                        ADD_ENUM(BrowserColumnResizingType, [o columnResizingType], columnResizingType, setcolumnResizingType, @"Column resizing type")
                        ADD_OBJECT([o columnsAutosaveName], columnsAutosaveName, setColumnsAutosaveName, @"Columns autosave name")
                        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_SEL([o doubleAction], @"Double action")
                        ADD_NUMBER([o firstVisibleColumn], firstVisibleColumn, setFirstVisibleColumn, @"First visible column")
                        ADD_BOOL([o hasHorizontalScroller], hasHorizontalScroller, sethasHorizontalScroller, @"Has horizontal scroller")
                        ADD_BOOL([o isLoaded], loaded, setisLoaded, @"Is loaded")
                        ADD_BOOL([o isTitled], titled, setisTitled, @"Is titled")
                        ADD_NUMBER([o lastColumn], lastColumn, setLastColumn, @"Last column")
                        ADD_NUMBER([o lastVisibleColumn], lastVisibleColumn, setLastVisibleColumn, @"Last visible column")
                        ADD_OBJECT([o matrixClass], matrixClass, setMatrixClass, @"Matrix class")
                        ADD_NUMBER([o maxVisibleColumns], maxVisibleColumns, setMaxVisibleColumns, @"Max visible columns")
                        ADD_NUMBER([o minColumnWidth], minColumnWidth, setMinColumnWidth, @"Min column width")
                        ADD_NUMBER([o numberOfVisibleColumns], numberOfVisibleColumns, setNumberOfVisibleColumns, @"Number of visible columns")
                        ADD_OBJECT([o path], path, setPath, @"Path")
                        ADD_OBJECT([o pathSeparator], pathSeparator, setPathSeparator, @"Path separator")
                        ADD_BOOL([o prefersAllColumnUserResizing], prefersAllColumnUserResizing, setprefersAllColumnUserResizing, @"Prefers all column user resizing")
                        ADD_BOOL([o reusesColumns], reusesColumns, setreusesColumns, @"Reuses columns")
                        ADD_OBJECTS([o selectedCells], @"Selected cells")
                        ADD_NUMBER([o selectedColumn], selectedColumn, setSelectedColumn, @"Selected column")
                        ADD_BOOL([o sendsActionOnArrowKeys], sendsActionOnArrowKeys, setsendsActionOnArrowKeys, @"Sends action on arrow keys")
                        ADD_BOOL([o separatesColumns], separatesColumns, setseparatesColumns, @"Separates columns")
                        ADD_BOOL([o takesTitleFromPreviousColumn], takesTitleFromPreviousColumn, settakesTitleFromPreviousColumn, @"Takes title from previous column")
                        ADD_NUMBER([o titleHeight], titleHeight, setTitleHeight, @"Title height")
                }
                else if ([object isKindOfClass:[NSButton class]]) {
                        if ([object isKindOfClass:[NSPopUpButton class]]) {
                                NSPopUpButton* o = object;
                                ADD_CLASS_LABEL(@"NSPopUpButton Info");
                                ADD_BOOL([o autoenablesItems], autoenablesItems, setautoenablesItems, @"Autoenables Items")
                                ADD_NUMBER([o indexOfSelectedItem], indexOfSelectedItem, setIndexOfSelectedItem, @"Index of selected item")
                                ADD_OBJECTS([o itemArray], @"Item array")
                                ADD_NUMBER([o numberOfItems], numberOfItems, setNumberOfItems, @"Number of items")
                                ADD_OBJECT([o objectValue], objectValue, setObjectValue, @"Object value")
                                ADD_ENUM(RectEdge, [o preferredEdge], preferredEdge, setpreferredEdge, @"Preferred edge")
                                ADD_BOOL([o pullsDown], pullsDown, setpullsDown, @"Pulls down")
                                ADD_OBJECT([o selectedItem], selectedItem, setSelectedItem, @"Selected item")
                        }

                        NSButton* o = object;
                        ADD_CLASS_LABEL(@"NSButton Info");
                        ADD_BOOL([o allowsMixedState], allowsMixedState, setallowsMixedState, @"Allows mixed state")
                        ADD_OBJECT_NOT_NIL([o alternateImage], alternateImage, setAlternateImage, @"Alternate image")
                        ADD_STRING([o alternateTitle], alternateTitle, setAlternateTitle, @"Alternate title")
                        ADD_OBJECT([o attributedAlternateTitle], attributedAlternateTitle, setAttributedAlternateTitle, @"Attributed alternate title")
                        ADD_OBJECT([o attributedTitle], attributedTitle, setAttributedTitle, @"Attributed title")
                        ADD_ENUM(BezelStyle, [o bezelStyle], bezelStyle, setbezelStyle, @"Bezel style")
                        ADD_OBJECT([o image], image, setImage, @"Image")
                        ADD_ENUM(CellImagePosition, [o imagePosition], imagePosition, setimagePosition, @"Image position")
                        ADD_BOOL([o isBordered], bordered, setisBordered, @"Is bordered")
                        ADD_BOOL([o isTransparent], transparent, setisTransparent, @"Is transparent")
                        ADD_OBJECT([o keyEquivalent], keyEquivalent, setKeyEquivalent, @"Key equivalent")
                        ADD_OPTIONS(EventModifierFlags, [o keyEquivalentModifierMask] & NSDeviceIndependentModifierFlagsMask, keyEquivalentModifierMask, setKeyEquivalentModifierMask, @"Key equivalent modifier mask")
                        ADD_BOOL([o showsBorderOnlyWhileMouseInside], showsBorderOnlyWhileMouseInside, setshowsBorderOnlyWhileMouseInside, @"Shows border only while mouse inside")
                        ADD_OBJECT_NOT_NIL([o sound], sound, setSound, @"Sound")
                        ADD_ENUM(CellStateValue, [o state], state, setstate, @"State")
                        ADD_STRING([o title], title, setTitle, @"Title")
                }
                else if ([object isKindOfClass:[NSColorWell class]]) {
                        NSColorWell* o = object;
                        ADD_CLASS_LABEL(@"NSColorWell Info");
                        ADD_COLOR([o color], color, setColor, @"Color")
                        ADD_BOOL([o isActive], active, setisActive, @"Is active")
                        ADD_BOOL([o isBordered], bordered, setisBordered, @"Is bordered")
                }
                else if ([object isKindOfClass:[NSDatePicker class]]) {
                        NSDatePicker* o = object;
                        ADD_CLASS_LABEL(@"NSDatePicker Info");
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT([o calendar], calendar, setCalendar, @"Calendar")
                        ADD_OPTIONS(DatePickerElementFlags, [o datePickerElements], datePickerElements, setdatePickerElements, @"Date picker elements")
                        ADD_ENUM(DatePickerMode, [o datePickerMode], datePickerMode, setdatePickerMode, @"Date picker mode")
                        ADD_ENUM(DatePickerStyle, [o datePickerStyle], datePickerStyle, setdatePickerStyle, @"Date picker style")
                        ADD_OBJECT([o dateValue], dateValue, setDateValue, @"Date value")
                        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                        ADD_BOOL([o isBezeled], bezeled, setisBezeled, @"Is bezeled")
                        ADD_BOOL([o isBordered], bordered, setisBordered, @"Is bordered")
                        ADD_OBJECT_NOT_NIL([o locale], locale, setLocale, @"Locale")
                        ADD_OBJECT([o maxDate], maxDate, setMaxDate, @"Max date")
                        ADD_OBJECT([o minDate], minDate, setMinDate, @"Min date")
                        ADD_COLOR([o textColor], textColor, setTextColor, @"Text Color")
                        ADD_NUMBER([o timeInterval], timeInterval, setTimeInterval, @"Time interval")
                        ADD_OBJECT([o timeZone], timeZone, setTimeZone, @"Time zone")
                }
                else if ([object isKindOfClass:[NSImageView class]]) {
                        NSImageView* o = object;
                        ADD_CLASS_LABEL(@"NSImageView Info");
                        ADD_BOOL([o allowsCutCopyPaste], allowsCutCopyPaste, setallowsCutCopyPaste, @"Allows cut copy paste")
                        ADD_BOOL([o animates], animates, setanimates, @"Animates")
                        ADD_OBJECT([o image], image, setImage, @"Image")
                        ADD_ENUM(ImageAlignment, [o imageAlignment], imageAlignment, setimageAlignment, @"Image alignment")
                        ADD_ENUM(ImageFrameStyle, [o imageFrameStyle], imageFrameStyle, setimageFrameStyle, @"Image frame style")
                        ADD_ENUM(ImageScaling, [o imageScaling], imageScaling, setimageScaling, @"Image scaling")
                        ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
                }
                else if ([object isKindOfClass:[NSLevelIndicator class]]) {
                        NSLevelIndicator* o = object;
                        ADD_CLASS_LABEL(@"NSLevelIndicator Info");
                        ADD_NUMBER([o criticalValue], criticalValue, setCriticalValue, @"Critical value")
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                        ADD_NUMBER([o numberOfMajorTickMarks], numberOfMajorTickMarks, setNumberOfMajorTickMarks, @"Number of major tick marks")
                        ADD_NUMBER([o numberOfTickMarks], numberOfTickMarks, setNumberOfTickMarks, @"Number of tick marks")
                        ADD_OBJECT(objectFromTickMarkPosition([o tickMarkPosition], NO), tickMarkPosition, setTickMarkPosition, @"Tick mark position")
                        ADD_NUMBER([o warningValue], warningValue, setWarningValue, @"Warning value")
                }
                else if ([object isKindOfClass:[NSMatrix class]]) {
                        NSMatrix* o = object;
                        ADD_CLASS_LABEL(@"NSMatrix Info");
                        ADD_BOOL([o allowsEmptySelection], allowsEmptySelection, setallowsEmptySelection, @"Allows empty selection")
                        ADD_BOOL([o autosizesCells], autosizesCells, setautosizesCells, @"Autosizes cells")
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_COLOR([o cellBackgroundColor], cellBackgroundColor, setCellBackgroundColor, @"Cell background color")
                        ADD_OBJECT([o cellClass], cellClass, setCellClass, @"Cell class")
                        ADD_SIZE([o cellSize], cellSize, setCellSize, @"Cell size");

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

                        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_SEL([o doubleAction], @"Double action")
                        ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                        ADD_BOOL([o drawsCellBackground], drawsCellBackground, setdrawsCellBackground, @"Draws cell background")
                        ADD_SIZE([o intercellSpacing], intercellSpacing, setIntercellSpacing, @"Intercell spacing")
                        ADD_BOOL([o isAutoscroll], autoscroll, setisAutoscroll, @"Is autoscroll")
                        ADD_BOOL([o isSelectionByRect], selectionByRect, setisSelectionByRect, @"Is selection by rect")
                        ADD_OBJECT([o keyCell], keyCell, setKeyCell, @"Key cell")
                        ADD_ENUM(MatrixMode, [(NSMatrix*)o mode], mode, setMode, @"Mode")
                        ADD_NUMBER([o numberOfColumns], numberOfColumns, setNumberOfColumns, @"Number of columns")
                        ADD_NUMBER([o numberOfRows], numberOfRows, setNumberOfRows, @"Number of rows")
                        ADD_OBJECT([o prototype], prototype, setPrototype, @"Prototype")
                        ADD_OBJECTS([o selectedCells], @"Selected cells")
                        ADD_NUMBER([o selectedColumn], selectedColumn, setSelectedColumn, @"Selected column")
                        ADD_NUMBER([o selectedRow], selectedRow, setSelectedRow, @"Selected row")
                        ADD_BOOL([o tabKeyTraversesCells], tabKeyTraversesCells, settabKeyTraversesCells, @"Tab key traverses cells")
                }
                else if ([object isKindOfClass:[NSPathControl class]]) {
                        NSPathControl* o = object;
                        ADD_CLASS_LABEL(@"NSPathControl Info");
                        ADD_COLOR_NOT_NIL([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_SEL([o doubleAction], @"Double action")
                        ADD_OBJECTS([o pathComponentCells], @"Path component cells")
                        ADD_ENUM(PathStyle, [o pathStyle], pathStyle, setpathStyle, @"Path style")
                        ADD_OBJECT([o URL], URL, setURL, @"URL")
                }
                else if ([object isKindOfClass:[NSRuleEditor class]]) {
                        if ([object isKindOfClass:[NSPredicateEditor class]]) {
                                NSPredicateEditor* o = object;
                                ADD_CLASS_LABEL(@"NSPredicateEditor Info");
                                ADD_OBJECTS([o rowTemplates], @"Row templates")
                        }

                        NSRuleEditor* o = object;
                        ADD_CLASS_LABEL(@"NSRuleEditor Info");
                        ADD_BOOL([o canRemoveAllRows], canRemoveAllRows, setcanRemoveAllRows, @"Can remove all rows")
                        ADD_OBJECT_NOT_NIL([o criteriaKeyPath], criteriaKeyPath, setCriteriaKeyPath, @"Criteria key path")
                        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_OBJECT_NOT_NIL([o displayValuesKeyPath], displayValuesKeyPath, setDisplayValuesKeyPath, @"Display values key path")
                        ADD_DICTIONARY([o formattingDictionary], @"Formatting dictionary")
                        ADD_OBJECT_NOT_NIL([o formattingStringsFilename], formattingStringsFilename, setFormattingStringsFilename, @"Formatting strings filename")
                        ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
                        ADD_ENUM(RuleEditorNestingMode, [o nestingMode], nestingMode, setnestingMode, @"Nesting mode")
                        ADD_NUMBER([o numberOfRows], numberOfRows, setNumberOfRows, @"Number of rows")
                        ADD_OBJECT([o predicate], predicate, setPredicate, @"Predicate")
                        ADD_OBJECT([o rowClass], rowClass, setRowClass, @"Row class")
                        ADD_NUMBER([o rowHeight], rowHeight, setRowHeight, @"Row height")
                        ADD_OBJECT_NOT_NIL([o rowTypeKeyPath], rowTypeKeyPath, setRowTypeKeyPath, @"Row type key path")
                        ADD_OBJECT_NOT_NIL([o selectedRowIndexes], selectedRowIndexes, setSelectedRowIndexes, @"Selected row indexes")
                        ADD_OBJECT_NOT_NIL([o subrowsKeyPath], subrowsKeyPath, setSubrowsKeyPath, @"Subrows key path")
                }
                else if ([object isKindOfClass:[NSScroller class]]) {
                        NSScroller* o = object;
                        ADD_CLASS_LABEL(@"NSScroller Info");
                        ADD_ENUM(ScrollArrowPosition, [o arrowsPosition], arrowsPosition, setarrowsPosition, @"Arrows position")
                        ADD_ENUM(ControlSize, [o controlSize], controlSize, setcontrolSize, @"Control size")
                        ADD_ENUM(ControlTint, [o controlTint], controlTint, setcontrolTint, @"Control tint")
                        ADD_NUMBER([o doubleValue], doubleValue, setDoubleValue, @"Double value")
                        ADD_ENUM(ScrollerPart, [o hitPart], hitPart, sethitPart, @"Hit part")
                        ADD_NUMBER([o knobProportion], knobProportion, setKnobProportion, @"Knob proportion")
                        ADD_ENUM(UsableScrollerParts, [o usableParts], usableParts, setusableParts, @"Usable parts")
                }
                else if ([object isKindOfClass:[NSSegmentedControl class]]) {
                        NSSegmentedControl* o = object;
                        NSInteger segmentCount = [o segmentCount];
                        ADD_CLASS_LABEL(@"NSSegmentedControl Info");

                        ADD_NUMBER(segmentCount, segmentCount, setSegmentCount, @"Segment count")
                        ADD_NUMBER([o selectedSegment], selectedSegment, setSelectedSegment, @"Selected segment")
                                            [self processSegmentedItem:o];
                }
                else if ([object isKindOfClass:[NSSlider class]]) {
                        NSSlider* o = object;
                        ADD_CLASS_LABEL(@"NSSlider Info");
                        ADD_BOOL([o allowsTickMarkValuesOnly], allowsTickMarkValuesOnly, setallowsTickMarkValuesOnly, @"Allows tick mark values only")
                        ADD_NUMBER([o altIncrementValue], altIncrementValue, setAltIncrementValue, @"Alt increment value")
                        ADD_NUMBER([(NSSlider*)o isVertical], vertical, setVertical:, @"Is vertical")
                        ADD_NUMBER([o knobThickness], knobThickness, setKnobThickness, @"Knob thickness")
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                        ADD_NUMBER([o numberOfTickMarks], numberOfTickMarks, setNumberOfTickMarks, @"Number of tick marks")
                        ADD_OBJECT(objectFromTickMarkPosition([o tickMarkPosition], [(NSSlider*)o isVertical] == 1), tickMarkPosition, setTickMarkPosition, @"Tick mark position")
                        ADD_STRING([o title], title, setTitle, @"title")
                }
                else if ([object isKindOfClass:[NSTableView class]]) {
                        if ([object isKindOfClass:[NSOutlineView class]]) {
                                NSOutlineView* o = object;
                                ADD_CLASS_LABEL(@"NSOutlineView Info");
                                ADD_BOOL([o autoresizesOutlineColumn], autoresizesOutlineColumn, setautoresizesOutlineColumn, @"Autoresizes outline column")
                                ADD_BOOL([o autosaveExpandedItems], autosaveExpandedItems, setautosaveExpandedItems, @"Autosave expanded items")
                                ADD_BOOL([o indentationMarkerFollowsCell], indentationMarkerFollowsCell, setindentationMarkerFollowsCell, @"Indentation marker follows cell")
                                ADD_NUMBER([o indentationPerLevel], indentationPerLevel, setIndentationPerLevel, @"Indentation per level")
                                ADD_OBJECT([o outlineTableColumn], outlineTableColumn, setOutlineTableColumn, @"Outline table column")
                        }

                        NSTableView* o = object;
                        ADD_CLASS_LABEL(@"NSTableView Info");
                        ADD_BOOL([o allowsColumnReordering], allowsColumnReordering, setallowsColumnReordering, @"Allows column reordering")
                        ADD_BOOL([o allowsColumnResizing], allowsColumnResizing, setallowsColumnResizing, @"Allows column resizing")
                        ADD_BOOL([o allowsColumnSelection], allowsColumnSelection, setallowsColumnSelection, @"Allows column selection")
                        ADD_BOOL([o allowsEmptySelection], allowsEmptySelection, setallowsEmptySelection, @"Allows empty selection")
                        ADD_BOOL([o allowsMultipleSelection], allowsMultipleSelection, setallowsMultipleSelection, @"Allows multiple selection")
                        ADD_BOOL([o allowsTypeSelect], allowsTypeSelect, setallowsTypeSelect, @"Allows type select")
                        ADD_OBJECT_NOT_NIL([o autosaveName], autosaveName, setAutosaveName, @"Autosave name")
                        ADD_BOOL([o autosaveTableColumns], autosaveTableColumns, setautosaveTableColumns, @"Autosave table columns")
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_ENUM(TableViewColumnAutoresizingStyle, [o columnAutoresizingStyle], columnAutoresizingStyle, setcolumnAutoresizingStyle, @"Column autoresizing style")
                        ADD_OBJECT([o cornerView], cornerView, setCornerView, @"Corner view")
                        ADD_OBJECT([o dataSource], dataSource, setDataSource, @"Data source")
                        ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_SEL([o doubleAction], @"Double action")
                        ADD_COLOR([o gridColor], gridColor, setGridColor, @"Grid color")
                        ADD_OPTIONS(TableViewGridLineStyle, [o gridStyleMask], gridStyleMask, setgridStyleMask, @"Grid style mask")
                        ADD_OBJECT([o headerView], headerView, setHeaderView, @"Header view")
                        ADD_OBJECT_NOT_NIL([o highlightedTableColumn], highlightedTableColumn, setHighlightedTableColumn, @"Highlighted table column")
                        ADD_SIZE([o intercellSpacing],  intercellSpacing, setIntercellSpacing, @"Intercell spacing")
                        ADD_NUMBER([o numberOfColumns], numberOfColumns, setNumberOfColumns, @"Number of columns")
                        ADD_NUMBER([o numberOfRows], numberOfRows, setNumberOfRows, @"Number of rows")
                        ADD_NUMBER([o numberOfSelectedColumns], numberOfSelectedColumns, setNumberOfSelectedColumns, @"Number of selected columns")
                        ADD_NUMBER([o numberOfSelectedRows], numberOfSelectedRows, setNumberOfSelectedRows, @"Number of selected rows")
                        ADD_NUMBER([o rowHeight], rowHeight, setRowHeight, @"Row height")
                        ADD_NUMBER([o selectedColumn], selectedColumn, setSelectedColumn, @"Selected column")
                        ADD_OBJECT([o selectedColumnIndexes], selectedColumnIndexes, setSelectedColumnIndexes, @"Selected column indexes")
                        ADD_NUMBER([o selectedRow], selectedRow, setSelectedRow, @"Selected row")
                        ADD_OBJECT([o selectedRowIndexes], selectedRowIndexes, setSelectedRowIndexes, @"Selected row indexes")
                        ADD_ENUM(TableViewSelectionHighlightStyle, [o selectionHighlightStyle], selectionHighlightStyle, setselectionHighlightStyle, @"Selection highlight style")
                        ADD_OBJECTS([o sortDescriptors], @"Sort descriptors")
                        ADD_OBJECTS([o tableColumns], @"Table columns")
                        ADD_BOOL([o usesAlternatingRowBackgroundColors], usesAlternatingRowBackgroundColors, setusesAlternatingRowBackgroundColors, @"Uses alternating row background colors")
                        ADD_BOOL([o verticalMotionCanBeginDrag], verticalMotionCanBeginDrag, setverticalMotionCanBeginDrag, @"Vertical motion can begin drag")
                }
                else if ([object isKindOfClass:[NSStepper class]]) {
                        NSStepper* o = object;
                        ADD_CLASS_LABEL(@"NSStepper Info");
                        ADD_BOOL([o autorepeat], autorepeat, setautorepeat, @"Autorepeat")
                        ADD_NUMBER([o increment], increment, setIncrement, @"Increment")
                        ADD_NUMBER([o maxValue], maxValue, setMaxValue, @"Max value")
                        ADD_NUMBER([o minValue], minValue, setMinValue, @"Min value")
                        ADD_BOOL([o valueWraps], valueWraps, setvalueWraps, @"Value wraps")
                }
                else if ([object isKindOfClass:[NSTextField class]]) {
                        if ([object isKindOfClass:[NSComboBox class]]) {
                                NSComboBox* o = object;
                                ADD_CLASS_LABEL(@"NSComboBox Info");
                                if ([o usesDataSource])
                                        ADD_OBJECT([o dataSource], dataSource, setDataSource, @"Data source")
                                ADD_BOOL([o hasVerticalScroller], hasVerticalScroller, sethasVerticalScroller, @"Has vertical scroller")
                                ADD_NUMBER([o indexOfSelectedItem], indexOfSelectedItem, setIndexOfSelectedItem, @"Index of selected item")
                                ADD_SIZE([o intercellSpacing], intercellSpacing, setIntercellSpacing, @"Intercell spacing")
                                ADD_BOOL([o isButtonBordered], buttonBordered, setisButtonBordered, @"Is button bordered")
                                ADD_NUMBER([o itemHeight], itemHeight, setItemHeight, @"Item height")
                                ADD_NUMBER([o numberOfItems], numberOfItems, setNumberOfItems, @"Number of items")
                                ADD_NUMBER([o numberOfVisibleItems], numberOfVisibleItems, setNumberOfVisibleItems, @"Number of visible items")
                                if (![o usesDataSource] && [o indexOfSelectedItem] != -1)
                                        ADD_OBJECT([o objectValueOfSelectedItem], objectValueOfSelectedItem, setObjectValueOfSelectedItem, @"Object value of selected item")
                                if (![o usesDataSource])
                                        ADD_OBJECTS([o objectValues], @"Object values")
                                ADD_BOOL([o usesDataSource], usesDataSource, setusesDataSource, @"Uses data source")
                        }
                        else if ([object isKindOfClass:[NSSearchField class]]) {
                                NSSearchField* o = object;
                                if ([[o recentSearches] count] != 0 || [o recentsAutosaveName] != nil)
                                        ADD_CLASS_LABEL(@"NSSearchField Info");
                                ADD_OBJECTS([o recentSearches], @"Recent searches")
                                ADD_OBJECT_NOT_NIL([o recentsAutosaveName], recentsAutosaveName, setRecentsAutosaveName, @"Recents autosave name")
                        }
                        else if ([object isKindOfClass:[NSTokenField class]]) {
                                NSTokenField* o = object;
                                ADD_CLASS_LABEL(@"NSTokenField Info");
                                ADD_NUMBER([o completionDelay], completionDelay, setCompletionDelay, @"Completion delay")
                                ADD_OBJECT([o tokenizingCharacterSet], tokenizingCharacterSet, setTokenizingCharacterSet, @"Tokenizing character set")
                                ADD_ENUM(TokenStyle, [o tokenStyle], tokenStyle, settokenStyle, @"Token style")
                        }

                        NSTextField* o = object;
                        ADD_CLASS_LABEL(@"NSTextField Info");
                        ADD_BOOL([o allowsEditingTextAttributes], allowsEditingTextAttributes, setallowsEditingTextAttributes, @"Allows editing text attributes")
                        ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                        ADD_ENUM(TextFieldBezelStyle, [o bezelStyle], bezelStyle, setbezelStyle, @"Bezel style")
                        ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                        ADD_BOOL([o drawsBackground], drawsBackground, setdrawsBackground, @"Draws background")
                        ADD_BOOL([o importsGraphics], importsGraphics, setimportsGraphics, @"Imports graphics")
                        ADD_BOOL([o isBezeled], bezeled, setisBezeled, @"Is bezeled")
                        ADD_BOOL([o isBordered], bordered, setisBordered, @"Is bordered")
                        ADD_BOOL([o isEditable], editable, setisEditable, @"Is editable")
                        ADD_BOOL([o isSelectable], selectable, setisSelectable, @"Is selectable")
                        ADD_COLOR([o textColor], textColor, setTextColor, @"Text color")
                }

                NSControl* o = object;
                ADD_CLASS_LABEL(@"NSControl Info");
                ADD_SEL([o action], @"Action")
                ADD_ENUM(TextAlignment, [o alignment], alignment, setalignment, @"Alignment")
                ADD_ENUM(WritingDirection, [o baseWritingDirection], baseWritingDirection, setbaseWritingDirection, @"Base writing direction")
                ADD_OBJECT([o cell], cell, setCell, @"Cell")
                ADD_ENUM(ControlSize, [o controlSize], controlSize, setcontrolSize, @"Control size")
                ADD_OBJECT_NOT_NIL([o currentEditor], currentEditor, setCurrentEditor, @"Current editor")
                ADD_OBJECT([o font], font, setFont, @"Font")
                ADD_OBJECT([o formatter], formatter, setFormatter, @"Formatter")
                ADD_BOOL([o ignoresMultiClick], ignoresMultiClick, setignoresMultiClick, @"Ignores multiclick")
                ADD_BOOL([o isContinuous], continuous, setisContinuous, @"Is continuous")
                ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
                if ([o currentEditor] == nil)
                        ADD_OBJECT([o objectValue], objectValue, setObjectValue, @"Object value") // To avoid side-effects, we only call objectValue if the control is not being edited, which is determined with the currentEditor call.
                ADD_BOOL([o refusesFirstResponder], refusesFirstResponder, setrefusesFirstResponder, @"Refuses first responder")
                ADD_OBJECT([o selectedCell], selectedCell, setSelectedCell, @"Selected cell")
                ADD_NUMBER([o selectedTag], selectedTag, setSelectedTag, @"Selected tag")
                ADD_OBJECT([o target], target, setTarget, @"Target")
        }
}

- (void)processNSWindow:(id)object
{
        {
                if ([object isKindOfClass:[NSPanel class]]) {
                        if ([object isKindOfClass:[NSColorPanel class]]) {
                                NSColorPanel* o = object;
                                ADD_CLASS_LABEL(@"NSColorPanel Info");
                                ADD_OBJECT_NOT_NIL([o accessoryView], accessoryView, setAccessoryView, @"Accessory view")
                                ADD_NUMBER([o alpha], alpha, setAlpha, @"Alpha")
                                ADD_COLOR([o color], color, setColor, @"Color")
                                ADD_BOOL([o isContinuous], continuous, setisContinuous, @"Is continuous")
                                ADD_ENUM(ColorPanelMode, [o mode], mode, setmode, @"Mode")
                                ADD_BOOL([o showsAlpha], showsAlpha, setshowsAlpha, @"Shows alpha")
                        }
                        else if ([object isKindOfClass:[NSFontPanel class]]) {
                                NSFontPanel* o = object;
                                ADD_CLASS_LABEL(@"NSFontPanel Info");
                                ADD_OBJECT_NOT_NIL([o accessoryView], accessoryView, setAccessoryView, @"Accessory view")
                                ADD_BOOL([o isEnabled], enabled, setisEnabled, @"Is enabled")
                        }
                        else if ([object isKindOfClass:[NSSavePanel class]]) {
                                if ([object isKindOfClass:[NSOpenPanel class]]) {
                                        NSOpenPanel* o = object;
                                        ADD_CLASS_LABEL(@"NSOpenPanel Info");
                                        ADD_BOOL([o allowsMultipleSelection], allowsMultipleSelection, setallowsMultipleSelection, @"Allows multiple selection")
                                        ADD_BOOL([o canChooseDirectories], canChooseDirectories, setcanChooseDirectories, @"Can choose directories")
                                        ADD_BOOL([o canChooseFiles], canChooseFiles, setcanChooseFiles, @"Can choose files")
                                        ADD_OBJECTS([o filenames], @"Filenames")
                                        ADD_BOOL([o resolvesAliases], resolvesAliases, setresolvesAliases, @"Resolves aliases")
                                        ADD_OBJECTS([o URLs], @"URLs")
                                }

                                NSSavePanel* o = object;
                                ADD_CLASS_LABEL(@"NSSavePanel Info");
                                ADD_OBJECT_NOT_NIL([o accessoryView], accessoryView, setAccessoryView, @"Accessory view")
                                ADD_OBJECTS([o allowedFileTypes], @"Allowed file types")
                                ADD_BOOL([o allowsOtherFileTypes], allowsOtherFileTypes, setallowsOtherFileTypes, @"Allows other file types")
                                ADD_BOOL([o canCreateDirectories], canCreateDirectories, setcanCreateDirectories, @"Can create directories")
                                ADD_BOOL([o canSelectHiddenExtension], canSelectHiddenExtension, setcanSelectHiddenExtension, @"Can select hidden extension")
                                ADD_OBJECT_NOT_NIL([o delegate], delegate, setDelegate, @"Delegate")
                                ADD_OBJECT([o directory], directory, setDirectory, @"Directory")
                                ADD_OBJECT([o filename], filename, setFilename, @"Filename")
                                ADD_BOOL([o isExpanded], expanded, setisExpanded, @"Is expanded")
                                ADD_BOOL([o isExtensionHidden], extensionHidden, setisExtensionHidden, @"Is extension hidden")
                                ADD_STRING([o message], message, setMessage, @"Message")
                                ADD_STRING([o nameFieldLabel], nameFieldLabel, setNameFieldLabel, @"nameFieldLabel")
                                ADD_OBJECT([o prompt], prompt, setPrompt, @"Prompt")
                                ADD_BOOL([o treatsFilePackagesAsDirectories], treatsFilePackagesAsDirectories, settreatsFilePackagesAsDirectories, @"Treats file packages as directories")
                                ADD_OBJECT([o URL], URL, setURL, @"URL")
                        }


                        NSPanel* o = object;
                        ADD_CLASS_LABEL(@"NSPanel Info");
                        ADD_BOOL([o becomesKeyOnlyIfNeeded], becomesKeyOnlyIfNeeded, setbecomesKeyOnlyIfNeeded, @"Becomes key only if needed")
                        ADD_BOOL([o isFloatingPanel], floatingPanel, setisFloatingPanel, @"Is floating panel")
                }

                NSWindow* o = object;
                ADD_CLASS_LABEL(@"NSWindow Info");
                ADD_BOOL([o acceptsMouseMovedEvents], acceptsMouseMovedEvents, setacceptsMouseMovedEvents, @"Accepts mouse moved events")
                ADD_BOOL([o allowsToolTipsWhenApplicationIsInactive], allowsToolTipsWhenApplicationIsInactive, setallowsToolTipsWhenApplicationIsInactive, @"Allows tool tips when application is inactive")
                ADD_NUMBER([o alphaValue], alphaValue, setAlphaValue, @"Alpha value")
                ADD_BOOL([o areCursorRectsEnabled], areCursorRectsEnabled, setareCursorRectsEnabled, @"Are cursor rects enabled")
                ADD_SIZE([o aspectRatio], aspectRatio, setAspectRatio, @"Aspect ratio")
                ADD_OBJECT_NOT_NIL([o attachedSheet], attachedSheet, setAttachedSheet, @"Attached sheet")
                ADD_BOOL([o autorecalculatesKeyViewLoop], autorecalculatesKeyViewLoop, setautorecalculatesKeyViewLoop, @"Autorecalculates key view loop")
                ADD_ENUM(WindowBackingLocation, [o backingLocation], backingLocation, setbackingLocation, @"Backing location")
                ADD_COLOR([o backgroundColor], backgroundColor, setBackgroundColor, @"Background color")
                ADD_ENUM(BackingStoreType, [o backingType], backingType, setbackingType, @"Backing type")
                ADD_BOOL([o canBecomeKeyWindow], canBecomeKeyWindow, setcanBecomeKeyWindow, @"Can become key window")
                ADD_BOOL([o canBecomeMainWindow], canBecomeMainWindow, setcanBecomeMainWindow, @"Can become main window")
                ADD_BOOL([o canBecomeVisibleWithoutLogin], canBecomeVisibleWithoutLogin, setcanBecomeVisibleWithoutLogin, @"Can become visible without login")
                ADD_BOOL([o canHide], canHide, setcanHide, @"Can hide")
                ADD_BOOL([o canStoreColor], canStoreColor, setcanStoreColor, @"Can store color")
                ADD_ENUM(WindowCollectionBehavior, [o collectionBehavior], collectionBehavior, setcollectionBehavior, @"Collection behavior")
                ADD_OBJECTS([o childWindows], @"Child windows")
                ADD_SIZE([o contentAspectRatio], contentAspectRatio,  setContentAspectRatio, @"Content aspect ratio")
                ADD_SIZE([o contentMaxSize], contentMaxSize,  setContentMaxSize, @"Content max size")
                ADD_SIZE([o contentMinSize], contentMinSize,  setContentMinSize, @"Content min size")
                ADD_SIZE([o contentResizeIncrements], contentResizeIncrements, setContentResizeIncrements, @"Content resize increments")
                ADD_OBJECT([o contentView], contentView, setContentView, @"Content view")
                ADD_OBJECT_NOT_NIL([o deepestScreen], deepestScreen, setDeepestScreen, @"Deepest screen")
                ADD_OBJECT([o defaultButtonCell], defaultButtonCell, setDefaultButtonCell, @"Default button cell")
                ADD_OBJECT([o delegate], delegate, setDelegate, @"Delegate")
                ADD_NUMBER([o depthLimit], depthLimit, setDepthLimit, @"Depth limit")
                ADD_DICTIONARY([o deviceDescription], @"Device description")
                ADD_BOOL([o displaysWhenScreenProfileChanges], displaysWhenScreenProfileChanges, setdisplaysWhenScreenProfileChanges, @"Displays when screen profile changes")
                ADD_OBJECTS([o drawers], @"Drawers")
                ADD_OBJECT([o firstResponder], firstResponder, setFirstResponder, @"First responder")
                ADD_RECT([o frame], frame, setFrame, @"Frame")
                ADD_OBJECT_NOT_NIL([o frameAutosaveName], frameAutosaveName, setFrameAutosaveName, @"Frame autosave name")
                ADD_OBJECT([o graphicsContext], graphicsContext, setGraphicsContext, @"Graphics context")
                // Call to gState fails when the window in miniaturized
                //ADD_NUMBER(            [o gState]                             ,@"gState")
                ADD_BOOL([o hasDynamicDepthLimit], hasDynamicDepthLimit, sethasDynamicDepthLimit, @"Has dynamic depth limit")
                ADD_BOOL([o hasShadow], hasShadow, sethasShadow, @"Has shadow")
                ADD_BOOL([o hidesOnDeactivate], hidesOnDeactivate, sethidesOnDeactivate, @"Hides on deactivate")
                ADD_BOOL([o ignoresMouseEvents], ignoresMouseEvents, setignoresMouseEvents, @"Ignores mouse events")
                ADD_OBJECT([o initialFirstResponder], initialFirstResponder, setInitialFirstResponder, @"Initial first responder")
                ADD_BOOL([o isAutodisplay], autodisplay, setisAutodisplay, @"Is autodisplay")
                ADD_BOOL([o isDocumentEdited], documentEdited, setisDocumentEdited, @"Is document edited")
                ADD_BOOL([o isExcludedFromWindowsMenu], excludedFromWindowsMenu, setisExcludedFromWindowsMenu, @"Is exclude from windowsmenu")
                ADD_BOOL([o isFlushWindowDisabled], flushWindowDisabled, setisFlushWindowDisabled, @"Is flush window disabled")
                ADD_BOOL([o isMiniaturized], miniaturized, setisMiniaturized, @"Is miniaturized")
                ADD_BOOL([o isMovableByWindowBackground], movableByWindowBackground, setisMovableByWindowBackground, @"Is movable by window background")
                ADD_BOOL([o isOneShot], oneShot, setisOneShot, @"Is oneShot")
                ADD_BOOL([o isOpaque], opaque, setisOpaque, @"Is opaque")
                ADD_BOOL([o isReleasedWhenClosed], releasedWhenClosed, setisReleasedWhenClosed, @"Is released when closed")
                ADD_BOOL([o isSheet], sheet, setisSheet, @"Is sheet")
                ADD_BOOL([o isVisible], visible, setisVisible, @"Is visible")
                ADD_BOOL([o isZoomed], zoomed, setisZoomed, @"Is zoomed")
                ADD_ENUM(SelectionDirection, [o keyViewSelectionDirection], keyViewSelectionDirection, setkeyViewSelectionDirection, @"Key view selection direction")
                ADD_ENUM(WindowLevel, [o level], level, setlevel, @"Level")
                ADD_SIZE([o maxSize], maxSize, setMaxSize, @"Max size")
                ADD_SIZE([o minSize], minSize, setMinSize, @"Min size")
                ADD_OBJECT_NOT_NIL([o miniwindowImage], miniwindowImage, setMiniwindowImage, @"Miniwindow image")
                ADD_STRING([o miniwindowTitle], miniwindowTitle, setMiniwindowTitle, @"Miniwindow title")
                ADD_OBJECT_NOT_NIL([o parentWindow], parentWindow, setParentWindow, @"Parent window")
                ADD_ENUM(WindowBackingLocation, [o preferredBackingLocation], preferredBackingLocation, setpreferredBackingLocation, @"Preferred backing location")
                ADD_BOOL([o preservesContentDuringLiveResize], preservesContentDuringLiveResize, setpreservesContentDuringLiveResize, @"Preserves content during live resize")
                ADD_OBJECT_NOT_NIL([o representedFilename], representedFilename, setRepresentedFilename, @"Represented filename")
                ADD_OBJECT_NOT_NIL([o representedURL], representedURL, setRepresentedURL, @"Represented URL")
                ADD_SIZE([o resizeIncrements], resizeIncrements,  setResizeIncrements, @"Resize increments")
                ADD_OBJECT([o screen], screen, setScreen, @"Screen")
                ADD_ENUM(WindowSharingType, [o sharingType], sharingType, setsharingType, @"Sharing type")
                ADD_BOOL([o showsResizeIndicator], showsResizeIndicator, setshowsResizeIndicator, @"Shows resize indicator")
                ADD_BOOL([o showsToolbarButton], showsToolbarButton, setshowsToolbarButton, @"Shows toolbar button")
                ADD_OPTIONS(WindowMask, [o styleMask], styleMask, setstyleMask, @"Style mask")
                ADD_STRING([o title], title, setTitle, @"Title")
                ADD_OBJECT_NOT_NIL([o toolbar], toolbar, setToolbar, @"Toolbar")
                ADD_NUMBER([o userSpaceScaleFactor], userSpaceScaleFactor, setUserSpaceScaleFactor, @"User space scale factor")
                ADD_BOOL([o viewsNeedDisplay], viewsNeedDisplay, setviewsNeedDisplay, @"Views need display")
                ADD_OBJECT_NOT_NIL([o windowController], windowController, setWindowController, @"Window controller")
                ADD_NUMBER([o windowNumber], windowNumber, setWindowNumber, @"Window number")
                ADD_BOOL([o worksWhenModal], worksWhenModal, setworksWhenModal, @"Works when modal")
        }
}
@end
