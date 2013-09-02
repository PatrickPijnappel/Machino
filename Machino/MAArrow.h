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

@class CATextLayer;
@class CAShapeLayer;
@class MANode;

typedef NS_ENUM(NSUInteger, MAArrowEnd) {
	MAArrowTail,
	MAArrowHead
};

#pragma mark - MACondition

@interface MACondition : NSObject <NSCoding>

@property (nonatomic, copy, readonly) NSString *name;

+ (id)conditionWithName:(NSString *)name;

@end

#pragma mark - MAAction

@interface MAAction : NSObject <NSCoding>

@property (nonatomic, copy, readonly) NSString *name;

+ (id)actionWithName:(NSString *)name;

@end

#pragma mark - MAArrow

@interface MAArrow : NSObject <NSCoding>

@property (nonatomic, weak) MANode *sourceNode;
@property (nonatomic, weak) MANode *targetNode;
@property (nonatomic) CGPoint sourcePoint;
@property (nonatomic) CGPoint targetPoint;
@property (nonatomic) CGFloat sourceAngle;
@property (nonatomic) CGFloat targetAngle;
@property (nonatomic) CGPoint midPoint;
@property (nonatomic, strong) MACondition *condition;
@property (nonatomic, copy) NSArray *actions;
// Layers
@property (nonatomic, strong) CAShapeLayer *layer;
@property (nonatomic, strong) CAShapeLayer *tailLayer;
@property (nonatomic, strong) CAShapeLayer *headLayer;
@property (nonatomic, strong) CALayer *textLayer;
@property (nonatomic, strong) CATextLayer *conditionLayer;
@property (nonatomic, strong) CATextLayer *slashLayer;
@property (nonatomic, strong) CATextLayer *actionsLayer;

- (MANode *)nodeForEnd:(MAArrowEnd)end;
- (void)setNode:(MANode *)node forEnd:(MAArrowEnd)end;
- (CGFloat)angleForEnd:(MAArrowEnd)end;
- (void)setAngle:(CGFloat)angle forEnd:(MAArrowEnd)end;
- (CGPoint)pointForEnd:(MAArrowEnd)end;
- (void)setPoint:(CGPoint)point forEnd:(MAArrowEnd)end;

@end
