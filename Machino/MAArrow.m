#import "Graph.h"
#import "MANodeInternal.h"
#import "Utility.h"

static NSString * const kCoderConditionNameKey = @"name";
static NSString * const kCoderActionNameKey = @"name";
static NSString * const kCoderSourceKey = @"source";
static NSString * const kCoderTargetKey = @"target";
static NSString * const kCoderSourcePointKey = @"sourcePoint";
static NSString * const kCoderTargetPointKey = @"targetPoint";
static NSString * const kCoderSourceAngleKey = @"sourceAngle";
static NSString * const kCoderTargetAngleKey = @"targetAngle";
static NSString * const kCoderConditionKey = @"condition";
static NSString * const kCoderActionsKey = @"actions";

#pragma mark - MACondition

@implementation MACondition

+ (id)conditionWithName:(NSString *)name
{
	MACondition *condition = [[self alloc] init];
	condition->_name = [name copy];
	return condition;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _name = [coder decodeObjectForKey:kCoderConditionNameKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.name forKey:kCoderConditionNameKey];
}

- (NSString *)description
{
	return self.name;
}

@end

#pragma mark - MAAction

@implementation MAAction

+ (id)actionWithName:(NSString *)name
{
	MAAction *action = [[self alloc] init];
	action->_name = [name copy];
	return action;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _name = [coder decodeObjectForKey:kCoderActionNameKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.name forKey:kCoderActionNameKey];
}

- (NSString *)description
{
	return self.name;
}

@end

#pragma mark - MAArrow

@implementation MAArrow

- (void)setSourceNode:(MANode *)sourceNode
{
	if (_sourceNode == sourceNode) return;
	[_sourceNode.arrowsMutable removeFirstOccurrenceOfObject:self];
	_sourceNode = sourceNode;
	[sourceNode.arrowsMutable addObject:self];
}

- (void)setTargetNode:(MANode *)targetNode
{
	if (_targetNode == targetNode) return;
	[_targetNode.arrowsMutable removeFirstOccurrenceOfObject:self];
	_targetNode = targetNode;
	[targetNode.arrowsMutable addObject:self];
}

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
		_sourceNode = [coder decodeObjectForKey:kCoderSourceKey];
		_targetNode = [coder decodeObjectForKey:kCoderTargetKey];
		_sourcePoint = [coder decodePointForKey:kCoderSourcePointKey];
		_targetPoint = [coder decodePointForKey:kCoderTargetPointKey];
		_sourceAngle = [coder decodeFloatForKey:kCoderSourceAngleKey];
		_targetAngle = [coder decodeFloatForKey:kCoderTargetAngleKey];
		_condition = [coder decodeObjectForKey:kCoderConditionKey];
		_actions = [coder decodeObjectForKey:kCoderActionsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.sourceNode forKey:kCoderSourceKey];
	[coder encodeObject:self.targetNode forKey:kCoderTargetKey];
	[coder encodePoint:self.sourcePoint forKey:kCoderSourcePointKey];
	[coder encodePoint:self.targetPoint forKey:kCoderTargetPointKey];
	[coder encodeFloat:self.sourceAngle forKey:kCoderSourceAngleKey];
	[coder encodeFloat:self.targetAngle forKey:kCoderTargetAngleKey];
	[coder encodeObject:self.condition forKey:kCoderConditionKey];
	[coder encodeObject:self.actions forKey:kCoderActionsKey];
}

#pragma mark - General

- (MANode *)nodeForEnd:(MAArrowEnd)end
{
	return (end == MAArrowTail) ? self.sourceNode : self.targetNode;
}

- (void)setNode:(MANode *)node forEnd:(MAArrowEnd)end
{
	if (end == MAArrowTail) self.sourceNode = node;
	else self.targetNode = node;
}

- (CGFloat)angleForEnd:(MAArrowEnd)end
{
	return (end == MAArrowTail) ? self.sourceAngle : self.targetAngle;
}

- (void)setAngle:(CGFloat)angle forEnd:(MAArrowEnd)end
{
	if (end == MAArrowTail) self.sourceAngle = angle;
	else self.targetAngle = angle;
}

- (CGPoint)pointForEnd:(MAArrowEnd)end
{
	return (end == MAArrowTail) ? self.sourcePoint : self.targetPoint;
}

- (void)setPoint:(CGPoint)point forEnd:(MAArrowEnd)end
{
	if (end == MAArrowTail) self.sourcePoint = point;
	else self.targetPoint = point;
}

- (NSString *)description
{
	NSString *actionString = [self.actions componentsJoinedByString:@", "];
	return [NSString stringWithFormat:@"%@ -- %@ / %@ --> %@", self.sourceNode, self.condition, actionString, self.targetNode];
}

@end
