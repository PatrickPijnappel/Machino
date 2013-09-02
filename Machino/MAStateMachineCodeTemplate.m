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

#import "MAStateMachineCodeTemplate.h"
#import "MASymbolManager.h"
#import "MACodeTemplate.h"
#import "Graph.h"
#import "Utility.h"

// Coder keys
static NSString * const kCoderStatesKey = @"states";
static NSString * const kCoderTransitionsKey = @"transitions";
static NSString * const kCoderConditionsKey = @"conditions";
static NSString * const kCoderActionsKey = @"actions";
static NSString * const kCoderSymbolsKey = @"symbols";
static NSString * const kCoderOptionsKey = @"options";
// Functions & sections names
static NSString * const kFunctionNameSetup = @"setup";
static NSString * const kFunctionNameLoop = @"loop";
static NSString * const kFunctionNameUpdateStateMachines = @"updateStateMachines";
static NSString * const kFunctionNameFormatUpdateStateMachine = @"updateStateMachine%i";
static NSString * const kSectionNameLibraries = @"Libraries";
static NSString * const kSectionNameVariables = @"Variables";
static NSString * const kSectionNameSetupAndLoop = @"Setup & Loop";
static NSString * const kSectionNameConditions = @"Conditions";
static NSString * const kSectionNameActions = @"Actions";
static NSString * const kSectionNameUtility = @"Utility";
static NSString * const kSectionNameStateMachine = @"State Machines";
// Key formats & keys for editable ranges. Formats inserting symbols prefix a '$' to avoid collisions.
static NSString * const kRangeAfterFunctionKeyFormat = @"AfterFunction$%@";
static NSString * const kRangeInsideFunctionKeyFormat = @"InsideFunction$%@";
static NSString * const kRangeAfterSectionHeaderKeyFormat = @"AfterSectionHeader$%@";
static NSString * const kRangeAfterVariablesKeyFormat = @"BeforeVariables$%@";
static NSString * const kRangeLibrariesKey = @"Libraries";
static NSString * const kRangeVariablesKey = @"Variables";
static NSString * const kRangeUtilityKey = @"Utility";
// Key formats & keys for extra range
static NSString * const kRangeConditionKeyFormat = @"Condition$%@";
static NSString * const kRangeActionKeyFormat = @"Action$%@";

#pragma mark - Private Interface

@interface MAStateMachineCodeTemplate ()

@property (nonatomic, copy) NSArray *stateGroups;
@property (nonatomic, copy) NSArray *conditions;
@property (nonatomic, copy) NSArray *actions;
@property (nonatomic, readonly) BOOL insertLoggingCode;

@end

@implementation MAStateMachineCodeTemplate

- (BOOL)insertLoggingCode
{
	return ((self.options & MAInsertLoggingCode) == MAInsertLoggingCode);
}

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _states = [coder decodeObjectForKey:kCoderStatesKey];
		_transitions = [coder decodeObjectForKey:kCoderTransitionsKey];
		_conditions = [coder decodeObjectForKey:kCoderConditionsKey];
		_actions = [coder decodeObjectForKey:kCoderActionsKey];
		_symbols = [coder decodeObjectForKey:kCoderSymbolsKey];
		_options = [coder decodeIntegerForKey:kCoderOptionsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeObject:self.states forKey:kCoderStatesKey];
	[coder encodeObject:self.transitions forKey:kCoderTransitionsKey];
	[coder encodeObject:self.conditions forKey:kCoderConditionsKey];
	[coder encodeObject:self.actions forKey:kCoderActionsKey];
	[coder encodeObject:self.symbols forKey:kCoderSymbolsKey];
	[coder encodeInteger:self.options forKey:kCoderOptionsKey];
}

#pragma mark - General

- (void)generate
{
	[self getStateGroups];
	[self getActionsAndConditions];
	[self assignNamesToSymbols];
	[self writeCode];
}

- (id)objectForSymbolWithID:(UInt64)symbolID
{
	return [self.symbols objectForSymbolID:symbolID];
}

- (NSRange)rangeForCondition:(MACondition *)condition
{
	NSString *conditionSymbolName = [self.symbols symbolNameForObject:condition];
	NSString *key = [NSString stringWithFormat:kRangeConditionKeyFormat, conditionSymbolName];
	return [self extraRangeForKey:key];
}

- (NSRange)rangeForAction:(MAAction *)action
{
	NSString *actionSymbolName = [self.symbols symbolNameForObject:action];
	NSString *key = [NSString stringWithFormat:kRangeActionKeyFormat, actionSymbolName];
	return [self extraRangeForKey:key];
}

