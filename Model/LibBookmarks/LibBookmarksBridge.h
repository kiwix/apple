//
//  LibBookmarksBridge.h
//  Kiwix

#import <Foundation/Foundation.h>
#import "kiwix/library.h"
#import "kiwix/bookmark.h"
#import "LibBookmark.h"

@interface LibBookmarksBridge : NSObject

- (nonnull instancetype) init;
- (BOOL) isBookmarked: (nonnull NSURL *) url inZIM: (nonnull NSUUID *) zimFileID NS_REFINED_FOR_SWIFT;
- (void) add: (nonnull LibBookmark *) bookmark NS_REFINED_FOR_SWIFT;
- (void) remove: (nonnull LibBookmark *) bookmark NS_REFINED_FOR_SWIFT;

@end
