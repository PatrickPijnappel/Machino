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

@protocol MAArduinoControllerDelegate;
@class ORSSerialPort;
@class MABoard;

@interface MAArduinoController : NSObject

@property (nonatomic, weak) id<MAArduinoControllerDelegate> delegate;
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic, strong) MABoard *board;

// Serial
- (BOOL)connect;
- (void)disconnect;
- (void)sendDataToArduino:(NSData *)data;
// Upload
- (void)uploadCode:(NSString *)code error:(NSError **)error completion:(void(^)(BOOL success, NSString *output, NSString *errors))completion;

@end

@protocol MAArduinoControllerDelegate <NSObject>

- (void)arduinoDidStartIteration:(MAArduinoController *)arduino;
- (void)arduinoDidEndIteration:(MAArduinoController *)arduino;
- (void)arduino:(MAArduinoController *)arduino didSendCurrentStateID:(UInt16)stateID;
- (void)arduino:(MAArduinoController *)arduino willCheckConditionWithID:(UInt16)conditionID forTransitionWithID:(UInt16)transitionID;
- (void)arduino:(MAArduinoController *)arduino willPerformTransitionWithID:(UInt16)transitionID;
- (void)arduino:(MAArduinoController *)arduino willPerformActionAtIndex:(UInt16)index forTransitionWithID:(UInt16)transitionID;
- (void)arduino:(MAArduinoController *)arduino didReceiveUserSerialData:(NSData *)data;

@end