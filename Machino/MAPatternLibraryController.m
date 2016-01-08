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
#import "MAPatternLibraryController.h"
#import "MAPatternLibraryLoader.h"
#import "MAPatternGroup.h"
#import "MAPattern.h"
#import "MANavigationController.h"
#import "MAPatternTableViewController.h"

//static const int MASearchToolbarSideSpace = 16; 
static NSString * const MAToolbarSearchItemIdentifier = @"MAToolbarSearchItemIdentifier";
static NSString * const MAToolbarTitleItemIdentifier = @"MAToolbarTitleItemIdentifier";
static NSString * const MAToolbarBackItemIdentifier = @"MAToolbarBackItemIdentifier";
static NSString * const MAToolbarPlaceholderItemIdentifier = @"MAToolbarPlaceholderItemIdentifier";
static NSString * const MAToolbarCustomSpaceItemIdentifier = @"MAToolbarCustomSpaceItemIdentifier";

typedef NS_ENUM(NSInteger, MAToolbarMode) {
	MASearchToolbar = 0,
	MANavigationToolbar
};

@interface MAPatternLibraryController ()

@property (nonatomic, copy) NSArray *items;
@property (nonatomic, weak) IBOutlet NSPanel *panel;
@property (nonatomic, weak) IBOutlet MANavigationController *navigationController;

@end

@implementation MAPatternLibraryController

- (IBAction)togglePanel:(id)sender
{
	if (![self.panel isVisible]) {
		NSWindowController *windowController = [[NSWindowController alloc] initWithWindow:self.panel];
		[self loadLibrary];
		MAPatternTableViewController *viewController = [[MAPatternTableViewController alloc] initWithNibName:@"MAPatternTableView" bundle:nil];
		viewController.navigationController = self.navigationController;
		viewController.items = self.items;
		[self.navigationController pushViewController:viewController animated:NO];
		[windowController showWindow:self];
	} else {
		[self.panel orderOut:self];
	}
}

- (IBAction)navigateBack:(id)sender
{
//	if (self.toolbarMode == MANavigationToolbar) {
//		[self setSearchToolbar];
//	}
}

- (void)loadLibrary
{
	MAPatternLibraryLoader *loader = [[MAPatternLibraryLoader alloc] init];
	self.items = [loader loadLibrary];
}

#pragma mark - Toolbar

//- (void)setSearchToolbar
//{
//	if (self.toolbarMode != MASearchToolbar) {
//		// Create snapshot imageView
//		NSImage *image = [self takeToolbarSnapshot];
//		NSImageView *imageView = [[NSImageView alloc] init];
//		[imageView setImage:image];
//		[[self.panel contentView] addSubview:imageView];
//		[imageView setFrame:[self.toolbarView frame]];
//		[imageView setWantsLayer:YES];
//
//		// Set items
//		[self setToolbarItems:@[ MAToolbarCustomSpaceItemIdentifier, MAToolbarSearchItemIdentifier, MAToolbarCustomSpaceItemIdentifier ]];
//		// Adjust items
//		[self setCustomSpaceAtIndex:0 toWidth:MASearchToolbarSideSpace];
//		[self setCustomSpaceAtIndex:2 toWidth:MASearchToolbarSideSpace*2];
//		// Update mode
//		self.toolbarMode = MASearchToolbar;
//
//		[CATransaction begin];
//		[CATransaction setDisableActions:YES];
//		[self.toolbarView setHidden:YES];
//		[CATransaction commit];
//
//		CATransition* transition = [CATransition animation];
//		transition.startProgress = 0;
//		transition.endProgress = 1.0;
//		transition.type = kCATransitionPush;
//		transition.subtype = kCATransitionFromLeft;
//		
//		// Add the transition animation to both layers
//		[[self.toolbarView layer] addAnimation:transition forKey:@"transition"];
//		[[imageView layer] addAnimation:transition forKey:@"transition"];
//
//		[self.toolbarView setHidden:NO];
//		[imageView setHidden:YES];
//	}
//}
//
//- (NSImage *)takeToolbarSnapshot
//{
//	CGRect bounds = [self.toolbarView bounds];
//	[self.toolbarView lockFocus];
//	NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:bounds];
//	[self.toolbarView unlockFocus];
//	[self.toolbarView cacheDisplayInRect:bounds toBitmapImageRep:imageRep];
//	return [[NSImage alloc] initWithCGImage:[imageRep CGImage] size:bounds.size];
//}
//
//- (void)setNavigationToolbarWithTitle:(NSString *)title
//{
//	[self.titleLabel setStringValue:title];
//	if (self.toolbarMode != MANavigationToolbar) {
//		// Set items
//		[self setToolbarItems:@[ MAToolbarBackItemIdentifier, MAToolbarTitleItemIdentifier, NSToolbarSpaceItemIdentifier ]];
//		// Adjust items
//		CGFloat backItemWidth = [self.backButton bounds].size.width;
//		[self setCustomSpaceAtIndex:2 toWidth:backItemWidth];
//		// Update mode
//		self.toolbarMode = MANavigationToolbar;
//	}
//}
//
//- (void)setCustomSpaceAtIndex:(NSUInteger)index toWidth:(CGFloat)width
//{
//	NSToolbarItem *item = [self.toolbar items][index];
//	[item setMaxSize:NSMakeSize(width, 0)];
//	[[item view] setBoundsSize:NSMakeSize(width, 0)];
//}
//
//- (void)setToolbarItems:(NSArray *)identifiers
//{
//	// Clear all except placeholder
//	NSUInteger numberOfItems = [[self.toolbar items] count];
//	[self.toolbar insertItemWithItemIdentifier:MAToolbarPlaceholderItemIdentifier atIndex:0];
//	for (int i=0; i<numberOfItems; i++) {
//		[self.toolbar removeItemAtIndex:1];
//	}
//	// Add items
//	int i = 1;
//	for (NSString *identifier in identifiers) {
//		[self.toolbar insertItemWithItemIdentifier:identifier atIndex:i];
//		i++;
//	}
//	// Remove placeholder
//	[self.toolbar removeItemAtIndex:0];
//}

@end
