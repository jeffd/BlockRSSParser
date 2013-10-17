//
//  RSSParser.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"
#import "NSString+HTML.h"

static dispatch_queue_t rssparser_success_callback_queue() {
    static dispatch_queue_t parser_success_callback_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser_success_callback_queue = dispatch_queue_create("rssparser.success_callback.processing", DISPATCH_QUEUE_CONCURRENT);
    });

    return parser_success_callback_queue;
}

@implementation RSSParser

#pragma mark lifecycle
- (id)init {
    self = [super init];
    if (self) {
        items = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark -

#pragma mark parser

+ (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                       success:(void (^)(NSArray *feedItems))success
                       failure:(void (^)(NSError *error))failure
{
    RSSParser *parser = [[RSSParser alloc] init];
    [parser parseRSSFeedForRequest:urlRequest success:success failure:failure];
}


- (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                                          success:(void (^)(NSArray *feedItems))success
                                          failure:(void (^)(NSError *error))failure
{
    
    block = [success copy];
    
    AFXMLRequestOperation *operation = [RSSParser XMLParserRequestOperationWithRequest:urlRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        [XMLParser setDelegate:self];
        [XMLParser parse];
        

    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParse) {
        failure(error);
    }];

    [operation setSuccessCallbackQueue:rssparser_success_callback_queue()];

    [operation start];
}

#pragma mark -

#pragma mark AFNetworking AFXMLRequestOperation acceptable Content-Type overwriting

+ (NSSet *)defaultAcceptableContentTypes {
    return [NSSet setWithObjects:@"application/xml", @"text/xml",@"application/rss+xml", @"application/atom+xml", nil];
}
+ (NSSet *)acceptableContentTypes {
    return [self defaultAcceptableContentTypes];
}
#pragma mark -

#pragma mark NSXMLParser delegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        currentItem = [[RSSItem alloc] init];
    }
    
    tmpString = [[NSMutableString alloc] init];
    
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{    
    if ([elementName isEqualToString:@"item"]) {
        [items addObject:currentItem];
    }
    if (currentItem != nil && tmpString != nil) {
        
        if ([elementName isEqualToString:@"title"]) {
            NSString *noNewlineTitle = [[tmpString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
            NSString *noTrailingWhitespaceTitle = [noNewlineTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [currentItem setTitle:noTrailingWhitespaceTitle];
        }
        
        if ([elementName isEqualToString:@"description"] || [elementName isEqualToString:@"content"]) {
            NSString *desc = [tmpString stringByConvertingHTMLToPlainText];
            NSString *noNewlineArticle = [[desc componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
            NSString *noTrailingWhitespaceArticle = [noNewlineArticle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [currentItem setItemDescription:noTrailingWhitespaceArticle];
        }
        
        if ([elementName isEqualToString:@"content:encoded"]) {
            [currentItem setContent:tmpString];
        }
        
        if ([elementName isEqualToString:@"link"]) {
            [currentItem setLink:[NSURL URLWithString:tmpString]];
        }
        
        if ([elementName isEqualToString:@"comments"]) {
            [currentItem setCommentsLink:[NSURL URLWithString:tmpString]];
        }
        
        if ([elementName isEqualToString:@"wfw:commentRss"]) {
            [currentItem setCommentsFeed:[NSURL URLWithString:tmpString]];
        }
        
        if ([elementName isEqualToString:@"slash:comments"]) {
            [currentItem setCommentsCount:[NSNumber numberWithInt:[tmpString intValue]]];
        }
        
        if ([elementName isEqualToString:@"pubDate"]) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

            NSLocale *local = [[NSLocale alloc] initWithLocaleIdentifier:@"en_EN"];
            [formatter setLocale:local];
          
            [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
            
            [currentItem setPubDate:[formatter dateFromString:tmpString]];
        }

        if ([elementName isEqualToString:@"dc:creator"]) {
            [currentItem setAuthor:tmpString];
        }
        
        if ([elementName isEqualToString:@"guid"]) {
            [currentItem setGuid:tmpString];
        }
    }
    
    if ([elementName isEqualToString:@"rss"] || [elementName isEqualToString:@"feed"]) {
        block(items);
    }
    
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [tmpString appendString:string];
    
}

#pragma mark -

@end
