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

#import <AppKit/AppKit.h>

CGFloat CGPointDistanceToPoint(CGPoint p1, CGPoint p2);
CGFloat CGPointDistanceToRect(CGPoint p, CGRect rect);
CGFloat CGPointAngleToPoint(CGPoint p1, CGPoint p2);
CGPoint CGPointMoveDistanceInAngle(CGPoint p, CGFloat distance, CGFloat angle);
CGPoint CGPointBetweenPoints(CGPoint p1, CGPoint p2);
CGPoint CGPointAddPoint(CGPoint p1, CGPoint p2);
CGPoint CGPointSubtractPoint(CGPoint p1, CGPoint p2);
CGPoint CGPointRound(CGPoint p);
CGPoint CGPointClampToRect(CGPoint p, CGRect rect);

CGRect CGRectBetweenPoints(CGPoint p1, CGPoint p2);
CGRect CGRectExpand(CGRect rect, CGFloat amount);
CGRect CGRectAroundPoint(CGPoint point, CGSize size);
CGRect CGRectAddSizeWithAnchorPoint(CGRect rect, CGSize size, CGPoint anchorPoint);
CGRect CGRectSetSizeWithAnchorPoint(CGRect rect, CGSize size, CGPoint anchorPoint);

CGSize CGSizeMakeUniform(CGFloat size);
CGSize CGSizeAddSize(CGSize s1, CGSize s2);
CGSize CGSizeAdd(CGSize size, CGFloat amount);

BOOL NSRangeContainsValue(NSRange range, CGFloat value);
BOOL NSRangeContainsRange(NSRange range1, NSRange range2);
BOOL NSRangeIntersectsRange(NSRange range1, NSRange range2);
NSRange NSRangeIntersection(NSRange range1, NSRange range2);

CGFloat clamp(CGFloat value, CGFloat min, CGFloat max);
CGPoint CGPointOnBezier(CGFloat t, CGPoint a, CGPoint b, CGPoint c, CGPoint d);
CGFloat bezierInterpolation(CGFloat t, CGFloat a, CGFloat b, CGFloat c, CGFloat d);

NSString *CAAlignmentModeFromNSTextAlignment(NSTextAlignment alignment);
NSTextAlignment NSTextAlignmentFromCAAlignmentMode(NSString *alignment);