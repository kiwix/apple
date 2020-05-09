//
//  SearchOperation.mm
//  Kiwix
//
//  Created by Chris Li on 5/9/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

#import "SearchOperation.h"
#import "SearchResult.h"
#import "ZimMultiReader.h"
#import "reader.h"
#import "searcher.h"

struct SharedReaders {
    NSArray *readerIDs;
    std::vector<std::shared_ptr<kiwix::Reader>> readers;
};

@interface SearchOperation ()

@property (strong) NSString *searchText;
@property (strong) NSSet *identifiers;

@end

@implementation SearchOperation

- (id)initWithSearchText:(NSString *)searchText zimFileIDs:(NSSet *)identifiers {
    self = [super init];
    if (self) {
        self.searchText = searchText;
        self.identifiers = identifiers;
        self.results = @[];
    }
    return self;
}

- (void)main {
    struct SharedReaders sharedReaders = [[ZimMultiReader shared] getSharedReaders:self.identifiers];
    NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:20];
    
    // initialize kiwix::Search
    kiwix::Searcher searcher = kiwix::Searcher();
    for (auto iter: sharedReaders.readers) {
        searcher.add_reader(iter.get());
    }
    
    // start search
    if (self.isCancelled) { return; }
    searcher.search([self.searchText cStringUsingEncoding:NSUTF8StringEncoding], 0, 20);
    
    // retrieve search results
    kiwix::Result *result = searcher.getNextResult();
    while (result != NULL) {
        NSString *zimFileID = sharedReaders.readerIDs[result->get_readerIndex()];
        NSString *path = [NSString stringWithCString:result->get_url().c_str() encoding:NSUTF8StringEncoding];
        NSString *title = [NSString stringWithCString:result->get_title().c_str() encoding:NSUTF8StringEncoding];
        SearchResult *searchResult = [[SearchResult alloc] initWithZimFileId:zimFileID path:path title:title];
        
        if (self.extractSnippet) {
            searchResult.snippet = [NSString stringWithCString:result->get_snippet().c_str()
                                                      encoding:NSUTF8StringEncoding];
        }
        
        if (searchResult != nil) {
            [results addObject:searchResult];
        }
        
        delete result;
        result = searcher.getNextResult();
        if (self.isCancelled) { break; }
    }
    
    self.results = results;
}

@end