- (BOOL)canSubstituteOldRangeWithKey:(id)key forNewRangeWithKey:(id)otherKey
{
	if ([key isEqualTo:otherKey]) return YES;
	if ([self isRangeInsideFunctionGivenKey:key] == [self isRangeInsideFunctionGivenKey:otherKey]) return YES;
	return NO;
}

- (BOOL)canMergeRangeWithKey:(id)key withOtherRangeWithKey:(id)otherKey
{
	if ([key isEqualTo:otherKey]) return YES;
	if (![self isRangeInsideFunctionGivenKey:key] && ![self isRangeInsideFunctionGivenKey:otherKey]) return YES;
	return NO;
}

- (BOOL)isRangeInsideFunctionGivenKey:(id)key
{
	NSString *insideFunctionKeyBase = [NSString stringWithFormat:kRangeInsideFunctionKeyFormat, @""];
	return ([key rangeOfString:insideFunctionKeyBase].location == 0);
}

#pragma mark - Writing

- (void)writeCode
{
	// Includes
	if (self.insertLoggingCode) [self writeLine:@"#include \"Messaging.h\"\n"];
	[self writeSectionHeader:kSectionNameLibraries];
	[self writeEditableLine:@"" withKey:kRangeLibrariesKey];
	// Variables
	[self writeSectionHeader:kSectionNameVariables];
	[self writeEditableLine:@"" withKey:kSectionNameVariables];
	// Setup & Loop
	[self writeSectionHeader:kSectionNameSetupAndLoop];
	[self writeLine:@""];
	[self writeFunctionWithReturnType:@"void" name:kFunctionNameSetup contents:^{
		[self writeEditableLine:@"// Add setup code here" withKey:[NSString stringWithFormat:kRangeInsideFunctionKeyFormat, kFunctionNameSetup]];
		if (self.insertLoggingCode) [self writeLine:@"setupMessaging();"];
	}];
	[self writeLine:@""];
	[self writeFunctionWithReturnType:@"void" name:kFunctionNameLoop contents:^{
		[self writeLine:@"%@();", kFunctionNameUpdateStateMachines];
	}];
	[self writeLine:@""];
	// Conditions
	[self writeSectionHeader:kSectionNameConditions];
	[self writeLine:@""];
	[self writeConditions];
	// Action
	[self writeSectionHeader:kSectionNameActions];
	[self writeLine:@""];
	[self writeActions];
	// Utility
	[self writeSectionHeader:kSectionNameUtility];
	[self writeEditableLine:@"" withKey:kSectionNameUtility];
	// State machine
	[self writeSectionHeader:kSectionNameStateMachine];
	[self writeLine:@""];
	[self writeFunctionUpdateStateMachines];
	[self.stateGroups enumerateObjectsUsingBlock:^(NSArray *stateGroup, NSUInteger index, BOOL *stop) {
		int number = (int)index+1;
		[self writeLine:@""];
		[self writeStateVariablesForStates:stateGroup withNumber:number];
		[self writeLine:@""];
		[self writeStateMachineForStates:stateGroup withNumber:number];
	}];
}

- (void)writeConditions
{
	// For all conditions
	for (MACondition *condition in self.conditions) {
		NSString *conditionSymbolName = [self.symbols symbolNameForObject:condition];
		// Write
		NSRange range = [self writeFunctionWithReturnType:@"boolean" name:conditionSymbolName contents:^{
			[self writeEditableLine:@"return false; // TODO: Return whether condition is true" withKey:[NSString stringWithFormat:kRangeInsideFunctionKeyFormat, conditionSymbolName]];
		}];
		[self writeLine:@""];
		// Mark range
		range = [[self code] lineRangeForRange:range];
		NSString *key = [NSString stringWithFormat:kRangeConditionKeyFormat, conditionSymbolName];
		[self addExtraRange:range forKey:key];
	}
}

- (void)writeActions
{
	// For all actions
	for (MAAction *action in self.actions) {
		NSString *actionSymbolName = [self.symbols symbolNameForObject:action];
		// Write
		NSRange range = [self writeFunctionWithReturnType:@"void" name:actionSymbolName contents:^{
			[self writeEditableLine:@"// TODO: Write code to perform this action" withKey:[NSString stringWithFormat:kRangeInsideFunctionKeyFormat, actionSymbolName]];
		}];
		[self writeLine:@""];
		// Mark range
		range = [[self code] lineRangeForRange:range];
		NSString *key = [NSString stringWithFormat:kRangeActionKeyFormat, actionSymbolName];
		[self addExtraRange:range forKey:key];
	}
}

