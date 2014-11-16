//
//  FSObjectEnumInfo.m
//  FScript
//
//  Created by Anthony Dervish on 16/11/2014.
//
//

#import "FSObjectEnumInfo.h"
#import "FSNamedNumber.h"
#import "FSNumber.h"
#import "FSObjectBrowserNamedObjectWrapper.h"

#import "CHBidirectionalDictionary.h"
#import "metamacros.h"

#define _BIDICT(_idx, _enum) \
@(_enum): @metamacro_stringify(_enum),

#define _BIDICT_LEADER(_name) \
static inline CHBidirectionalDictionary *_name ## Bimap() { \
static CHBidirectionalDictionary *dict = nil; \
if (!dict) { \
dict = [CHBidirectionalDictionary new]; \
[dict addEntriesFromDictionary:

#define BIDICT(_name, ...) \
_BIDICT_LEADER(_name) \
@{ metamacro_foreach(_BIDICT, ,__VA_ARGS__) } \
];} \
return dict; \
}

#define BIDICT_LIT(_name, _dict) \
_BIDICT_LEADER(_name) \
_dict \
];} \
return dict; \
}

#define _IDENTITY(_idx, _val) _val

#define OPTSMASK(...) \
metamacro_foreach(_IDENTITY, |, __VA_ARGS__)

#define BIMAP_CLASS_METHODS_DECL(_name) \
+(id)objectFor ## _name :(NS ## _name)mask; \
+(NSDictionary*)optionsFor ## _name ; \
extern id objectFrom ## _name(NS ## _name _name);

#define BIMAP_CLASS_METHODS_DEFN(_name) \
+(id)objectFor ## _name :(NS ## _name)mask { return objectFrom ## _name(mask); } \
+(NSDictionary*)optionsFor ## _name { return (_name ## Bimap()).inverseDictionary; }

#define ENUM_FUNC(_name) \
id objectFrom ## _name(NS ## _name _name) \
{ \
  CHBidirectionalDictionary *dict = _name ## Bimap(); \
  id lookup = dict[@(_name)]; \
  return lookup ? [FSNamedNumber namedNumberWithDouble:(double)_name name:lookup] : [FSNumber numberWithDouble:_name]; \
} \

// Define a lookup function 'objectTo<Enumeration>', for simple enumerations (can take one, and only one value from the enum)
#define ENUMTOOBJ(_name, ...) \
BIDICT(_name, __VA_ARGS__) \
ENUM_FUNC(_name) \
BIMAP_CLASS_METHODS_DEFN(_name)


// Same as 'ENUMTOOBJ', but use when the elements of the 'enumeration' are actually macros
#define ENUMTOOBJ_DICT(_name, _dict) \
BIDICT_LIT(_name, _dict) \
ENUM_FUNC(_name) \
BIMAP_CLASS_METHODS_DEFN(_name)

#define OPTSDICT(_name, ...) \
const NSUInteger _name ## Mask = OPTSMASK(__VA_ARGS__); \
BIDICT(_name, __VA_ARGS__)

