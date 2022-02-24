//
//  SearchOperation.mm
//  Kiwix
//
//  Created by Chris Li on 5/9/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import "kiwix/reader.h"
#import "kiwix/searcher.h"
#import "zim/suggestion.h"
#pragma clang diagnostic pop

#import "SearchOperation.h"
#import "SearchResult.h"
#import "ZimFileService.h"

struct SharedReaders {
    NSArray *readerIDs;
    std::vector<std::shared_ptr<kiwix::Reader>> readers;
    std::vector<zim::Archive> archives;
};

@interface SearchOperation ()

@property (nonatomic, strong) NSSet *identifiers;

@end

@implementation SearchOperation

- (id)initWithSearchText:(NSString *)searchText zimFileIDs:(NSSet *)identifiers {
    self = [super init];
    if (self) {
        self.searchText = searchText;
        self.identifiers = identifiers;
        self.snippetMode = @"disabled";
        self.results = [[NSMutableOrderedSet alloc] initWithCapacity:35];
        self.qualityOfService = NSQualityOfServiceUserInitiated;
    }
    return self;
}

/// Perform index and title based searches.
- (void)performSearch {
    struct SharedReaders sharedReaders = [[ZimFileService sharedInstance] getSharedReaders:self.identifiers];
    [self addIndexSearchResults:sharedReaders.archives];
    
    int archivesCount = (int)sharedReaders.archives.size();
    if (archivesCount > 0) {
        int count = std::max((35 - (int)[self.results count]) / archivesCount, 5);
        [self addTitleSearchResults:sharedReaders.archives count:(int)count];
    }
}

/// Add search results based on search index.
/// @param archives archives to retrieve search results from
- (void)addIndexSearchResults:(std::vector<zim::Archive>)archives {
    // initialize and start full text search
    if (self.isCancelled) { return; }
    zim::Searcher searcher = zim::Searcher(archives);
    zim::Query query = zim::Query([self.searchText cStringUsingEncoding:NSUTF8StringEncoding]);
    zim::SearchResultSet resultSet = searcher.search(query).getResults(0, 25);
    
    // retrieve full text search results
    for (auto result = resultSet.begin(); result != resultSet.end(); result++) {
        if (self.isCancelled) { break; }
        
        zim::Item item = result->getRedirect();
        NSUUID *zimFileID = [[NSUUID alloc] initWithUUIDBytes:(unsigned char *)result.getZimId().data];
        NSString *path = [NSString stringWithCString:item.getPath().c_str() encoding:NSUTF8StringEncoding];
        NSString *title = [NSString stringWithCString:item.getTitle().c_str() encoding:NSUTF8StringEncoding];
        SearchResult *searchResult = [[SearchResult alloc] initWithZimFileID:[zimFileID UUIDString] path:path title:title];
        searchResult.probability = [[NSNumber alloc] initWithFloat:result.getScore() / 100];
        
        // optionally, add snippet
        if ([self.snippetMode isEqual: @"matches"]) {
            NSString *html = [NSString stringWithCString:result.getSnippet().c_str() encoding:NSUTF8StringEncoding];
            searchResult.htmlSnippet = html;
        }
        
        if (searchResult != nil) { [self.results addObject:searchResult]; }
    }
}

/// Add search results based on matching article titles with search text.
/// @param archives archives to retrieve search results from
/// @param count number of articles to retrieve for each archive
- (void)addTitleSearchResults:(std::vector<zim::Archive>)archives count:(int)count {
    std::string searchTextC = [self.searchText cStringUsingEncoding:NSUTF8StringEncoding];
    
    for (zim::Archive archive: archives) {
        if (self.isCancelled) { break; }
        
        NSUUID *zimFileID = [[NSUUID alloc] initWithUUIDBytes:(unsigned char *)archive.getUuid().data];
        auto results = zim::SuggestionSearcher(archive).suggest(searchTextC).getResults(0, count);
        for (auto result = results.begin(); result != results.end(); result++) {
            if (self.isCancelled) { break; }
            
            zim::Item item = result.getEntry().getRedirect();
            NSString *path = [NSString stringWithCString:item.getPath().c_str() encoding:NSUTF8StringEncoding];
            NSString *title = [NSString stringWithCString:item.getTitle().c_str() encoding:NSUTF8StringEncoding];
            SearchResult *searchResult = [[SearchResult alloc] initWithZimFileID:[zimFileID UUIDString] path:path title:title];
            if (searchResult != nil) { [self.results addObject:searchResult]; }
        }
    }
}

@end