- (void)writeFunctionUpdateStateMachines
{
	[self writeFunctionWithReturnType:@"void" name:kFunctionNameUpdateStateMachines contents:^{
		NSUInteger stateGroupCount = [self.stateGroups count];
		for (int i=0; i<stateGroupCount; i++) {
			NSString *functionName = [NSString stringWithFormat:kFunctionNameFormatUpdateStateMachine, i+1];
			[self writeLine:@"%@();", functionName];
		}
	}];
}

- (void)writeStateVariablesForStates:(NSArray *)states withNumber:(int)number
{
	NSString *startingStateName = @"0";
	int i=0;
	for (MANode *state in states) {
		NSString *stateName = [self.symbols symbolNameForObject:state];
		[self writeLine:@"const int %@ = %i;", stateName, i];
		if (state.isInitialState) startingStateName = stateName;
		i++;
	}
	[self writeLine:@"int currentState%i = %@;", number, startingStateName];
}

- (void)writeStateMachineForStates:(NSArray *)states withNumber:(int)number
{
	NSString *functionName = [NSString stringWithFormat:kFunctionNameFormatUpdateStateMachine, number];
	[self writeFunctionWithReturnType:@"void" name:functionName contents:^{
		[self writeLine:@"switch (currentState%i) {", number];
		[self doIndented:^{
			// For all states
			int i=0;
			for (MANode *state in states) {
				NSString *stateName = [self.symbols symbolNameForObject:state];
				UInt64 stateID = [self.symbols symbolIDForObject:state];
				if (i != 0) [self writeLine:@""];
				[self writeLine:@"case %@:", stateName];
				[self doIndented:^{
					if (self.insertLoggingCode) [self writeLine:@"sendMessageCurrentState(%lli);", stateID];
					[self writeTransitionsForState:state withNumber:number];
					[self writeLine:@"break;"];
				}];
				i++;
			}
		}];
		[self writeLine:@"}"];
	}];
}

- (void)writeTransitionsForState:(MANode *)state withNumber:(int)number
{
	// Conditions
	NSMutableArray *nothingTransitions = [NSMutableArray array];
	for (MAArrow *transition in state.arrows) {
		if (transition.sourceNode != state) continue;
		if (transition.condition) {
			NSString *conditionName = [self.symbols symbolNameForObject:transition.condition];
			UInt64 conditionID = [self.symbols symbolIDForObject:transition.condition];
			UInt64 transitionID = [self.symbols symbolIDForObject:transition];
			NSString *conditionCode;
			if (self.insertLoggingCode) {
				conditionCode = [NSString stringWithFormat:@"sendMessageWillCheckCondition(%lli, %lli) && %@()", transitionID, conditionID, conditionName];
			} else {
				conditionCode = [NSString stringWithFormat:@"%@()", conditionName];
			}
			[self writeLine:@"if (%@) {", conditionCode];
			[self doIndented:^{ [self writeTransition:transition withStateGroupNumber:number isLast:NO]; }];
			[self writeLine:@"}"];
		} else {
			[nothingTransitions addObject:transition];
		}
	}
	if ([nothingTransitions count] > 0) {
		MAArrow *lastTransition = [nothingTransitions lastObject];
		for (MAArrow *transition in nothingTransitions) { // TODO: This is not correct for transitions that are not self-pointing (sets state var multiple times)
			BOOL isLast = (transition == lastTransition);
			[self writeTransition:transition withStateGroupNumber:number isLast:isLast];
		}
	}
}

- (void)writeTransition:(MAArrow *)transition withStateGroupNumber:(int)number isLast:(BOOL)isLast
{
	UInt64 transitionID = [self.symbols symbolIDForObject:transition];
	if (self.insertLoggingCode) [self writeLine:@"sendMessageWillPerformTransition(%lli);", transitionID];
	// Write actions, if there are any
	for (MAAction *action in transition.actions) {
		NSString *actionName = [self.symbols symbolNameForObject:action];
		NSUInteger actionIndex = [transition.actions indexOfObject:action];
		if (self.insertLoggingCode) [self writeLine:@"sendMessageWillPerformAction(%lli, %i);", transitionID, (int)actionIndex];
		[self writeLine:@"%@();", actionName];
	}
	// Write transition to another state, if applicable
	if (transition.targetNode != transition.sourceNode) {
		NSString *targetStateName = [self.symbols symbolNameForObject:transition.targetNode];
		[self writeLine:@"currentState%i = %@;", number, targetStateName];
		if (!isLast) [self writeLine:@"break;"];
	}
}

#pragma mark Writing Utility

