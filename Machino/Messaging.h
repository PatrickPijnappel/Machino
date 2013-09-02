#include "Arduino.h"

static const int kMessageStartSequenceLength = 3;
static const byte kMessageStartSequence[] = { 17, 31, 23 };

typedef enum {
	kMessageNone = 0,
	kMessageIterationStart = 1,
	kMessageIterationEnd = 2,
	kMessageCurrentState = 3,
	kMessageWillCheckCondition = 4,
	kMessageWillPerformTransition = 5,
	kMessageWillPerformAction = 6
} MessageType;

// -------------
// -- Utility --
// -------------

void setupMessaging() {
	Serial.begin(9600);
}

void writeUInt8(uint8_t value) {
	Serial.write(value);
}

void writeUInt16(uint16_t value) {
	Serial.write((value >> 8) & 255);
	Serial.write(value & 255);
}

void writeMessageHeader(MessageType type, uint16_t length) {
	Serial.write(kMessageStartSequence, kMessageStartSequenceLength);
	writeUInt8(type);
	writeUInt16(length);
}

void endMessage()
{
	Serial.flush();
}

// --------------
// -- Messages --
// --------------

void sendMessageIterationStart() {
	writeMessageHeader(kMessageIterationStart, 0);
	endMessage();
}

void sendMessageIterationEnd() {
	writeMessageHeader(kMessageIterationEnd, 0);
	endMessage();
}

void sendMessageCurrentState(int stateID) {
	writeMessageHeader(kMessageCurrentState, 2);
	writeUInt16(stateID);
	endMessage();
}

boolean sendMessageWillCheckCondition(int transitionID, int conditionID) {
	writeMessageHeader(kMessageWillCheckCondition, 4);
	writeUInt16(transitionID);
	writeUInt16(conditionID);
	endMessage();
	return true; // To allow message sending from within conditionals
}

void sendMessageWillPerformTransition(int transitionID) {
	writeMessageHeader(kMessageWillPerformTransition, 2);
	writeUInt16(transitionID);
	endMessage();
}

void sendMessageWillPerformAction(int transitionID, int index) {
	writeMessageHeader(kMessageWillPerformAction, 4);
	writeUInt16(transitionID);
	writeUInt16(index);
	endMessage();
}