// Define a lookup function 'objectTo<Enumeration>', for flag enumerations (can take a logical OR of enumeration values)
#define OPTSTOOBJ(_name, ...) \
OPTSDICT(_name, __VA_ARGS__) \
id objectFrom ## _name(NS ## _name mask) \
{ \
if (_name ## Mask == 0 || (mask & ~(_name ## Mask))) { return [FSNumber numberWithDouble:mask]; } \
CHBidirectionalDictionary *dict = _name ## Bimap(); \
NSMutableArray *result = [NSMutableArray array] ; \
for (NSNumber *opt in dict.allKeys) { \
if (mask & opt.unsignedIntegerValue) { \
[result addObject:dict[opt]]; \
} \
} \
return result.count ? [FSNamedNumber namedNumberWithDouble:mask name:[result componentsJoinedByString:@" + "]] : [FSNumber numberWithDouble:mask];\
} \
BIMAP_CLASS_METHODS_DEFN(_name)

@implementation FSObjectEnumInfo

ENUMTOOBJ(AnimationBlockingMode,
          NSAnimationBlocking,
          NSAnimationNonblocking,
          NSAnimationNonblockingThreaded
          );



ENUMTOOBJ(AnimationCurve,
          NSAnimationEaseInOut,
          NSAnimationEaseIn,
          NSAnimationEaseOut,
          NSAnimationLinear
          );


ENUMTOOBJ(AlertStyle,
          NSWarningAlertStyle,
          NSInformationalAlertStyle,
          NSCriticalAlertStyle
          );


OPTSTOOBJ(AutoresizingMaskOptions,
          NSViewMinXMargin,
          NSViewWidthSizable,
          NSViewMaxXMargin,
          NSViewMinYMargin,
          NSViewHeightSizable,
          NSViewMaxYMargin
          );

ENUMTOOBJ(AttributeType,
          NSUndefinedAttributeType,
          NSInteger16AttributeType,
          NSInteger32AttributeType,
          NSInteger64AttributeType,
          NSDecimalAttributeType,
          NSDoubleAttributeType,
          NSFloatAttributeType,
          NSStringAttributeType,
          NSBooleanAttributeType,
          NSDateAttributeType,
          NSBinaryDataAttributeType,
          NSTransformableAttributeType
          );


ENUMTOOBJ(BackgroundStyle,
          NSBackgroundStyleLight,
          NSBackgroundStyleDark,
          NSBackgroundStyleRaised,
          NSBackgroundStyleLowered
          );



ENUMTOOBJ(BackingStoreType,
          NSBackingStoreBuffered,
          NSBackingStoreRetained,
          NSBackingStoreNonretained
          );


ENUMTOOBJ(BorderType,
          NSNoBorder,
          NSLineBorder,
          NSBezelBorder,
          NSGrooveBorder
          );

ENUMTOOBJ(BezelStyle,
          NSRoundedBezelStyle,
          NSRegularSquareBezelStyle,
          NSThickSquareBezelStyle,
          NSThickerSquareBezelStyle,
          NSDisclosureBezelStyle,
          NSShadowlessSquareBezelStyle,
          NSCircularBezelStyle,
          NSTexturedSquareBezelStyle,
          NSHelpButtonBezelStyle,
          NSSmallSquareBezelStyle,
          NSTexturedRoundedBezelStyle
          );



OPTSTOOBJ(BitmapFormat,
          NSAlphaFirstBitmapFormat,
          NSAlphaNonpremultipliedBitmapFormat,
          NSFloatingPointSamplesBitmapFormat
          );

ENUMTOOBJ(BoxType,
          NSBoxPrimary,
          NSBoxSecondary,
          NSBoxSeparator,
          NSBoxOldStyle,
          NSBoxCustom
          );


OPTSTOOBJ(EventButtonMask,
          NSPenTipMask,
          NSPenLowerSideMask,
          NSPenUpperSideMask
          );


ENUMTOOBJ(BrowserColumnResizingType,
          NSBrowserNoColumnResizing,
          NSBrowserAutoColumnResizing,
          NSBrowserUserColumnResizing
          );


/*static id objectFromButtonType(NSButtonType buttonType)
 {
 switch (buttonType)
 {
 case NSMomentaryLight:        return [NamedNumber namedNumberWithDouble:buttonType name:@"NSMomentaryLight"];
 case NSMomentaryPushButton:   return [NamedNumber namedNumberWithDouble:buttonType name:@"NSMomentaryPushButton"];
 case NSMomentaryChangeButton: return [NamedNumber namedNumberWithDouble:buttonType name:@"NSMomentaryChangeButton"];
 case NSPushOnPushOffButton:   return [NamedNumber namedNumberWithDouble:buttonType name:@"NSPushOnPushOffButton"];
 case NSOnOffButton:           return [NamedNumber namedNumberWithDouble:buttonType name:@"NSOnOffButton"];
 case NSToggleButton:          return [NamedNumber namedNumberWithDouble:buttonType name:@"NSToggleButton"];
 case NSSwitchButton:          return [NamedNumber namedNumberWithDouble:buttonType name:@"NSSwitchButton"];
 case NSRadioButton:           return [NamedNumber namedNumberWithDouble:buttonType name:@"NSRadioButton"];
 default:                      return [Number numberWithDouble:buttonType];
 }
 }*/

ENUMTOOBJ(CellImagePosition,
          NSNoImage,
          NSImageOnly,
          NSImageLeft,
          NSImageRight,
          NSImageBelow,
          NSImageAbove,
          NSImageOverlaps
          );


OPTSTOOBJ(CellStyleMask,
          NSNoCellMask,
          NSContentsCellMask,
          NSPushInCellMask,
          NSChangeGrayCellMask,
          NSChangeBackgroundCellMask
          );

ENUMTOOBJ(CellStateValue,
          NSMixedState,
          NSOffState,
          NSOnState
          );


ENUMTOOBJ(CellType,
          NSNullCellType,
          NSTextCellType,
          NSImageCellType
          );


ENUMTOOBJ(CharacterCollection,
          NSIdentityMappingCharacterCollection,
          NSAdobeCNS1CharacterCollection,
          NSAdobeGB1CharacterCollection,
          NSAdobeJapan1CharacterCollection,
          NSAdobeJapan2CharacterCollection,
          NSAdobeKorea1CharacterCollection
          );


ENUMTOOBJ(ColorPanelMode,
          NSGrayModeColorPanel,
          NSRGBModeColorPanel,
          NSCMYKModeColorPanel,
          NSHSBModeColorPanel,
          NSCustomPaletteModeColorPanel,
          NSColorListModeColorPanel,
          NSWheelModeColorPanel,
          NSCrayonModeColorPanel
          );


ENUMTOOBJ(ColorRenderingIntent,
          NSColorRenderingIntentDefault,
          NSColorRenderingIntentAbsoluteColorimetric,
          NSColorRenderingIntentRelativeColorimetric,
          NSColorRenderingIntentPerceptual,
          NSColorRenderingIntentSaturation
          );


OPTSTOOBJ(ComparisonPredicateOptions,
          NSCaseInsensitivePredicateOption,
          NSDiacriticInsensitivePredicateOption,
          NSNormalizedPredicateOption
          );

ENUMTOOBJ(ComparisonPredicateModifier,
          NSDirectPredicateModifier,
          NSAllPredicateModifier,
          NSAnyPredicateModifier
          );


ENUMTOOBJ(CompositingOperation,
          NSCompositeClear,
          NSCompositeCopy,
          NSCompositeSourceOver,
          NSCompositeSourceIn,
          NSCompositeSourceOut,
          NSCompositeSourceAtop,
          NSCompositeDestinationOver,
          NSCompositeDestinationIn,
          NSCompositeDestinationOut,
          NSCompositeDestinationAtop,
          NSCompositeXOR,
          NSCompositePlusDarker,
          NSCompositeHighlight,
          NSCompositePlusLighter
          );



ENUMTOOBJ(CompoundPredicateType,
          NSNotPredicateType,
          NSAndPredicateType,
          NSOrPredicateType
          );


ENUMTOOBJ(ControlSize,
          NSRegularControlSize,
          NSSmallControlSize,
          NSMiniControlSize
          );


ENUMTOOBJ(ControlTint,
          NSDefaultControlTint,
          NSBlueControlTint,
          NSGraphiteControlTint,
          NSClearControlTint
          );

OPTSTOOBJ(DatePickerElementFlags,
          NSHourMinuteDatePickerElementFlag,
          NSHourMinuteSecondDatePickerElementFlag,
          NSTimeZoneDatePickerElementFlag,
          NSYearMonthDatePickerElementFlag,
          NSYearMonthDayDatePickerElementFlag,
          NSEraDatePickerElementFlag
          );

ENUMTOOBJ(DatePickerMode,
          NSSingleDateMode,
          NSRangeDateMode
          );


ENUMTOOBJ(DatePickerStyle,
          NSTextFieldAndStepperDatePickerStyle,
          NSClockAndCalendarDatePickerStyle
          );


ENUMTOOBJ(DeleteRule,
          NSNoActionDeleteRule,
          NSNullifyDeleteRule,
          NSCascadeDeleteRule,
          NSDenyDeleteRule
          );


ENUMTOOBJ(DrawerState,
          NSDrawerClosedState,
          NSDrawerOpeningState,
          NSDrawerOpenState,
          NSDrawerClosingState
          );



ENUMTOOBJ(EventType,
          NSLeftMouseDown,
          NSLeftMouseUp,
          NSRightMouseDown,
          NSRightMouseUp,
          NSOtherMouseDown,
          NSOtherMouseUp,
          NSMouseMoved,
          NSLeftMouseDragged,
          NSRightMouseDragged,
          NSOtherMouseDragged,
          NSMouseEntered,
          NSMouseExited,
          NSCursorUpdate,
          NSKeyDown,
          NSKeyUp,
          NSFlagsChanged,
          NSAppKitDefined,
          NSSystemDefined,
          NSApplicationDefined,
          NSPeriodic,
          NSScrollWheel,
          NSTabletPoint,
          NSTabletProximity
          );


ENUMTOOBJ(EventSubtype,
          NSMouseEventSubtype,
          NSTabletPointEventSubtype,
          NSTabletProximityEventSubtype
          );


ENUMTOOBJ(ExpressionType,
          NSConstantValueExpressionType,
          NSEvaluatedObjectExpressionType,
          NSVariableExpressionType,
          NSKeyPathExpressionType,
          NSFunctionExpressionType,
          NSUnionSetExpressionType,
          NSIntersectSetExpressionType,
          NSMinusSetExpressionType,
          NSSubqueryExpressionType,
          NSAggregateExpressionType
          );



ENUMTOOBJ(FetchRequestResultType,
          NSManagedObjectResultType,
          NSManagedObjectIDResultType
          );


ENUMTOOBJ(FocusRingType,
          NSFocusRingTypeDefault,
          NSFocusRingTypeNone,
          NSFocusRingTypeExterior
          );


ENUMTOOBJ(FontRenderingMode,
          NSFontDefaultRenderingMode,
          NSFontAntialiasedRenderingMode,
          NSFontIntegerAdvancementsRenderingMode,
          NSFontAntialiasedIntegerAdvancementsRenderingMode
          );


ENUMTOOBJ(GradientType,
          NSGradientNone,
          NSGradientConcaveWeak,
          NSGradientConcaveStrong,
          NSGradientConvexWeak,
          NSGradientConvexStrong
          );


OPTSTOOBJ(TableViewGridLineStyle,
          NSTableViewSolidVerticalGridLineMask,
          NSTableViewSolidHorizontalGridLineMask,
          NSTableViewDashedHorizontalGridLineMask
          );
          

ENUMTOOBJ(ImageAlignment,
          NSImageAlignCenter,
          NSImageAlignTop,
          NSImageAlignTopLeft,
          NSImageAlignTopRight,
          NSImageAlignLeft,
          NSImageAlignBottom,
          NSImageAlignBottomLeft,
          NSImageAlignBottomRight,
          NSImageAlignRight
          );


ENUMTOOBJ(ImageCacheMode,
          NSImageCacheDefault,
          NSImageCacheAlways,
          NSImageCacheBySize,
          NSImageCacheNever
          );



ENUMTOOBJ(ImageFrameStyle,
          NSImageFrameNone,
          NSImageFramePhoto,
          NSImageFrameGrayBezel,
          NSImageFrameGroove,
          NSImageFrameButton
          );



ENUMTOOBJ(ImageInterpolation,
          NSImageInterpolationDefault,
          NSImageInterpolationNone,
          NSImageInterpolationLow,
          NSImageInterpolationHigh
          );


ENUMTOOBJ(ImageScaling,
          NSImageScaleProportionallyDown,
          NSImageScaleAxesIndependently,
          NSImageScaleNone,
          NSImageScaleProportionallyUpOrDown
          );


OPTSTOOBJ(EventModifierFlags,
          NSAlphaShiftKeyMask,
          NSShiftKeyMask,
          NSControlKeyMask,
          NSAlternateKeyMask,
          NSCommandKeyMask,
          NSNumericPadKeyMask,
          NSHelpKeyMask,
          NSFunctionKeyMask
          );

id objectFromKeyModifierMask(NSUInteger mask)
{
  NSUInteger deviceIndependentMask = mask & ~(NSUInteger)32767; // The lower 16 bits of the modifier flags are reserved for device-dependent bits.
  return objectFromEventModifierFlags(deviceIndependentMask);
}

OPTSTOOBJ(GlyphStorageLayoutOptions,
          NSShowControlGlyphs,
          NSShowInvisibleGlyphs,
          NSWantsBidiLevels
          );


ENUMTOOBJ(LevelIndicatorStyle,
          NSRelevancyLevelIndicatorStyle,
          NSContinuousCapacityLevelIndicatorStyle,
          NSDiscreteCapacityLevelIndicatorStyle,
          NSRatingLevelIndicatorStyle
          );


ENUMTOOBJ(LineBreakMode,
          NSLineBreakByWordWrapping,
          NSLineBreakByCharWrapping,
          NSLineBreakByClipping,
          NSLineBreakByTruncatingHead,
          NSLineBreakByTruncatingTail,
          NSLineBreakByTruncatingMiddle
          );


ENUMTOOBJ(LineCapStyle,
          NSButtLineCapStyle,
          NSRoundLineCapStyle,
          NSSquareLineCapStyle
          );


ENUMTOOBJ(LineJoinStyle,
          NSMiterLineJoinStyle,
          NSRoundLineJoinStyle,
          NSBevelLineJoinStyle
          );


ENUMTOOBJ(MatrixMode,
          NSRadioModeMatrix,
          NSHighlightModeMatrix,
          NSListModeMatrix,
          NSTrackModeMatrix
          );


id objectFromMergePolicy(id mergePolicy)
{
  NSString *name = nil;
  
  if      (mergePolicy == NSErrorMergePolicy)                      name = @"NSErrorMergePolicy";
  else if (mergePolicy == NSMergeByPropertyStoreTrumpMergePolicy)  name = @"NSMergeByPropertyStoreTrumpMergePolicy";
  else if (mergePolicy == NSMergeByPropertyObjectTrumpMergePolicy) name = @"NSMergeByPropertyObjectTrumpMergePolicy";
  else if (mergePolicy == NSOverwriteMergePolicy)                  name = @"NSOverwriteMergePolicy";
  else if (mergePolicy == NSRollbackMergePolicy)                   name = @"NSRollbackMergePolicy";
  
  if (name) return [FSObjectBrowserNamedObjectWrapper namedObjectWrapperWithObject:mergePolicy name:name];
  else      return mergePolicy;
}

ENUMTOOBJ(RuleEditorNestingMode,
          NSRuleEditorNestingModeSingle,
          NSRuleEditorNestingModeList,
          NSRuleEditorNestingModeCompound,
          NSRuleEditorNestingModeSimple
          );


ENUMTOOBJ(PathStyle,
          NSPathStyleStandard,
          NSPathStyleNavigationBar,
          NSPathStylePopUp
          );


ENUMTOOBJ(PointingDeviceType,
          NSUnknownPointingDevice,
          NSPenPointingDevice,
          NSCursorPointingDevice,
          NSEraserPointingDevice
          );


ENUMTOOBJ(PredicateOperatorType,
          NSLessThanPredicateOperatorType,
          NSLessThanOrEqualToPredicateOperatorType,
          NSGreaterThanPredicateOperatorType,
          NSGreaterThanOrEqualToPredicateOperatorType,
          NSEqualToPredicateOperatorType,
          NSNotEqualToPredicateOperatorType,
          NSMatchesPredicateOperatorType,
          NSLikePredicateOperatorType,
          NSBeginsWithPredicateOperatorType,
          NSEndsWithPredicateOperatorType,
          NSInPredicateOperatorType,
          NSCustomSelectorPredicateOperatorType,
          NSContainsPredicateOperatorType,
          NSBetweenPredicateOperatorType
          );


ENUMTOOBJ(ProgressIndicatorStyle,
          NSProgressIndicatorBarStyle,
          NSProgressIndicatorSpinningStyle
          );


ENUMTOOBJ(PopUpArrowPosition,
          NSPopUpNoArrow,
          NSPopUpArrowAtCenter,
          NSPopUpArrowAtBottom
          );


ENUMTOOBJ_DICT(RectEdge,
               (@{@(NSMinXEdge):@"NSMinXEdge",
                  @(NSMinYEdge):@"NSMinYEdge",
                  @(NSMaxXEdge):@"NSMaxXEdge",
                  @(NSMaxYEdge):@"NSMaxYEdge"
                  })
          );


ENUMTOOBJ(RulerOrientation,
          NSHorizontalRuler,
          NSVerticalRuler
          );


ENUMTOOBJ(ScrollArrowPosition,
          NSScrollerArrowsDefaultSetting,
          NSScrollerArrowsNone
          );


ENUMTOOBJ(ScrollerPart,
          NSScrollerNoPart,
          NSScrollerDecrementPage,
          NSScrollerKnob,
          NSScrollerIncrementPage,
          NSScrollerDecrementLine,
          NSScrollerIncrementLine,
          NSScrollerKnobSlot
          );


ENUMTOOBJ(SegmentSwitchTracking,
          NSSegmentSwitchTrackingSelectOne,
          NSSegmentSwitchTrackingSelectAny,
          NSSegmentSwitchTrackingMomentary
          );


ENUMTOOBJ(SelectionAffinity,
          NSSelectionAffinityUpstream,
          NSSelectionAffinityDownstream
          );


ENUMTOOBJ(SelectionDirection,
          NSDirectSelection,
          NSSelectingNext,
          NSSelectingPrevious
          );


ENUMTOOBJ(SelectionGranularity,
          NSSelectByCharacter,
          NSSelectByWord,
          NSSelectByParagraph
          );


ENUMTOOBJ(TableViewSelectionHighlightStyle,
          NSTableViewSelectionHighlightStyleRegular,
          NSTableViewSelectionHighlightStyleSourceList
          );


ENUMTOOBJ(SliderType,
          NSLinearSlider,
          NSCircularSlider
          );


ENUMTOOBJ(StatusItemLength,
          NSVariableStatusItemLength,
          NSSquareStatusItemLength
          );

ENUMTOOBJ(StringEncoding,
          NSASCIIStringEncoding,
          NSNEXTSTEPStringEncoding,
          NSJapaneseEUCStringEncoding,
          NSUTF8StringEncoding,
          NSISOLatin1StringEncoding,
          NSSymbolStringEncoding,
          NSNonLossyASCIIStringEncoding,
          NSShiftJISStringEncoding,
          NSISOLatin2StringEncoding,
          NSUnicodeStringEncoding,
          NSWindowsCP1251StringEncoding,
          NSWindowsCP1252StringEncoding,
          NSWindowsCP1253StringEncoding,
          NSWindowsCP1254StringEncoding,
          NSWindowsCP1250StringEncoding,
          NSISO2022JPStringEncoding,
          NSMacOSRomanStringEncoding
          );


OPTSTOOBJ(TableColumnResizingOptions,
          NSTableColumnNoResizing,
          NSTableColumnAutoresizingMask,
          NSTableColumnUserResizingMask
          );

ENUMTOOBJ(TableViewColumnAutoresizingStyle,
          NSTableViewNoColumnAutoresizing,
          NSTableViewUniformColumnAutoresizingStyle,
          NSTableViewSequentialColumnAutoresizingStyle,
          NSTableViewReverseSequentialColumnAutoresizingStyle,
          NSTableViewLastColumnOnlyAutoresizingStyle,
          NSTableViewFirstColumnOnlyAutoresizingStyle
          );



ENUMTOOBJ(TabState,
          NSBackgroundTab,
          NSPressedTab,
          NSSelectedTab
          );


ENUMTOOBJ(TabViewType,
          NSTopTabsBezelBorder,
          NSLeftTabsBezelBorder,
          NSBottomTabsBezelBorder,
          NSRightTabsBezelBorder,
          NSNoTabsBezelBorder,
          NSNoTabsLineBorder,
          NSNoTabsNoBorder
          );


ENUMTOOBJ(TextAlignment,
          NSLeftTextAlignment,
          NSRightTextAlignment,
          NSCenterTextAlignment,
          NSJustifiedTextAlignment,
          NSNaturalTextAlignment
          );


ENUMTOOBJ(TextBlockValueType,
          NSTextBlockAbsoluteValueType,
          NSTextBlockPercentageValueType
          );


ENUMTOOBJ(TextBlockVerticalAlignment,
          NSTextBlockTopAlignment,
          NSTextBlockMiddleAlignment,
          NSTextBlockBottomAlignment,
          NSTextBlockBaselineAlignment
          );


ENUMTOOBJ(TextFieldBezelStyle,
          NSTextFieldSquareBezel,
          NSTextFieldRoundedBezel
          );

OPTSTOOBJ(TextListOptions,
          NSTextListPrependEnclosingMarker
          );


OPTSTOOBJ(TextStorageEditedOptions,
          NSTextStorageEditedAttributes,
          NSTextStorageEditedCharacters
          );

ENUMTOOBJ(TextTableLayoutAlgorithm,
          NSTextTableAutomaticLayoutAlgorithm,
          NSTextTableFixedLayoutAlgorithm
          );


ENUMTOOBJ(TextTabType,
          NSLeftTabStopType,
          NSRightTabStopType,
          NSCenterTabStopType,
          NSDecimalTabStopType
          );


id objectFromTickMarkPosition(NSTickMarkPosition tickMarkPosition, BOOL isVertical)
{
  switch (tickMarkPosition)
  {
    case NSTickMarkBelow: return [FSNamedNumber namedNumberWithDouble:tickMarkPosition name: isVertical ? @"NSTickMarkRight" : @"NSTickMarkBelow"];
    case NSTickMarkAbove: return [FSNamedNumber namedNumberWithDouble:tickMarkPosition name: isVertical ? @"NSTickMarkLeft"  : @"NSTickMarkAbove"];
      //case NSTickMarkLeft:  return [NamedNumber namedNumberWithDouble:tickMarkPosition name:@"NSTickMarkLeft"];
      //case NSTickMarkRight: return [NamedNumber namedNumberWithDouble:tickMarkPosition name:@"NSTickMarkRight"];
    default:              return [FSNumber numberWithDouble:tickMarkPosition];
  }
}

ENUMTOOBJ(TIFFCompression,
          NSTIFFCompressionNone,
          NSTIFFCompressionCCITTFAX3,
          NSTIFFCompressionCCITTFAX4,
          NSTIFFCompressionLZW,
          NSTIFFCompressionJPEG,
          NSTIFFCompressionNEXT,
          NSTIFFCompressionPackBits,
          NSTIFFCompressionOldJPEG
          );


ENUMTOOBJ(TitlePosition,
          NSNoTitle,
          NSAboveTop,
          NSAtTop,
          NSBelowTop,
          NSAboveBottom,
          NSAtBottom,
          NSBelowBottom
          );


ENUMTOOBJ(TokenStyle,
          NSDefaultTokenStyle,
          NSPlainTextTokenStyle,
          NSRoundedTokenStyle
          );


ENUMTOOBJ(ToolbarDisplayMode,
          NSToolbarDisplayModeDefault,
          NSToolbarDisplayModeIconAndLabel,
          NSToolbarDisplayModeIconOnly,
          NSToolbarDisplayModeLabelOnly
          );

ENUMTOOBJ(ToolbarItemVisibilityPriority,
          NSToolbarItemVisibilityPriorityStandard,
          NSToolbarItemVisibilityPriorityLow,
          NSToolbarItemVisibilityPriorityHigh,
          NSToolbarItemVisibilityPriorityUser
          );


ENUMTOOBJ(ToolbarSizeMode,
          NSToolbarSizeModeDefault,
          NSToolbarSizeModeRegular,
          NSToolbarSizeModeSmall
          );


OPTSTOOBJ(TrackingAreaOptions,
          NSTrackingMouseEnteredAndExited,
          NSTrackingMouseMoved,
          NSTrackingCursorUpdate,
          NSTrackingActiveWhenFirstResponder,
          NSTrackingActiveInKeyWindow,
          NSTrackingActiveInActiveApp,
          NSTrackingActiveAlways,
          NSTrackingAssumeInside,
          NSTrackingInVisibleRect,
          NSTrackingEnabledDuringMouseDrag
          );


ENUMTOOBJ(TypesetterBehavior,
          NSTypesetterLatestBehavior,
          NSTypesetterOriginalBehavior,
          NSTypesetterBehavior_10_2_WithCompatibility,
          NSTypesetterBehavior_10_2,
          NSTypesetterBehavior_10_3,
          NSTypesetterBehavior_10_4
          );


ENUMTOOBJ(UsableScrollerParts,
          NSNoScrollerParts,
          NSOnlyScrollerArrows,
          NSAllScrollerParts
          );


ENUMTOOBJ(WindingRule,
          NSNonZeroWindingRule,
          NSEvenOddWindingRule
          );

ENUMTOOBJ_DICT(WindowLevel,
          (@{@(NSNormalWindowLevel):@"NSNormalWindowLevel",
             @(NSFloatingWindowLevel):@"NSFloatingWindowLevel",
             @(NSSubmenuWindowLevel):@"NSSubmenuWindowLevel",
             @(NSTornOffMenuWindowLevel):@"NSTornOffMenuWindowLevel",
             @(NSMainMenuWindowLevel):@"NSMainMenuWindowLevel",
             @(NSStatusWindowLevel):@"NSStatusWindowLevel",
             @(NSDockWindowLevel):@"NSDockWindowLevel",
             @(NSModalPanelWindowLevel):@"NSModalPanelWindowLevel",
             @(NSPopUpMenuWindowLevel):@"NSPopUpMenuWindowLevel",
             @(NSScreenSaverWindowLevel):@"NSScreenSaverWindowLevel"})
          );


OPTSTOOBJ(WindowMask,
          NSBorderlessWindowMask,
          NSTitledWindowMask,
          NSClosableWindowMask,
          NSMiniaturizableWindowMask,
          NSResizableWindowMask,
          NSTexturedBackgroundWindowMask,
          NSUnifiedTitleAndToolbarWindowMask,
          NSFullScreenWindowMask,
          NSFullSizeContentViewWindowMask
          );

ENUMTOOBJ(WindowBackingLocation,
          NSWindowBackingLocationDefault,
          NSWindowBackingLocationVideoMemory,
          NSWindowBackingLocationMainMemory
          );


ENUMTOOBJ(WindowCollectionBehavior,
          NSWindowCollectionBehaviorDefault,
          NSWindowCollectionBehaviorCanJoinAllSpaces,
          NSWindowCollectionBehaviorMoveToActiveSpace
          );


ENUMTOOBJ(WindowSharingType,
          NSWindowSharingNone,
          NSWindowSharingReadOnly,
          NSWindowSharingReadWrite
          );


/*static id objectFromWindowOrderingMode(NSWindowOrderingMode orderingMode)
 {
 switch (orderingMode)
 {
 case NSWindowAbove: return [NamedNumber namedNumberWithDouble:orderingMode name:@"NSWindowAbove"];
 case NSWindowBelow: return [NamedNumber namedNumberWithDouble:orderingMode name:@"NSWindowBelow"];
 case NSWindowOut:   return [NamedNumber namedNumberWithDouble:orderingMode name:@"NSWindowOut"];
 default:            return [Number numberWithDouble:orderingMode];
 }
 }*/

ENUMTOOBJ(WritingDirection,
          NSWritingDirectionNatural,
          NSWritingDirectionLeftToRight,
          NSWritingDirectionRightToLeft
          );

@end