- (NSRange)writeFunctionWithReturnType:(NSString *)returnType name:(NSString *)name contents:(void(^)())block
{
	NSUInteger startIndex = [[self code] length]+1;
	[self writeLine:@"%@ %@() {", returnType, name];
	[self doIndented:block];
	[self writeLine:@"}"];
	NSUInteger endIndex = [[self code] length];
	return NSMakeRange(startIndex, endIndex-startIndex);
}

- (void)writeSectionHeader:(NSString *)name
{
	NSMutableString *dashes = [NSMutableString string];
	for (int i=0; i<[name length]; i++) {
		[dashes appendString:@"-"];
	}
	// Write
	[self writeLine:@"// ---%@---", dashes];
	[self writeLine:@"// -- %@ --", name];
	[self writeLine:@"// ---%@---", dashes];
}

#pragma mark - Preparation

- (void)getStateGroups
{
	NSMutableArray *stateGroups = [NSMutableArray array];
	for (MANode *state in self.states) {
		// Check if it's already in one of the state machines in the list
		BOOL alreadyInList = NO;
		for (NSArray *stateGroup in stateGroups) {
			if ([stateGroup containsObject:state]) {
				alreadyInList = YES;
				break;
			}
		}
		// If not, add its state machine
		if (!alreadyInList) {
			NSArray *stateGroup = [state findConnectedNodes];
			[stateGroups addObject:stateGroup];
		}
	}
	self.stateGroups = stateGroups;
}

- (void)getActionsAndConditions
{
	NSMutableArray *conditions = [NSMutableArray array];
	NSMutableArray *actions = [NSMutableArray array];
	for (MAArrow *transition in self.transitions) {
		// Conditions
		MACondition *condition = transition.condition;
		if (condition && ![conditions containsObject:condition]) [conditions addObject:condition];
		// Actions
		for (MAAction *action in transition.actions) {
			if (![actions containsObject:action]) [actions addObject:action];
		}
	}
	self.conditions = conditions;
	self.actions = actions;
}

- (void)assignNamesToSymbols
{
	if (!self.symbols) self.symbols = [self createSymbolManager];
	MASymbolManager *symbols = self.symbols;
	// Add reserved names
	NSUInteger stateGroupCount = [self.stateGroups count];
	for (int i=0; i<stateGroupCount; i++) {
		NSString *functionName = [NSString stringWithFormat:kFunctionNameFormatUpdateStateMachine, i+1];
		[symbols addReservedNames:@[ functionName ]];
	}
	// States
	for (MANode *state in self.states) {
		if (![symbols containsObject:state]) {
			[symbols addObject:state withName:state.name symbolNameFormat:@"state %@"];
		} else {
			[symbols setName:state.name forObject:state];
		}
	}
	// Transitions
	for (MAArrow *transition in self.transitions) {
		if (![symbols containsObject:transition]) {
			[symbols addObject:transition withName:nil]; // To give it an id
		}
	}
	// Conditions
	for (MACondition *condition in self.conditions) {
		if (![symbols containsObject:condition]) {
			[symbols addObject:condition withName:condition.name symbolNameFormat:nil];
		} else {
			[symbols setName:condition.name forObject:condition];
		}
	}
	// Actions
	for (MAAction *action in self.actions) {
		if (![symbols containsObject:action]) {
			[symbols addObject:action withName:action.name];
		} else {
			[symbols setName:action.name forObject:symbols];
		}
	}
	// Remove unused symbols
	NSArray *allObjects = [symbols allObjects];
	for (id object in allObjects) {
		if ([object isKindOfClass:[MANode class]] && [self.states containsObject:object]) continue;
		if ([object isKindOfClass:[MAArrow class]] && [self.transitions containsObject:object]) continue;
		if ([object isKindOfClass:[MACondition class]] && [self.conditions containsObject:object]) continue;
		if ([object isKindOfClass:[MAAction class]] && [self.actions containsObject:object]) continue;
		// Not used anymore, delete
		[symbols removeObject:object];
	}
	// Generate names
	[symbols generateSymbolNames];
}

- (MASymbolManager *)createSymbolManager
{
	MASymbolManager *symbols = [[MASymbolManager alloc] init];
	symbols.maximumSymbolID = UINT16_MAX;
	// Add reserved names
	NSString *path = [[NSBundle mainBundle] pathForResource:@"ReservedSymbolNames" ofType:@"txt"];
	NSString *reversedNamesString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	NSArray *reservedNames = [reversedNamesString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	reservedNames = [reservedNames arrayUsingBlock:^id(NSString *str) {
		return ([str length] > 0) ? str : nil; // Returning nil will remove the element
	}];
	[symbols addReservedNames:reservedNames];
	// Return
	return symbols;
}

@end
