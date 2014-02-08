//
//  LEGIFExporter.m
//  LEGifExporter
//
//  Created by Julius Parishy on 2/8/14.
//  Copyright (c) 2014 jp. All rights reserved.
//

#import "LEGIFExporter.h"

#import "LEMovieFrameExporter.h"

#include <GIFLIB/gif_lib.h>

NSString *const LEGIFErrorDomain = @"GIFErrorDomain";

@interface LEGIFExporter ()

@property (nonatomic, strong) NSURL *sourceMovieURL;
@property (nonatomic, assign) GifFileType *file;

@property (nonatomic, strong) LEMovieFrameExporter *exporter;

@property (nonatomic, assign) ColorMapObject *palette;

@end

@implementation LEGIFExporter

- (instancetype)initWithMovieURL:(NSURL *)movieURL
{
    if((self = [super init]))
    {
        self.outputImageSize = CGSizeZero;
        self.framesPerSecond = 30.0;
        self.paletteSize = 256;
        
        self.sourceMovieURL = movieURL;
    }
    
    return self;
}

- (void)writeToOutputURL:(NSURL *)outputURL completion:(LEGIFExporterCompletionBlock)completion
{
    NSParameterAssert(outputURL);
    NSAssert(outputURL.isFileURL, @"outputURL must be a fileURL");
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        __strong typeof(self) strongSelf = weakSelf;
        
        NSError *error = nil;
        
        NSString *path = outputURL.path;
        if(![strongSelf openOutputFileWithPath:path error:&error])
        {
            completion(error);
            return;
        }
        
        __block BOOL shouldWriteHeaders = YES;
        
        __weak typeof(self) weakSelf = self;
        strongSelf.exporter = [[LEMovieFrameExporter alloc] initWithMovieURL:strongSelf.sourceMovieURL exportedBlock:^(NSInteger width, NSInteger height, void *frameData) {
            
            __strong typeof(self) strongSelf = weakSelf;
            
            [strongSelf writeFrameWithWidth:width height:height data:frameData shouldWriteHeaders:shouldWriteHeaders];
            
            if(shouldWriteHeaders)
            {
                shouldWriteHeaders = NO;
            }
        }];
        
        if(![strongSelf.exporter exportFrames:&error])
        {
            completion(error);
            return;
        }
        
        EGifCloseFile(strongSelf.file);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            completion(nil);
        });
    });
}

- (NSError *)genericError
{
    NSString *localizedDescription = NSLocalizedString(@"A generic GIF error occurred", nil);
    return [NSError errorWithDomain:LEGIFErrorDomain code:LEGIFErrorGeneric userInfo:@{
        
        NSLocalizedDescriptionKey : localizedDescription
    }];
}

- (NSError *)errorFromGIFError:(int)gifError
{
    const char *description = GifErrorString(gifError);
    NSString *localizedDescription = [NSString stringWithCString:description encoding:NSASCIIStringEncoding];
    
    return [NSError errorWithDomain:LEGIFErrorDomain code:gifError userInfo:@{
        
        NSLocalizedDescriptionKey : localizedDescription
    }];
}

- (BOOL)openOutputFileWithPath:(NSString *)path error:(NSError **)error
{
    const char *filename = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    int openError = 0;
    self.file = EGifOpenFileName(filename, NO, &openError);
    
    if(openError)
    {
        *error = [self errorFromGIFError:openError];
        return NO;
    }
    
    return YES;
}

- (BOOL)writeScreenDescriptionWithError:(NSError **)error
{
    int width = self.outputImageSize.width;
    int height = self.outputImageSize.height;
    
    int colorResolution = 8;
    int background = 0;
    
    int gifError = EGifPutScreenDesc(self.file, width, height, colorResolution, background, self.palette);
    if(gifError == GIF_ERROR)
    {
        *error = [self genericError];
        return NO;
    }
    
    return YES;
}

- (BOOL)writeLoopExtensionWithError:(NSError **)error
{
    char *netscapeExtension = "NETSCAPE2.0";
    EGifPutExtensionLeader(self.file, APPLICATION_EXT_FUNC_CODE);
    EGifPutExtensionBlock(self.file, strlen(netscapeExtension), netscapeExtension);

    char loopBlock[3] = { 1, 0, 0 };
    EGifPutExtensionBlock(self.file, 3, loopBlock);
    EGifPutExtensionTrailer(self.file);
    
    return YES;
}

