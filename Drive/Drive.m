/*
 *  Copyright (C) 2005 - 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "Drive.h"
#import "SectorRange.h"
#import "Logger.h"

#include <IOKit/storage/IOCDTypes.h>
#include <IOKit/storage/IOCDMediaBSDClient.h>
#include <util.h>

@interface Drive ()
@property (assign) DADiskRef disk;
@property (copy) NSError * error;
@property (assign) int fd;
@end

@interface Drive (Private)
- (NSUInteger) readCD:(void *)buffer sectorAreas:(uint8_t)sectorAreas startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;
@end

@implementation Drive

@synthesize disk = _disk;
@synthesize error = _error;
@synthesize fd = _fd;
@synthesize cacheSize = _cacheSize;

- (id) initWithDADiskRef:(DADiskRef)disk
{
	NSParameterAssert(NULL != disk);

	if((self = [super init])) {
		self.cacheSize	= 2 * 1024 * 1024;
		self.disk = disk;
		self.fd = -1;
	}

	return self;
}

- (void) finalize
{
	[self closeDevice];
	
	[super finalize];
}

// Device management
- (BOOL) deviceIsOpen
{
	return (-1 != self.fd);
}

- (BOOL) openDevice
{
	if(self.deviceIsOpen)
		return YES;

	// Claim the disk for exclusive use
//	DADiskClaim(self.disk);
	
	self.fd = opendev((char *)DADiskGetBSDName(self.disk), O_RDONLY, 0, NULL);
	if(-1 == self.fd) {
		[[Logger sharedLogger] logMessage:@"Unable to open the drive for reading"];
		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return NO;
	}
	else
		return YES;
}

- (BOOL) closeDevice
{
	if(!self.deviceIsOpen)
		return YES;

	int result = close(self.fd);
	self.fd = -1;

	// We no longer need exclusive access to the disk
//	DADiskUnclaim(self.disk);
	
	if(-1 == result) {
		[[Logger sharedLogger] logMessage:@"Unable to close the drive"];
		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return NO;
	}
	else
		return YES;
}

- (NSUInteger) cacheSizeInSectors
{
	return ((self.cacheSize / kCDSectorSizeCDDA) + 1);
}

- (uint16_t) speed
{
	uint16_t speed = 0;
	if(-1 == ioctl(self.fd, DKIOCCDGETSPEED, &speed)) {
		[[Logger sharedLogger] logMessage:@"Unable to get the drive's speed"];
		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
	}

	return speed;
}

- (BOOL) setSpeed:(uint16_t)speed
{
	if(-1 == ioctl(self.fd, DKIOCCDSETSPEED, &speed)) {
		[[Logger sharedLogger] logMessage:@"Unable to set the drive's speed"];
		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return NO;
	}

	return YES;
}

- (BOOL) clearCacheAvoidingRange:(SectorRange *)range legalSectors:(SectorRange *)legalSectors
{
	NSUInteger sectorsRemaining, sectorsRead, boundary;

	NSUInteger requiredReadSize			= self.cacheSizeInSectors;
	NSUInteger sessionFirstSector		= legalSectors.firstSector;
	NSUInteger sessionLastSector		= legalSectors.lastSector;
	NSUInteger preSectorsAvailable		= range.firstSector - sessionFirstSector;
	NSUInteger postSectorsAvailable		= sessionLastSector - range.lastSector;

	// Allocate the buffer
	NSUInteger			bufferLen	= requiredReadSize < 1024 ? requiredReadSize : 1024;
	__strong int16_t	*buffer		= NSAllocateCollectable(bufferLen * kCDSectorSizeCDDA, 0);
	
	if(NULL == buffer) {
		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
		return NO;
	}

	// Make sure there are enough sectors outside the range to fill the cache
	if(preSectorsAvailable + postSectorsAvailable < requiredReadSize) {
		[[Logger sharedLogger] logMessageWithLevel:eLogMessageLevelDebug format:@"Unable to flush the drive's cache"];

		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
		return NO;
	}

	// Read from whichever block of sectors is the largest
	if(preSectorsAvailable > postSectorsAvailable && preSectorsAvailable >= requiredReadSize) {
		sectorsRemaining = requiredReadSize;
		while(0 < sectorsRemaining) {
			sectorsRead = [self readAudio:buffer
							  startSector:sessionFirstSector + (requiredReadSize - sectorsRemaining)
							  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
			
			if(0 == sectorsRead)
				return NO;

			sectorsRemaining -= sectorsRead;
		}
	}
	else if(postSectorsAvailable >= requiredReadSize) {
		sectorsRemaining = requiredReadSize;
		while(0 < sectorsRemaining) {
			sectorsRead = [self readAudio:buffer
							  startSector:sessionLastSector - sectorsRemaining
							  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];

			if(0 == sectorsRead)
				return NO;

			sectorsRemaining -= sectorsRead;
		}
	}
	// Need to read multiple blocks
	else {

		// First read as much as possible from before the range
		boundary			= [range firstSector] - 1;
		sectorsRemaining	= boundary;

		while(0 < sectorsRemaining) {
			sectorsRead = [self readAudio:buffer
							  startSector:sessionFirstSector + (boundary - sectorsRemaining)
							  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];

			if(0 == sectorsRead)
				return NO;

			sectorsRemaining -= sectorsRead;
		}

		// Read the remaining sectors from after the range
		boundary			= [range lastSector] + 1;
		sectorsRemaining	= requiredReadSize - sectorsRemaining;

		// This should never happen; we tested for it above
		if(sectorsRemaining > (sessionLastSector - boundary))
			NSLog(@"fnord!");

		while(0 < sectorsRemaining) {
			sectorsRead = [self readAudio:buffer
							  startSector:sessionLastSector - sectorsRemaining
							  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];

			if(0 == sectorsRead)
				return NO;

			sectorsRemaining -= sectorsRead;
		}
	}

	return YES;
}

- (NSUInteger) readAudio:(void *)buffer sector:(NSUInteger)sector
{
	return [self readAudio:buffer startSector:sector sectorCount:1];
}

- (NSUInteger) readAudio:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudio:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (NSUInteger) readAudio:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount
{
	return [self readCD:buffer sectorAreas:kCDSectorAreaUser startSector:startSector sectorCount:sectorCount];
}

- (NSUInteger) readAudioAndQSubchannel:(void *)buffer sector:(NSUInteger)sector
{
	return [self readAudioAndQSubchannel:buffer startSector:sector sectorCount:1];
}

- (NSUInteger) readAudioAndQSubchannel:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudioAndQSubchannel:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (NSUInteger) readAudioAndQSubchannel:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount
{
	return [self readCD:buffer sectorAreas:(kCDSectorAreaUser | kCDSectorAreaSubChannelQ) startSector:startSector sectorCount:sectorCount];
}

- (NSUInteger) readAudioAndErrorFlags:(void *)buffer sector:(NSUInteger)sector
{
	return [self readAudioAndErrorFlags:buffer startSector:sector sectorCount:1];
}

- (NSUInteger) readAudioAndErrorFlags:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudioAndErrorFlags:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (NSUInteger) readAudioAndErrorFlags:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount
{
	return [self readCD:buffer sectorAreas:(kCDSectorAreaUser | kCDSectorAreaErrorFlags) startSector:startSector sectorCount:sectorCount];
}

- (NSUInteger) readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sector:(NSUInteger)sector
{
	return [self readAudioAndErrorFlagsWithQSubchannel:buffer startSector:sector sectorCount:1];
}

- (NSUInteger) readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudioAndErrorFlagsWithQSubchannel:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (NSUInteger) readAudioAndErrorFlagsWithQSubchannel:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount
{
	return [self readCD:buffer sectorAreas:(kCDSectorAreaUser | kCDSectorAreaErrorFlags | kCDSectorAreaSubChannelQ) startSector:startSector sectorCount:sectorCount];
}

- (NSString *) readMCN
{
	dk_cd_read_mcn_t cd_read_mcn;
	bzero(&cd_read_mcn, sizeof(cd_read_mcn));

	if(-1 == ioctl(self.fd, DKIOCCDREADMCN, &cd_read_mcn)) {
		[[Logger sharedLogger] logMessage:@"Unable to read the disc's media catalog number (MCN)"];
		
		// This is not an error condition
		return nil;
	}

	return [NSString stringWithCString:cd_read_mcn.mcn encoding:NSASCIIStringEncoding];
}

- (NSString *) readISRC:(NSUInteger)track
{
	dk_cd_read_isrc_t cd_read_isrc;
	bzero(&cd_read_isrc, sizeof(cd_read_isrc));

	cd_read_isrc.track = track;

	if(-1 == ioctl(self.fd, DKIOCCDREADISRC, &cd_read_isrc)) {
		[[Logger sharedLogger] logMessage:@"Unable to read the international standard recording code (ISRC) for track %i", track];

		// This is not an error condition
		return nil;
	}

	return [NSString stringWithCString:cd_read_isrc.isrc encoding:NSASCIIStringEncoding];
}

@end

@implementation Drive (Private)

// Implementation method
- (NSUInteger) readCD:(void *)buffer sectorAreas:(uint8_t)sectorAreas startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount
{
	NSParameterAssert(NULL != buffer);
	NSParameterAssert(0 != sectorAreas);
	NSParameterAssert(0 < sectorCount);
	
	dk_cd_read_t	cd_read;
	NSUInteger		blockSize		= 0;

	if(kCDSectorAreaUser & sectorAreas)				blockSize += kCDSectorSizeCDDA;
	if(kCDSectorAreaErrorFlags & sectorAreas)		blockSize += kCDSectorSizeErrorFlags;
	if(kCDSectorAreaSubChannelQ & sectorAreas)		blockSize += kCDSectorSizeQSubchannel;

	if(0 == blockSize)
		return 0;
	
	bzero(&cd_read, sizeof(cd_read));
	bzero(buffer, blockSize * sectorCount);

	cd_read.offset			= (uint64_t)blockSize * startSector;
	cd_read.sectorArea		= sectorAreas;
	cd_read.sectorType		= kCDSectorTypeCDDA;
	cd_read.buffer			= buffer;
	cd_read.bufferLength	= (uint32_t)(blockSize * sectorCount);

	if(-1 == ioctl(self.fd, DKIOCCDREAD, &cd_read)) {
		self.error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return 0;
	}
	
	if(cd_read.bufferLength != (blockSize * sectorCount))
		[[Logger sharedLogger] logMessage:@"DKIOCCDREAD: Requested %ld bytes at sector %ld (offset %ld), got %ld", blockSize * sectorCount, startSector, blockSize * startSector, cd_read.bufferLength];
	
	return cd_read.bufferLength / blockSize;
}

@end
