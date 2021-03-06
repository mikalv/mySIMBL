//
//  pluginTable.m
//  TableTest
//
//  Created by Wolfgang Baird on 3/12/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

@import AppKit;
#import "shareClass.h"
#import "pluginData.h"
#import "MSPlugin.h"

extern NSMutableArray *confirmDelete;
extern NSMutableArray *pluginsArray;
NSInteger previusRow = -1;

@interface pluginTable : NSObject
{
    shareClass *_sharedMethods;
    pluginData *_pluginData;
}
@property (weak) IBOutlet NSTableView*  tblView;
@property NSMutableArray *tableContent;
@end

@interface CustomTableCell : NSTableCellView <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSButton*     pluginDelete;
@property (weak) IBOutlet NSButton*     pluginWeb;
@property (weak) IBOutlet NSButton*     pluginUserLoc;
@property (weak) IBOutlet NSButton*     pluginStatus;
@property (weak) IBOutlet NSTextField*  pluginName;
@property (weak) IBOutlet NSTextField*  pluginDescription;
@property (weak) IBOutlet NSImageView*  pluginImage;
@property (weak) IBOutlet NSString*     pluginID;
@end

@implementation pluginTable

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (_sharedMethods == nil)
        _sharedMethods = [shareClass alloc];
    
    _pluginData = [pluginData sharedInstance];
    [_pluginData fetch_local];
    
    NSSortDescriptor *sorter = [[NSSortDescriptor alloc] initWithKey:@"localName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *dank = [[NSMutableArray alloc] initWithArray:[_pluginData.localPluginsDic allValues]];
    _tableContent = [[dank sortedArrayUsingDescriptors:@[sorter]] copy];
    
    return _tableContent.count;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([[pboard types] containsObject:NSURLPboardType])
    {
        NSArray* urls = [pboard readObjectsForClasses:@[[NSURL class]] options:nil];
        NSMutableArray* sorted = [[NSMutableArray alloc] init];
        for (NSURL* url in urls)
        {
            if ([[url.path pathExtension] isEqualToString:@"bundle"])
            {
                [sorted addObject:url.path];
            }
        }
        if ([sorted count])
        {
            NSArray* installArray = [NSArray arrayWithArray:sorted];
            [_sharedMethods installBundles:installArray];
        }
    }
    return YES;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    CustomTableCell *result = (CustomTableCell*)[tableView makeViewWithIdentifier:@"MyView" owner:self];
    MSPlugin *aBundle = [_tableContent objectAtIndex:row];
    
    result.pluginName.stringValue = aBundle.localName;
    if([aBundle.localPath length]) {
        NSString *path = aBundle.localPath;
//        NSArray *components = [path pathComponents];
        if ([path rangeOfString:@"Disabled"].length) {
            [result.pluginStatus setImage:[NSImage imageNamed:@"NSStatusUnavailable"]];
        } else {
            [result.pluginStatus setImage:[NSImage imageNamed:@"NSStatusAvailable"]];
        }
        NSArray *components = [path pathComponents];
        if ([components[1] isEqualToString:@"Library"]) {
            [result.pluginUserLoc setState:NSOffState];
            [result.pluginUserLoc setImage:[NSImage imageNamed:@"NSUserGroup"]];
        } else {
            [result.pluginUserLoc setState:NSOnState];
            [result.pluginUserLoc setImage:[NSImage imageNamed:@"NSUser"]];
        }
    }
    
    result.pluginDescription.stringValue = aBundle.localDescription;
    result.pluginImage.image = [_pluginData fetch_icon:aBundle];
    
    [result.pluginDelete setImage:[NSImage imageNamed:@"NSTrashEmpty"]];
    
    if ([[confirmDelete objectAtIndex:row] boolValue])
        [result.pluginDelete setImage:[NSImage imageNamed:@"NSTrashFull"]];
    else
        [result.pluginDelete setImage:[NSImage imageNamed:@"NSTrashEmpty"]];
    
    [result.pluginWeb setImage:[NSImage imageNamed:@"webicon.png"]];
    [[result.pluginWeb cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    [result.pluginWeb setEnabled:true];
    [result.pluginWeb setHidden:true];
    
    // Return the result
    return result;
}

- (IBAction)pluginWebpage:(id)sender {
    NSTableView *t = (NSTableView*)[[[sender superview] superview] superview];
    NSDictionary* obj = [pluginsArray objectAtIndex:[t rowForView:sender]];
    NSString* webURL = [[obj objectForKey:@"bundleInfo"] objectForKey:@"DevURL"];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:webURL]];
}

