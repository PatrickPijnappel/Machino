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

#import "MAPatternViewController.h"
#import "MANavigationController.h"
#import "MAPattern.h"

@interface MAPatternViewController ()

@property (nonatomic, assign) IBOutlet NSTextView *textView;
@property (nonatomic, weak) IBOutlet NSButton *backButton;
@property (nonatomic, weak) IBOutlet NSTextField *titleLabel;

@end

@implementation MAPatternViewController

- (void)setPattern:(MAPattern *)pattern
{
	if (_pattern == pattern) return;
	_pattern = pattern;
	[self updatePattern];
}

#pragma mark - Initialization

- (void)awakeFromNib
{
	// Text view properties
	[self.textView setTextContainerInset:NSMakeSize(6, 10)];
	[self.textView setEnabledTextCheckingTypes:0];
}

#pragma mark - Navigation

- (void)updatePattern
{
	// Set title
	NSString *title = self.pattern.name;
	if (!title) title = @"";
	[self.titleLabel setStringValue:title];
	// Set text
	NSAttributedString *text = self.pattern.text;
	[[self.textView textStorage] setAttributedString:text ? text : [[NSAttributedString alloc] init]];
	// Scroll
	[self.textView scrollToBeginningOfDocument:self];
}

- (IBAction)navigateBack:(id)sender
{
	[self.navigationController popViewControllerAnimated:YES];
}

@end
