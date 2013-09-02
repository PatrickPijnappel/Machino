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

#import "MAPatternTableViewController.h"
#import "MAPatternViewController.h"
#import "MAPatternTableRowView.h"
#import "MANavigationController.h"
#import "MAPatternGroup.h"
#import "MAPattern.h"

static NSString * const MAPatternTableRowIdentifier = @"PatternTableRow";

@interface MAPatternTableViewController () <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>

@property (nonatomic, strong) NSMutableArray *shownItems;
@property (nonatomic, readonly) BOOL isRootViewController;
@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, weak) IBOutlet NSButton *backButton;
@property (nonatomic, weak) IBOutlet NSTextField *titleLabel;
@property (nonatomic, weak) IBOutlet NSSearchField *searchField;

@end

@implementation MAPatternTableViewController

- (BOOL)isRootViewController
{
	return (!self.navigationController || self.navigationController.rootViewController == self);
}

- (void)setNavigationController:(MANavigationController *)navigationController
{
	if (_navigationController == navigationController) return;
	_navigationController = navigationController;
	[self updateNavigationBar];
}

- (void)setItems:(NSArray *)items
{
	if (_items == items) return;
	_items = [items copy];
	[self updateShownItems];
}

- (void)setParentItem:(MAPatternGroup *)parentItem
{
	if (_parentItem == parentItem) return;
	_parentItem = parentItem;
	[self updateTitle];
}

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		self->_shownItems = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Views

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [self.shownItems count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	MAPatternTableRowView *view = [tableView makeViewWithIdentifier:MAPatternTableRowIdentifier owner:self];
	// Fill depending on item type
	id item = self.shownItems[row];
	if ([item isKindOfClass:[MAPatternGroup class]]) {
		MAPatternGroup *group = item;
		[view.title setStringValue:group.name];
		NSUInteger patternCount = [group.children count];
		NSString *detail = (patternCount != 1) ? [NSString stringWithFormat:@"%i patterns", (int)patternCount] : @"1 pattern";
		[view.detail setStringValue:detail];
		[view.arrow setHidden:NO];
	} else if ([item isKindOfClass:[MAPattern class]]) {
		MAPattern *pattern = item;
		[view.title setStringValue:pattern.name];
		[view.detail setStringValue:pattern.teaser];
		[view.arrow setHidden:YES];
	}
	return view;
}

#pragma mark - Navigation

- (void)updateNavigationBar
{
	BOOL isRoot = self.isRootViewController;
	[self.searchField setHidden:!isRoot];
	[self.backButton setHidden:isRoot];
	[self.titleLabel setHidden:isRoot];
	[self updateTitle];
}

- (void)updateTitle
{
	if (!self.isRootViewController) {
		NSString *title = self.parentItem.name;
		if (!title) title = @"";
		[self.titleLabel setStringValue:title];
	}
}

- (IBAction)navigateBack:(id)sender
{
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger row = [self.tableView selectedRow];
	if (row == -1) return;
	id item = self.shownItems[row];
	if ([item isKindOfClass:[MAPatternGroup class]]) {
		MAPatternGroup *group = item;
		MAPatternTableViewController *viewController = [[MAPatternTableViewController alloc] init];
		NSArray *objects;
		[[NSBundle mainBundle] loadNibNamed:@"MAPatternTableView" owner:viewController topLevelObjects:&objects];
		viewController.navigationController = self.navigationController;
		viewController.parentItem = group;
		viewController.items = group.children;
		[self.navigationController pushViewController:viewController animated:YES];
	} else if ([item isKindOfClass:[MAPattern class]]) {
		MAPattern *pattern = item;
		MAPatternViewController *viewController = [[MAPatternViewController alloc] init];
		NSArray *objects;
		[[NSBundle mainBundle] loadNibNamed:@"MAPatternView" owner:viewController topLevelObjects:&objects];
		viewController.navigationController = self.navigationController;
		viewController.pattern = pattern;
		[self.navigationController pushViewController:viewController animated:YES];
	}
	[self.tableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
}

#pragma mark - Search

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self updateShownItems];
}

- (void)updateShownItems
{
	NSString *text = [self.searchField stringValue];
	NSString *textTrimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([textTrimmed length] > 0) {
		[self.shownItems removeAllObjects];
		[self addItemsInArray:self.items matchingSearchString:textTrimmed toArray:self.shownItems];
	} else {
		[self.shownItems setArray:self.items];
	}
	[self.tableView reloadData];
}

- (void)addItemsInArray:(NSArray *)items matchingSearchString:(NSString *)searchString toArray:(NSMutableArray *)matches
{
	for (id item in items) {
		BOOL isMatch = [self isItem:item matchForSearchString:searchString];
		if (isMatch) [matches addObject:item];
		if ([item isKindOfClass:[MAPatternGroup class]]) {
			MAPatternGroup *group = item;
			[self addItemsInArray:group.children matchingSearchString:searchString toArray:matches];
		}
	}
}

- (BOOL)isItem:(id)item matchForSearchString:(NSString *)searchString
{
	NSArray *searchStringParts = [searchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	for (NSString *searchStringPart in searchStringParts) {
		if ([searchStringPart length] == 0) continue;
		BOOL isMatch = NO;
		if ([item isKindOfClass:[MAPatternGroup class]]) {
//			MAPatternGroup *group = item;
//			isMatch |= [self doesString:group.name containString:searchStringPart];
		} else if ([item isKindOfClass:[MAPattern class]]) {
			MAPattern *pattern = item;
			isMatch |= [self doesString:pattern.name containString:searchStringPart];
			isMatch |= [self doesString:pattern.teaser containString:searchStringPart];
			isMatch |= [self doesString:pattern.keywords containString:searchStringPart];
		}
		if (!isMatch) return false;
	}
	return true;
}

- (BOOL)doesString:(NSString *)string containString:(NSString *)searchString
{
	if (!string || [searchString length] == 0) return false;
	NSRange range = [string rangeOfString:searchString options:NSCaseInsensitiveSearch];
	return (range.location != NSNotFound);
}

@end
