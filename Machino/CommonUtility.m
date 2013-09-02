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

#import <QuartzCore/QuartzCore.h>
#import "Utility.h"

CGFloat CGPointDistanceToPoint(CGPoint p1, CGPoint p2)
{
	CGFloat dx = p2.x-p1.x;
	CGFloat dy = p2.y-p1.y;
	return sqrt(dx*dx + dy*dy);
}

CGFloat CGPointDistanceToRect(CGPoint p, CGRect rect)
{
	CGPoint closestPoint = CGPointClampToRect(p, rect);
	return CGPointDistanceToPoint(p, closestPoint);
}

CGFloat CGPointAngleToPoint(CGPoint p1, CGPoint p2)
{
	CGFloat dx = p2.x-p1.x;
	CGFloat dy = p2.y-p1.y;
	return atan2(dy, dx);
}

CGPoint CGPointMoveDistanceInAngle(CGPoint p, CGFloat distance, CGFloat angle)
{
	p.x += distance * cos(angle);
	p.y += distance * sin(angle);
	return p;
}

CGPoint CGPointBetweenPoints(CGPoint p1, CGPoint p2)
{
	return NSMakePoint((p1.x+p2.x)/2, (p1.y+p2.y)/2);
}

CGPoint CGPointAddPoint(CGPoint p1, CGPoint p2)
{
	return NSMakePoint(p1.x+p2.x, p1.y+p2.y);
}

CGPoint CGPointSubtractPoint(CGPoint p1, CGPoint p2)
{
	return NSMakePoint(p1.x-p2.x, p1.y-p2.y);
}

CGPoint CGPointRound(CGPoint p)
{
	p.x = round(p.x);
	p.y = round(p.y);
	return p;
}

CGPoint CGPointClampToRect(CGPoint p, CGRect rect)
{
	p.x = clamp(p.x, CGRectGetMinX(rect), CGRectGetMaxX(rect));
	p.y = clamp(p.y, CGRectGetMinY(rect), CGRectGetMaxY(rect));
	return p;
}

CGRect CGRectBetweenPoints(CGPoint p1, CGPoint p2)
{
	CGFloat x = MIN(p1.x, p2.x);
	CGFloat y = MIN(p1.y, p2.y);
	CGFloat width = ABS(p2.x - p1.x);
	CGFloat height = ABS(p2.y - p1.y);
	return CGRectMake(x, y, width, height);
}

CGRect CGRectExpand(CGRect rect, CGFloat amount)
{
	rect.origin.x -= amount;
	rect.origin.y -= amount;
	rect.size.width += 2*amount;
	rect.size.height += 2*amount;
	return rect;
}

CGRect CGRectAroundPoint(CGPoint point, CGSize size)
{
	CGFloat x = point.x - size.width/2;
	CGFloat y = point.y - size.height/2;
	return CGRectMake(x, y, size.width, size.height);
}

CGRect CGRectAddSizeWithAnchorPoint(CGRect rect, CGSize size, CGPoint anchorPoint)
{
	rect.origin.x -= size.width * anchorPoint.x;
	rect.origin.y -= size.height * anchorPoint.y;
	rect.size.width += size.width;
	rect.size.height += size.height;
	return rect;
}

CGRect CGRectSetSizeWithAnchorPoint(CGRect rect, CGSize size, CGPoint anchorPoint)
{
	CGSize delta = CGSizeMake(size.width-rect.size.width, size.height-rect.size.height);
	return CGRectAddSizeWithAnchorPoint(rect, delta, anchorPoint);
}

CGSize CGSizeMakeUniform(CGFloat size)
{
	return CGSizeMake(size, size);
}

CGSize CGSizeAddSize(CGSize s1, CGSize s2)
{
	return NSMakeSize(s1.width+s2.width, s1.height+s2.height);
}

CGSize CGSizeAdd(CGSize size, CGFloat amount)
{
	size.width += amount;
	size.height += amount;
	return size;
}

BOOL NSRangeContainsValue(NSRange range, CGFloat value)
{
	return (value >= range.location && value <= range.location + range.length);
}

BOOL NSRangeContainsRange(NSRange range1, NSRange range2)
{
	return (range2.location >= range1.location && (range2.location+range2.length <= range1.location+range1.length));
}

BOOL NSRangeIntersectsRange(NSRange range1, NSRange range2)
{
	return (range1.location < range2.location+range2.length && range2.location < range1.location+range1.length);
}

NSRange NSRangeIntersection(NSRange range1, NSRange range2)
{
	NSUInteger location = MAX(range1.location, range2.location);
	NSInteger endLocation = MIN(range1.location+range1.length, range2.location+range2.length);
	if (endLocation < location) NSMakeRange(NSNotFound, 0);
	return NSMakeRange(location, endLocation-location);
}

CGFloat clamp(CGFloat value, CGFloat min, CGFloat max)
{
	if (value < min) return min;
	if (value > max) return max;
	return value;
}

CGPoint CGPointOnBezier(CGFloat t, CGPoint a, CGPoint b, CGPoint c, CGPoint d)
{
	CGPoint p;
	p.x = bezierInterpolation(t, a.x, b.x, c.x, d.x);
	p.y = bezierInterpolation(t, a.y, b.y, c.y, d.y);
	return p;
}

// See http://stackoverflow.com/questions/4058979
CGFloat bezierInterpolation(CGFloat t, CGFloat a, CGFloat b, CGFloat c, CGFloat d) {
    CGFloat t2 = t * t;
    CGFloat t3 = t2 * t;
    return a + (-a * 3 + t * (3 * a - a * t)) * t
	+ (3 * b + t * (-6 * b + b * 3 * t)) * t
	+ (c * 3 - c * 3 * t) * t2
	+ d * t3;
}

NSString *CAAlignmentModeFromNSTextAlignment(NSTextAlignment alignment)
{
	switch (alignment) {
		case NSLeftTextAlignment: return kCAAlignmentLeft;
		case NSRightTextAlignment: return kCAAlignmentRight;
		case NSCenterTextAlignment: return kCAAlignmentCenter;
		case NSJustifiedTextAlignment: return kCAAlignmentJustified;
		case NSNaturalTextAlignment: return kCAAlignmentNatural;
	}
	return nil;
}

NSTextAlignment NSTextAlignmentFromCAAlignmentMode(NSString *alignment)
{
	if (alignment == kCAAlignmentLeft) return NSLeftTextAlignment;
	if (alignment == kCAAlignmentRight) return NSRightTextAlignment;
	if (alignment == kCAAlignmentCenter) return NSCenterTextAlignment;
	if (alignment == kCAAlignmentJustified) return NSJustifiedTextAlignment;
	if (alignment == kCAAlignmentNatural) return NSNaturalTextAlignment;
	return NSNotFound;
}
