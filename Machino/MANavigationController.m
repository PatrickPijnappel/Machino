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
#import "MANavigationController.h"

@interface MANavigationController () <NSToolbarDelegate>

@property (nonatomic, strong, readonly) NSMutableArray *viewControllersMutable;

@end

@implementation MANavigationController

- (NSViewController *)topViewController
{
	return [self.viewControllersMutable lastObject];
}

- (NSViewController *)rootViewController
{
	if ([self.viewControllersMutable count] == 0) return nil;
	return [self.viewControllersMutable objectAtIndex:0];
}

- (NSArray *)viewControllers
{
	return [self.viewControllersMutable copy];
}

- (void)setContetView:(NSView *)contentView
{
	if (_contentView == contentView) return;
	NSView *oldView = _contentView;
	_contentView = contentView;
	[self handleContentViewChangedFromView:oldView toView:contentView];
}

- (id)init
{
	self = [super init];
    if (self) {
        self->_viewControllersMutable = [NSMutableArray array];
    }
    return self;
}

- (void)awakeFromNib
{
	[self handleContentViewChangedFromView:nil toView:self.contentView];
}

- (void)handleContentViewChangedFromView:(NSView *)oldView toView:(NSView *)view;
{
	// Make it have a layer
	[view setWantsLayer:YES];
	// Place current view controller
	NSViewController *viewController = self.topViewController;
	if (viewController) {
		[self placeViewControllerView:[viewController view]];
	}
}

#pragma mark - Transitions

- (void)pushViewController:(NSViewController *)viewController animated:(BOOL)animated
{
	[self transitionToViewController:viewController animated:animated];
}

- (void)popViewControllerAnimated:(BOOL)animated
{
	NSUInteger count = [self.viewControllersMutable count];
	if (count >= 2) {
		NSViewController *viewController = [self.viewControllersMutable objectAtIndex:count-2];
		[self transitionToViewController:viewController animated:animated];
	}
}

- (void)popToRootViewControllerAnimated:(BOOL)animated
{
	if (self.rootViewController) {
		[self transitionToViewController:self.rootViewController animated:animated];
	}
}

- (void)popToViewController:(NSViewController *)viewController animated:(BOOL)animated
{
	if (![self.viewControllersMutable containsObject:viewController]) return;
	[self transitionToViewController:viewController animated:animated];
}

- (void)transitionToViewController:(NSViewController *)viewController animated:(BOOL)animated
{
	NSViewController *sourceViewController = self.topViewController;
	if (viewController == sourceViewController) return;
	// Add viewController if it is new, otherwise remove old
	if (![self.viewControllersMutable containsObject:viewController]) {
		[self.viewControllersMutable addObject:viewController];
	} else if (sourceViewController) {
		[self.viewControllersMutable removeObject:sourceViewController];
	}
	// Get view controller indices
	NSUInteger sourceIndex = [self.viewControllersMutable indexOfObject:sourceViewController];
	NSUInteger targetIndex = [self.viewControllersMutable indexOfObject:viewController];
	// Create transition
	CATransition *transition = [CATransition animation];
	transition.startProgress = 0;
	transition.endProgress = 1.0;
	transition.type = kCATransitionPush;
	transition.subtype = (targetIndex < sourceIndex) ? kCATransitionFromLeft : kCATransitionFromRight;
	transition.duration = .25;
	// Update
	if (animated) {
		[self replaceViewControllerView:[sourceViewController view] withView:[viewController view] transition:transition];
	} else {
		[self placeViewControllerView:[viewController view]];
	}
}

#pragma mark - View Controllers

- (void)placeViewControllerView:(NSView *)view
{
	[view removeFromSuperview];
	[self.contentView addSubview:view];
	[view setFrame:[self.contentView bounds]];
	[view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

- (void)replaceViewControllerView:(NSView *)oldView withView:(NSView *)newView transition:(CATransition *)transition
{
	// Initial state
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	[newView setHidden:YES];
	[CATransaction commit];
	// Update
	[self placeViewControllerView:newView];
	// Apply transition
	[[oldView layer] addAnimation:transition forKey:@"transition"];
	[[newView layer] addAnimation:transition forKey:@"transition"];
	// Set new state
	[oldView setHidden:YES];
	[newView setHidden:NO];
}

@end
