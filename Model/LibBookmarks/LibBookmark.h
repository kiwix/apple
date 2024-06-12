//
//  LibBookmark.h
//  Kiwix

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LibBookmark : NSObject

@property std::string zimID_c;
@property std::string url_c;
@property std::string title_c;

- (nonnull instancetype) init: (nonnull NSURL *) url inZIM: (nonnull NSUUID *) zimFileID withTitle: (nonnull NSString *) title;

//- (const kiwix::Bookmark&) bridged;
- (kiwix::Book) book;

NS_ASSUME_NONNULL_END

@end
