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

@protocol MANavigationControllerDelegate;

@interface MANavigationController : NSObject

@property (nonatomic, weak) IBOutlet id<MANavigationControllerDelegate> delegate;
@property (nonatomic, weak) IBOutlet NSView *contentView;
@property (nonatomic, copy, readonly) NSArray *viewControllers;
@property (nonatomic, strong, readonly) NSViewController *topViewController;
@property (nonatomic, strong, readonly) NSViewController *rootViewController;

- (void)pushViewController:(NSViewController *)viewController animated:(BOOL)animated;
- (void)popViewControllerAnimated:(BOOL)animated;
- (void)popToViewController:(NSViewController *)viewController animated:(BOOL)animated;
- (void)popToRootViewControllerAnimated:(BOOL)animated;

@end

@protocol MANavigationControllerDelegate <NSObject>

@optional
- (NSArray *)toolbarItemIdentifiersForViewController:(NSViewController *)viewController;

@end
