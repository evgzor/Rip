/*
 *  Copyright (C) 2008 - 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "TrackMetadata.h"

@implementation TrackMetadata

// ========================================
// Core Data properties
@dynamic additionalMetadata;
@dynamic artist;
@dynamic composer;
@dynamic date;
@dynamic genre;
@dynamic ISRC;
@dynamic lyrics;
@dynamic musicBrainzID;
@dynamic peak;
@dynamic replayGain;
@dynamic title;

// ========================================
// Core Data relationships
@dynamic track;

@end