- (IBAction)pluginFinder:(id)sender {
    NSTableView *t = (NSTableView*)[[[sender superview] superview] superview];
    NSDictionary* obj = [pluginsArray objectAtIndex:[t rowForView:sender]];
    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:[obj valueForKey:@"path"]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[NSArray arrayWithObject:fileURL]];
}

- (IBAction)pluginLocToggle:(id)sender {
    NSTableView *t = (NSTableView*)[[[sender superview] superview] superview];
    long selected = [t rowForView:sender];
    CustomTableCell *cell = (CustomTableCell*)[sender superview];
    [cell.pluginUserLoc setNextState];
    
    NSDictionary* obj = [pluginsArray objectAtIndex:selected];
    NSString* name = [obj objectForKey:@"name"];
    NSString* path = [obj objectForKey:@"path"];
    
    NSArray* libDomain = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSLocalDomainMask];
    NSArray* usrDomain = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    NSString* libSupport = [[libDomain objectAtIndex:0] path];
    NSString* usrSupport = [[usrDomain objectAtIndex:0] path];
    
    NSString* disPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins (Disabled)/%@.bundle", libSupport, name];
    NSString* libPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins/%@.bundle", libSupport, name];
    if (cell.pluginUserLoc.state == NSOffState) {
        disPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins (Disabled)/%@.bundle", usrSupport, name];
        libPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins/%@.bundle", usrSupport, name];
    }
    
    if ([path rangeOfString:@"Disabled"].length)
        [_sharedMethods replaceFile:path :disPath];
    else
        [_sharedMethods replaceFile:path :libPath];
    
    [_sharedMethods readPlugins:_tblView];
}

- (IBAction)pluginToggle:(id)sender {
    NSTableView *t = (NSTableView*)[[[sender superview] superview] superview];
    long selected = [t rowForView:sender];
    CustomTableCell *cell = (CustomTableCell*)[sender superview];
    
    NSDictionary* obj = [pluginsArray objectAtIndex:selected];
    NSString* name = [obj objectForKey:@"name"];
    NSString* path = [obj objectForKey:@"path"];
    
    NSArray* libDomain = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSLocalDomainMask];
    NSArray* usrDomain = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    NSString* libSupport = [[libDomain objectAtIndex:0] path];
    NSString* usrSupport = [[usrDomain objectAtIndex:0] path];
    
    NSString* disPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins (Disabled)/%@.bundle", libSupport, name];
    NSString* libPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins/%@.bundle", libSupport, name];
    if (cell.pluginUserLoc.state) {
        disPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins (Disabled)/%@.bundle", usrSupport, name];
        libPath = [NSString stringWithFormat:@"%@/SIMBL/Plugins/%@.bundle", usrSupport, name];
    }
    
    if ([[obj objectForKey:@"path"] isEqualToString:disPath])
        [_sharedMethods replaceFile:path :libPath];
    else
        [_sharedMethods replaceFile:path :disPath];
    
    [_sharedMethods readPlugins:_tblView];
}

- (IBAction)pluginDelete:(id)sender {
    NSTableView *t = _tblView;
    long selected = [t selectedRow];
    if ([[confirmDelete objectAtIndex:selected] boolValue]) {
        NSDictionary* obj = [pluginsArray objectAtIndex:selected];
        NSString* path = [obj objectForKey:@"path"];
        NSURL* url = [NSURL fileURLWithPath:path];
        NSURL* trash;
        NSError* error;
        [[NSFileManager defaultManager] trashItemAtURL:url resultingItemURL:&trash error:&error];
    }
    [confirmDelete setObject:[NSNumber numberWithBool:true] atIndexedSubscript:selected];
}

@end

@implementation CustomTableCell
@end

