//
//  ZimFileService.h
//  Kiwix
//
//  Created by Chris Li on 8/17/17.
//  Copyright © 2017-2022 Chris Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZimFileMetaData.h"

struct SharedReaders;

@interface ZimFileService : NSObject

- (instancetype _Nonnull)init NS_REFINED_FOR_SWIFT;
+ (nonnull ZimFileService *)sharedInstance NS_REFINED_FOR_SWIFT;

#pragma mark - Reader Management

- (void)open:(NSURL *_Nonnull)url NS_REFINED_FOR_SWIFT;
- (void)close:(NSUUID *_Nonnull)zimFileID NS_REFINED_FOR_SWIFT;
- (NSArray *_Nonnull)getReaderIdentifiers NS_REFINED_FOR_SWIFT;
- (struct SharedReaders)getSharedReaders:(nonnull NSSet *)identifiers NS_REFINED_FOR_SWIFT;

# pragma mark - Metadata

- (nullable ZimFileMetaData *)getMetaData:(nonnull NSUUID *)identifier NS_REFINED_FOR_SWIFT;
+ (nullable ZimFileMetaData *)getMetaDataWithFileURL:(nonnull NSURL *)url NS_REFINED_FOR_SWIFT;

# pragma mark - URL Handling

- (NSURL *_Nullable)getFileURL:(NSUUID *_Nonnull)zimFileID NS_REFINED_FOR_SWIFT;
- (NSString *_Nullable)getRedirectedPath:(NSUUID *_Nonnull)zimFileID contentPath:(NSString *_Nonnull)contentPath NS_REFINED_FOR_SWIFT;
- (NSString *_Nullable)getMainPagePath:(NSUUID *_Nonnull)zimFileID NS_REFINED_FOR_SWIFT;
- (NSString *_Nullable)getRandomPagePath:(NSUUID *_Nonnull)zimFileID NS_REFINED_FOR_SWIFT;
- (NSDictionary *_Nullable)getContent:(NSUUID *_Nonnull)zimFileID contentPath:(NSString *_Nonnull)contentPath NS_REFINED_FOR_SWIFT;

@end
