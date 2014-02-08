//
//  LEMovieFrameExporter.m
//  LEGifExporter
//
//  Created by Julius Parishy on 2/8/14.
//  Copyright (c) 2014 jp. All rights reserved.
//

#import "LEMovieFrameExporter.h"

@import AVFoundation;

NSString *const LEMovieFrameExporterErrorDomain = @"LEMovieFrameExporterErrorDomain";

@interface LEMovieFrameExporter ()

@property (nonatomic, strong) NSURL *movieURL;
@property (nonatomic, copy) LEMovieFrameExportedBlock exportedBlock;

@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVAssetReader *assetReader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;

@end

@implementation LEMovieFrameExporter

- (instancetype)initWithMovieURL:(NSURL *)movieURL exportedBlock:(LEMovieFrameExportedBlock)exportedBlock
{
    if((self = [super init]))
    {
        self.movieURL = movieURL;
        self.exportedBlock = exportedBlock;
    }
    
    return self;
}

- (BOOL)exportFrames:(NSError **)outError
{
    self.asset = [AVAsset assetWithURL:self.movieURL];
    
    NSError *error = nil;
    self.assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
    if(error)
    {
        *outError = error;
        return NO;
    }
    
    NSArray *allVideoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    if(allVideoTracks.count == 0)
    {
        *outError = [NSError errorWithDomain:LEMovieFrameExporterErrorDomain code:0 userInfo:@{
            
            NSLocalizedDescriptionKey : NSLocalizedString(@"Asset does not include a video track", nil)
        }];
        
        return NO;
    }
    
    AVAssetTrack *track = [allVideoTracks firstObject];
    
    NSDictionary *outputSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
    };
    
    self.output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
    
    [self.assetReader addOutput:self.output];
    [self.assetReader startReading];
    
    CMSampleBufferRef sampleBuffer = NULL;
    
    do
    {
    /*
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
        if(image)
        {
            NSLog(@"Copied frame: %@", NSStringFromCGSize(image.size));
            NSData *data = UIImageJPEGRepresentation(image, 1.0f);
            
            NSString *file = [NSString stringWithFormat:@"/Users/jp/Desktop/test/frame_%05d.jpg", index++];
            [data writeToFile:file atomically:YES];
        }
        */
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
     
        // Get the number of bytes per row for the pixel buffer
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
     
        // Get the pixel buffer width and height
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        if(width > 0 && height > 0)
        {
            self.exportedBlock(width, height, baseAddress);
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
    } while((sampleBuffer = [self.output copyNextSampleBuffer]) != NULL);
    
    return YES;
}

- (void)finishExporting
{

}

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
 
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
 
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
 
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
 
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
      bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    if(!context)
    {
        return nil;
    }
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
 
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
 
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
 
    // Release the Quartz image
    CGImageRelease(quartzImage);
 
    return (image);
}

@end
