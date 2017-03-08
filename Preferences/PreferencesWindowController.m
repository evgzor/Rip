/*
 *  Copyright (C) 2008 - 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "PreferencesWindowController.h"
#import "NSViewController+PreferencesViewControllerMethods.h"

// ========================================
// Identifiers for toolbar items
// ========================================
NSString * const	GeneralPreferencesToolbarItemIdentifier						= @"org.sbooth.Rip.Preferences.Toolbar.General";
NSString * const	EncoderPreferencesToolbarItemIdentifier						= @"org.sbooth.Rip.Preferences.Toolbar.Encoder";
NSString * const	MusicDatabasePreferencesToolbarItemIdentifier				= @"org.sbooth.Rip.Preferences.Toolbar.MusicDatabase";
NSString * const	AdvancedPreferencesToolbarItemIdentifier					= @"org.sbooth.Rip.Preferences.Toolbar.Advanced";

// ========================================
// The global instance
// ========================================
static PreferencesWindowController *sSharedPreferencesWindowController = nil;

@interface PreferencesWindowController (Private)
- (IBAction) toolbarItemSelected:(id)sender;
@end

@implementation PreferencesWindowController

+ (PreferencesWindowController *) sharedPreferencesWindowController
{
	if(!sSharedPreferencesWindowController)
		sSharedPreferencesWindowController = [[self alloc] init];
	return sSharedPreferencesWindowController;
}

- (id) init
{
	return [super initWithWindowNibName:@"PreferencesWindow"];
}

- (void) windowDidLoad
{
	// Set up the toolbar
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"org.sbooth.Rip.Preferences.Toolbar"];
	
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
	
	// Determine which preference view to select
	NSString *itemIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"selectedPreferencePane"];
	
	// If the item identifier is nil, fall back to a visible item
	if(!itemIdentifier) {
		if(nil != [toolbar visibleItems] && 0 != [[toolbar visibleItems] count])
			itemIdentifier = [[[toolbar visibleItems] objectAtIndex:0] itemIdentifier];
		else if(nil != [toolbar items] && 0 != [[toolbar items] count])
			itemIdentifier = [[[toolbar items] objectAtIndex:0] itemIdentifier];
		else
			itemIdentifier = GeneralPreferencesToolbarItemIdentifier;
	}
	
	[self selectPreferencePaneWithIdentifier:itemIdentifier];
	
	// Center our window
//	[[self window] center];
}

- (void) windowWillClose:(NSNotification *)notification
{
	
#pragma unused (notification)

	// Save the settings for the current preference pane
	if([_preferencesViewController respondsToSelector:@selector(savePreferences:)])
		[_preferencesViewController savePreferences:self];
}

- (void) selectPreferencePaneWithIdentifier:(NSString *)itemIdentifier
{
	NSParameterAssert(nil != itemIdentifier);

	// Select the appropriate toolbar item if it isn't already
	if(![[[[self window] toolbar] selectedItemIdentifier] isEqualToString:itemIdentifier])
		[[[self window] toolbar] setSelectedItemIdentifier:itemIdentifier];
	
	// Remove any preference subviews that are currently being displayed
	if(_preferencesViewController) {
		// Save the settings first
		if([_preferencesViewController respondsToSelector:@selector(savePreferences:)])
			[_preferencesViewController savePreferences:self];

		[[_preferencesViewController view] removeFromSuperview];
	}
	
	// Adjust the window and view's frame size to match the preference's view size
	Class preferencesViewControllerClass = NSClassFromString([[[itemIdentifier componentsSeparatedByString:@"."] lastObject] stringByAppendingString:@"PreferencesViewController"]);
	_preferencesViewController = [[preferencesViewControllerClass alloc] init];

	// Calculate the difference between the current and target preference view sizes
	NSRect currentPreferencesViewFrame = [_preferencesView frame];
	NSRect targetPreferencesViewFrame = [[_preferencesViewController view] frame];
	
	CGFloat viewDeltaX = targetPreferencesViewFrame.size.width - currentPreferencesViewFrame.size.width;
	CGFloat viewDeltaY = targetPreferencesViewFrame.size.height - currentPreferencesViewFrame.size.height;
	
	// Calculate the new window and view sizes
	NSRect currentWindowFrame = [self.window frame];
	NSRect newWindowFrame = currentWindowFrame;
	
	newWindowFrame.origin.x -= viewDeltaX / 2;
	newWindowFrame.origin.y -= viewDeltaY;
	newWindowFrame.size.width += viewDeltaX;
	newWindowFrame.size.height += viewDeltaY;
	
	NSRect newViewFrame = currentPreferencesViewFrame;
	
	newViewFrame.size.width += viewDeltaX;
	newViewFrame.size.height += viewDeltaY;
	
	// Set the new sizes
	[self.window setFrame:newWindowFrame display:YES animate:YES];
	[_preferencesView setFrame:newViewFrame];
	
	// Now that the sizes are correct, add the view controller's view to the view hierarchy
	[_preferencesView addSubview:[_preferencesViewController view]];

	// Set the next responder and key view
	[self setNextResponder:_preferencesViewController];

	NSView *view = [_preferencesView nextValidKeyView];
	if(view)
		[[self window] makeFirstResponder:view];
	
	// Set the window's title to the name of the preference view
	[[self window] setTitle:[_preferencesViewController title]];
	
	// Save the selected pane
	[[NSUserDefaults standardUserDefaults] setObject:itemIdentifier forKey:@"selectedPreferencePane"];	
}

@end

@implementation PreferencesWindowController (NSToolbarDelegateMethods)

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
	
#pragma unused (toolbar)
#pragma unused (flag)
	
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(toolbarItemSelected:)];
	
    if([itemIdentifier isEqualToString:GeneralPreferencesToolbarItemIdentifier]) {
		[toolbarItem setLabel:NSLocalizedString(@"General", @"General preference pane name")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"General", @"")];		
		[toolbarItem setToolTip:NSLocalizedString(@"Options that control the general behavior of Rip", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"NSPreferencesGeneral"]];
	}
    else if([itemIdentifier isEqualToString:EncoderPreferencesToolbarItemIdentifier]) {
		[toolbarItem setLabel:NSLocalizedString(@"Encoders", @"Encoders preference pane name")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Encoders", @"")];
		[toolbarItem setToolTip:NSLocalizedString(@"Select and configure the encoder used for output files", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"EncoderPreferencesToolbarIcon"]];
	}
    else if([itemIdentifier isEqualToString:MusicDatabasePreferencesToolbarItemIdentifier]) {
		[toolbarItem setLabel:NSLocalizedString(@"Metadata", @"Metadata preference pane name")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Metadata", @"")];
		[toolbarItem setToolTip:NSLocalizedString(@"Select and configure the metadata provider", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"MetadataPreferencesToolbarIcon"]];
	}
    else if([itemIdentifier isEqualToString:AdvancedPreferencesToolbarItemIdentifier]) {
		[toolbarItem setLabel:NSLocalizedString(@"Advanced", @"Advanced preference pane name")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Advanced", @"")];
		[toolbarItem setToolTip:NSLocalizedString(@"Configure some of the audio extraction parameters used by Rip", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"NSAdvanced"]];
	}
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{

#pragma unused (toolbar)

	return [NSArray arrayWithObjects:
			GeneralPreferencesToolbarItemIdentifier,
			EncoderPreferencesToolbarItemIdentifier,
			MusicDatabasePreferencesToolbarItemIdentifier,
			AdvancedPreferencesToolbarItemIdentifier,
			nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{
	
#pragma unused (toolbar)

	return [NSArray arrayWithObjects:
			GeneralPreferencesToolbarItemIdentifier,
			EncoderPreferencesToolbarItemIdentifier,
			MusicDatabasePreferencesToolbarItemIdentifier,
			AdvancedPreferencesToolbarItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	
#pragma unused (toolbar)

	return [NSArray arrayWithObjects:
			GeneralPreferencesToolbarItemIdentifier,
			EncoderPreferencesToolbarItemIdentifier,
			MusicDatabasePreferencesToolbarItemIdentifier,
			AdvancedPreferencesToolbarItemIdentifier,
			nil];
}

@end

@implementation PreferencesWindowController (Private)

- (IBAction) toolbarItemSelected:(id)sender
{
	NSParameterAssert(nil != sender);
	NSParameterAssert([sender isKindOfClass:[NSToolbarItem class]]);
	
	NSToolbarItem *sendingToolbarItem = (NSToolbarItem *)sender;
	[self selectPreferencePaneWithIdentifier:[sendingToolbarItem itemIdentifier]];
}

@end
