/*
 *  Copyright (C) 2005 - 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <Cocoa/Cocoa.h>

// ========================================
// Utility class representing a contiguous, inclusive range of sectors on a CDDA disc
// ========================================
@interface SectorRange : NSObject <NSCopying, NSCoding>
{
@private
	NSUInteger _firstSector;
	NSUInteger _lastSector;
}

// ========================================
// Properties
@property (readonly, assign) NSUInteger firstSector;
@property (readonly, assign) NSUInteger lastSector;
@property (readonly) NSUInteger length;
@property (readonly) NSUInteger byteSize;

// ========================================
// Creation
+ (id) sectorRangeWithSector:(NSUInteger)sector;
+ (id) sectorRangeWithRange:(NSRange)range;
+ (id) sectorRangeWithFirstSector:(NSUInteger)firstSector lastSector:(NSUInteger)lastSector;
+ (id) sectorRangeWithFirstSector:(NSUInteger)firstSector sectorCount:(NSUInteger)sectorCount;
+ (id) sectorRangeWithLastSector:(NSUInteger)lastSector sectorCount:(NSUInteger)sectorCount;

- (id) initWithSector:(NSUInteger)sector;
- (id) initWithRange:(NSRange)range;
- (id) initWithFirstSector:(NSUInteger)firstSector lastSector:(NSUInteger)lastSector;
- (id) initWithFirstSector:(NSUInteger)firstSector sectorCount:(NSUInteger)sectorCount;
- (id) initWithLastSector:(NSUInteger)lastSector sectorCount:(NSUInteger)sectorCount;

// ========================================
// Utilities
- (BOOL) isEqualToSectorRange:(SectorRange *)anotherSectorRange;

- (NSUInteger) indexForSector:(NSUInteger)sector;
- (NSUInteger) sectorForIndex:(NSUInteger)index;

- (BOOL) containsSector:(NSUInteger)sector;
- (BOOL) containsSectorRange:(SectorRange *)range;
- (BOOL) intersectsSectorRange:(SectorRange *)range;
- (SectorRange *) intersectedSectorRange:(SectorRange *)range;

- (NSRange) rangeValue;

@end
