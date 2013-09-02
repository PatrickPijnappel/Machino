//
// Copyright (c) 2013, Patrick Pijnappel (contact@patrickpijnappel.com)
//
// Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted,
// provided that the above copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
// CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#import <Cocoa/Cocoa.h>

@protocol MAGraphViewDelegate;
@class MANode;
@class MAArrow;
@class MACondition;

#pragma mark - Constants

extern NSString * const MAGraphMouseEventNodeKey;
extern NSString * const MAGraphMouseEventArrowKey;
extern NSString * const MAGraphMouseEventConditionKey;
extern NSString * const MAGraphMouseEventActionIndexKey;

#pragma mark - Public Interface

@interface MAGraphView : NSView

@property (nonatomic, weak) IBOutlet id<MAGraphViewDelegate> delegate;
// Active
@property (nonatomic, copy, readonly) NSArray *activatedNodes;
@property (nonatomic, weak, readonly) MANode *activeNode;
@property (nonatomic, weak, readonly) MAArrow *activeArrow;
@property (nonatomic, weak, readonly) MACondition *activeCondition;
@property (nonatomic, readonly) NSUInteger activeActionIndex;

- (NSArray *)getNodes;
- (NSArray *)getArrows;
- (void)setNodes:(NSMutableArray *)nodes arrows:(NSMutableArray *)arrows;
// Active objects
- (void)clearActiveObjects;
- (void)makeNodeActive:(MANode *)node;
- (void)makeConditionActive:(MACondition *)condition arrow:(MAArrow *)arrow;
- (void)makeActionAtIndexActive:(NSUInteger)index arrow:(MAArrow *)arrow;
// Hovered
- (void)setHoveredItemsToItems:(NSArray *)hoveredItems;

@end

#pragma mark - Delegate

@protocol MAGraphViewDelegate <NSObject>

@optional
- (void)graphDidChangeForGraphView:(MAGraphView *)graphView;
- (void)graphView:(MAGraphView *)graphView mouseHoverEventWithInfo:(NSDictionary *)info;
- (void)graphView:(MAGraphView *)graphView mouseClickEventWithInfo:(NSDictionary *)info;

@end