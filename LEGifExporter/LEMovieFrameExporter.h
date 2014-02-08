//
//  LEMovieFrameExporter.h
//  LEGifExporter
//
//  Created by Julius Parishy on 2/8/14.
//  Copyright (c) 2014 jp. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^LEMovieFrameExportedBlock)(NSInteger width, NSInteger height, void *frameData);

@interface LEMovieFrameExporter : NSObject

- (instancetype)initWithMovieURL:(NSURL *)movieURL exportedBlock:(LEMovieFrameExportedBlock)exportedBlock;

- (BOOL)exportFrames:(NSError **)error;

@end
