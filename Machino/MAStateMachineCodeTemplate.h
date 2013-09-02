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

#import <Foundation/Foundation.h>
#import "MACodeTemplate.h"

@class MASymbolManager;
@class MACondition;
@class MAAction;

typedef NS_OPTIONS(NSUInteger, MAStateMachineCodeTemplateOptions) {
	MAInsertLoggingCode = 1
};

@interface MAStateMachineCodeTemplate : MACodeTemplate <NSCoding>

@property (nonatomic) MAStateMachineCodeTemplateOptions options;
@property (nonatomic, copy) NSArray *states;
@property (nonatomic, copy) NSArray *transitions;
@property (nonatomic, strong) MASymbolManager *symbols;

- (void)generate;
- (id)objectForSymbolWithID:(UInt64)symbolID;
- (NSRange)rangeForCondition:(MACondition *)condition;
- (NSRange)rangeForAction:(MAAction *)action;

@end
