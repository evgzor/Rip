/*
 *  Copyright (C) 2005 - 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "BitArray.h"

@interface BitArray (Private)
- (NSUInteger) arrayLength;
@end

@implementation BitArray

@synthesize bitCount = _bitCount;

+ (id) bitArrayWithBitCount:(NSUInteger)bitCount
{
	return [[BitArray alloc] initWithBitCount:bitCount];
}

- (id) initWithBitCount:(NSUInteger)bitCount
{
	if((self = [super init]))
		self.bitCount = bitCount;
	return self;
}

- (id) initWithData:(NSData *)data
{
	NSParameterAssert(nil != data);
	
	return [self initWithBits:[data bytes] bitCount:([data length] / 8)];
}

- (id) initWithBits:(const void *)buffer bitCount:(NSUInteger)bitCount
{
	NSParameterAssert(NULL != buffer);
	
	if((self = [super init])) {
		self.bitCount = bitCount;
		memcpy(_bits, buffer, self.arrayLength * sizeof(NSUInteger));
	}
	return self;
}

#pragma mark NSCoding

- (id) initWithCoder:(NSCoder *)decoder
{
	NSParameterAssert(nil != decoder);

	if((self = [super init])) {
		self.bitCount = (NSUInteger)[decoder decodeIntegerForKey:@"BABitCount"];

		NSUInteger length = 0;
		const uint8_t *bits = [decoder decodeBytesForKey:@"BABits" returnedLength:&length];

		memcpy(_bits, bits, length);
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	NSParameterAssert(nil != encoder);
	
	[encoder encodeInteger:(NSInteger)self.bitCount forKey:@"BABitCount"];
	[encoder encodeBytes:(const uint8_t *)_bits length:(self.arrayLength * sizeof(NSUInteger)) forKey:@"BABits"];
}

#pragma mark NSCopying

- (id) copyWithZone:(NSZone *)zone
{
	BitArray *copy = [[[self class] allocWithZone:zone] init];
	
	copy.bitCount = self.bitCount;
	if(self.bitCount)
		memcpy(copy->_bits, _bits, self.arrayLength * sizeof(NSUInteger));
	
	return copy;
}

#pragma mark Bit Count

- (void) setBitCount:(NSUInteger)bitCount
{
	if(bitCount != self.bitCount) {
		_bitCount = bitCount;

		if(0 == bitCount)
			return;
		
		_bits = NSAllocateCollectable(self.arrayLength * sizeof(NSUInteger), 0);
		if(NULL == _bits) {

#if DEBUG
			NSLog(@"Unable to allocate memory");
#endif

			_bitCount = 0;
			return;
		}
		memset(_bits, 0, self.arrayLength * sizeof(NSUInteger));
	}
}

#pragma mark Bit Getting/Setting

- (BOOL) valueAtIndex:(NSUInteger)desiredIndex
{
	NSParameterAssert(desiredIndex < self.bitCount);
	
	NSUInteger arrayIndex = desiredIndex / (8 * sizeof(NSUInteger));
	NSUInteger bitIndex = desiredIndex % (8 * sizeof(NSUInteger));
	
	return (_bits[arrayIndex] & (1 << bitIndex) ? YES : NO);
}

- (void) setValue:(BOOL)value forIndex:(NSUInteger)desiredIndex
{
	NSParameterAssert(desiredIndex < self.bitCount);

	NSUInteger arrayIndex = desiredIndex / (8 * sizeof(NSUInteger));
	NSUInteger bitIndex = desiredIndex % (8 * sizeof(NSUInteger));
	uint32_t mask = value << bitIndex;
	
	if(value)
		_bits[arrayIndex] |= mask;
	else
		_bits[arrayIndex] &= mask;
}

#pragma mark Zero methods

- (BOOL) allZeroes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i) {
		if(0 != _bits[i])
			return NO;
	}
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i) {
		if(0 != (_bits[lastArrayIndex] & (1 << i)))
			return NO;
	}
	
	return YES;
}

- (NSUInteger) countOfZeroes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));
	NSUInteger result = 0;
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i) {
		if(!_bits[i]) {
			for(NSUInteger j = 0; j < (8 * sizeof(NSUInteger)); ++j) {
				if(!(_bits[i] & (1 << j)))
					++result;
			}
		}
	}
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i) {
		if(!(_bits[lastArrayIndex] & (1 << i)))
			++result;
	}
	
	return result;
}

- (void) setAllZeroes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i)
		_bits[i] = 0;
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i)
		_bits[lastArrayIndex] &= ~(1 << i);
}

- (NSIndexSet *) indexSetForZeroes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));

	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i) {
		if(!_bits[i]) {
			for(NSUInteger j = 0; j < (8 * sizeof(NSUInteger)); ++j) {
				if(!(_bits[i] & (1 << j)))
					[indexSet addIndex:((i * (8 * sizeof(NSUInteger))) + j)];
			}
		}
	}
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i) {
		if(!(_bits[lastArrayIndex] & (1 << i)))
			[indexSet addIndex:((lastArrayIndex * (8 * sizeof(NSUInteger))) + i)];
	}
	
	return [indexSet copy];
}

#pragma mark One methods

- (BOOL) allOnes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i) {
		if(NSUIntegerMax != _bits[i])
			return NO;
	}
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i) {
		if(0 == (_bits[lastArrayIndex] & (1 << i)))
			return NO;
	}
	
	return YES;
}

- (NSUInteger) countOfOnes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));
	NSUInteger result = 0;
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i) {
		if(_bits[i]) {
			for(NSUInteger j = 0; j < (8 * sizeof(NSUInteger)); ++j) {
				if(_bits[i] & (1 << j)) 
					++result;
			}
		}
	}
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i) {
		if(_bits[lastArrayIndex] & (1 << i))
			++result;
	}
	
	return result;
}

- (void) setAllOnes
{	
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));

	for(NSUInteger i = 0; i < lastArrayIndex; ++i)
		_bits[i] = NSUIntegerMax;
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i)
		_bits[lastArrayIndex] |= 1 << i;
}

- (NSIndexSet *) indexSetForOnes
{
	NSUInteger lastArrayIndex = self.bitCount / (8 * sizeof(NSUInteger));
	NSUInteger lastBitIndex = self.bitCount % (8 * sizeof(NSUInteger));

	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	
	for(NSUInteger i = 0; i < lastArrayIndex; ++i) {
		if(_bits[i]) {
			for(NSUInteger j = 0; j < (8 * sizeof(NSUInteger)); ++j) {
				if(_bits[i] & (1 << j)) 
					[indexSet addIndex:((i * (8 * sizeof(NSUInteger))) + j)];
			}
		}
	}
	
	for(NSUInteger i = 0; i < lastBitIndex; ++i) {
		if(_bits[lastArrayIndex] & (1 << i))
			[indexSet addIndex:((lastArrayIndex * (8 * sizeof(NSUInteger))) + i)];
	}
	
	return [indexSet copy];
}

- (NSString *) description
{
	NSMutableString *result = [NSMutableString string];

	for(NSUInteger i = 0; i < self.bitCount; ++i) {
		[result appendString:([self valueAtIndex:i] ? @"1" : @"0")];
		if(0 == i % 8)
			[result appendString:@" "];
		if(0 == i % 32)
			[result appendString:@"\n"];
	}
	
	return result;
}

@end

@implementation BitArray (Private)

- (NSUInteger) arrayLength
{
	return ((self.bitCount + ((8 * sizeof(NSUInteger)) - 1)) / (8 * sizeof(NSUInteger)));
}

@end