- (void)writeRGBData:(unsigned char *)data width:(NSInteger)width height:(NSInteger)height
{
    unsigned char controlExtension[4] = { 0x04, 0x00, 0x00, 0xff };
    
    NSInteger delay = (1.0f / self.framesPerSecond) * 100;
    controlExtension[1] = delay % 256;
    controlExtension[2] = delay / 256;
    
    EGifPutExtension(self.file, GRAPHICS_EXT_FUNC_CODE, 4, controlExtension);
    EGifPutImageDesc(self.file, 0, 0, width, height, 0, NULL);
    
    for(int i = 0; i < height; ++i)
    {
        unsigned char *line = &data[(i * width * 3)];
        EGifPutLine(self.file, line, width * 3);
    }
}

- (void)writeFrameWithWidth:(NSInteger)width height:(NSInteger)height data:(void *)data shouldWriteHeaders:(BOOL)shouldWriteHeaders
{
    NSInteger rgbLength = width * height * 3;
    unsigned char *rgb = [self rgbDataFromBGRAData:data width:width height:height];
    
    if(shouldWriteHeaders)
    {
        self.palette = GifMakeMapObject(self.paletteSize, NULL);
    
        int paletteSize = self.paletteSize;
        
        NSInteger length = width * height;
        
        unsigned char *red   = calloc(sizeof(unsigned char), length);
        unsigned char *green = calloc(sizeof(unsigned char), length);
        unsigned char *blue  = calloc(sizeof(unsigned char), length);
        
        [self deinterlaceData:rgb length:length red:red green:green blue:blue];
        
        unsigned char *output = calloc(sizeof(unsigned char), rgbLength);
        int gifError = GifQuantizeBuffer(width, height, &paletteSize, red, green, blue, output, self.palette->Colors);
        
        if(gifError == GIF_ERROR)
        {
            NSLog(@"Failed to quantize buffer");
        }
        
        self.paletteSize = paletteSize;
        self.outputImageSize = CGSizeMake(width, height);
            
        NSError *error = nil;
        
        [self writeScreenDescriptionWithError:&error];
        [self writeLoopExtensionWithError:&error];
        
        [self writeRGBData:output width:width height:height];
        
        free(red);
        free(green);
        free(blue);
        
        free(output);
    }
    else
    {
        unsigned char *frame = [self closestRGBWithData:rgb width:width height:height];
    
        [self writeRGBData:frame width:width height:height];
        
        free(frame);
    }
    
    free(rgb);
}

- (unsigned char *)rgbDataFromBGRAData:(unsigned char *)bgraData width:(NSInteger)width height:(NSInteger)height
{
    unsigned char *rgbData = calloc(sizeof(unsigned char), width * height * 3);
    
    for(NSInteger i = 0; i < height; ++i)
    {
        for(NSInteger j = 0; j < width; ++j)
        {
            NSInteger bgraIndex = (width * 4 * i) + (j * 4);
            NSInteger rgbIndex  = (width * 3 * i) + (j * 3);
            
            rgbData[rgbIndex + 0] = bgraData[bgraIndex + 2];
            rgbData[rgbIndex + 1] = bgraData[bgraIndex + 1];
            rgbData[rgbIndex + 2] = bgraData[bgraIndex + 0];
        }
    }
    
    return rgbData;
}

- (void)deinterlaceData:(unsigned char *)data length:(NSInteger)length red:(unsigned char *)red green:(unsigned char *)green blue:(unsigned char *)blue
{
    NSInteger j = 0;
    
    for(NSInteger i = 0; i < length; ++i)
    {
        blue[i]  = data[j++];
        green[i] = data[j++];
        red[i]   = data[j++];
    }
}

- (unsigned char *)closestRGBWithData:(unsigned char *)data width:(NSInteger)width height:(NSInteger)height
{
    NSInteger length = width * height;
    
    unsigned char *output = calloc(sizeof(unsigned char), length * 3);
    
    int j = 0;
    for(int i = 0; i < length; i++)
    {
        int minIndex = 0;
        int minDist = 3 * 256 * 256;
        
        GifColorType *c = self.palette->Colors;

        /* Find closest color in first color map to this color. */
        for (int k = 0; k < self.palette->ColorCount; k++)
        {
            int dr = c[k].Red   - data[j + 0];
            int dg = c[k].Green - data[j + 1];
            int db = c[k].Blue  - data[j + 2];

            int dist = dr * dr + dg * dg + db * db;

            if(minDist > dist)
            {
                minDist  = dist;
                minIndex = k;
            }
        }
        
        j += 3;
        output[i] = minIndex;
    }
    
    return output;
}

@end
