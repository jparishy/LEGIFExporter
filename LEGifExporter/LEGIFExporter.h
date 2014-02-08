//
//  LEGIFExporter.h
//  LEGifExporter
//
//  Created by Julius Parishy on 2/8/14.
//  Copyright (c) 2014 jp. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^LEGIFExporterCompletionBlock)(NSError *error);

typedef NS_ENUM(NSInteger, LEGIFError)
{
    LEGIFErrorGeneric
};

@interface LEGIFExporter : NSObject

@property (nonatomic, assign) CGSize outputImageSize;

@property (nonatomic, assign) NSTimeInterval framesPerSecond;
@property (nonatomic, assign) NSInteger paletteSize;

- (instancetype)initWithMovieURL:(NSURL *)movieURL;

- (void)writeToOutputURL:(NSURL *)outputURL completion:(LEGIFExporterCompletionBlock)completion;

@end
