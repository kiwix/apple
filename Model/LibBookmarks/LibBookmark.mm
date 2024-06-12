//
//  LibBookmark.m
//  Kiwix

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#include "kiwix/bookmark.h"
#include "kiwix/book.h"
#include "zim/archive.h"
#pragma clang diagnostic pop

#import <Foundation/Foundation.h>
#import "LibBookmark.h"
#import "ZimFileService.h"

@interface LibBookmark()
@property (nonatomic, strong) NSURL *_Nonnull url;
@property (nonatomic, strong) NSUUID *_Nonnull zimFileID;
@end

@implementation LibBookmark

- (instancetype) init: (NSURL *) url inZIM: (NSUUID *) zimFileID withTitle: (nonnull NSString *) title{
    self = [super init];
    if (self) {
        self.url = url;
        self.zimFileID = zimFileID;
        self.zimID_c = [[[zimFileID UUIDString] lowercaseString] cStringUsingEncoding:NSUTF8StringEncoding];
        self.url_c = [url fileSystemRepresentation];
        self.title_c = [title cStringUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

- (kiwix::Book) book {
    return [ZimFileService.sharedInstance getBookBy: self.zimFileID];
}

@end
