//
//  LEViewController.m
//  LEGifExporter
//
//  Created by Julius Parishy on 2/8/14.
//  Copyright (c) 2014 jp. All rights reserved.
//

#import "LEViewController.h"

#import "LEGIFExporter.h"

@interface LEViewController ()

@end

@implementation LEViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSURL *url = [NSURL fileURLWithPath:@"/Users/jp/Desktop/test.mov"];
    LEGIFExporter *exporter = [[LEGIFExporter alloc] initWithMovieURL:url];
    exporter.framesPerSecond = 24.0;
    
    NSURL *outputURL = [NSURL fileURLWithPath:@"/Users/jp/Desktop/test.gif"];
    
    NSLog(@"Exporting...");
    NSDate *start = [NSDate date];
    
    [exporter writeToOutputURL:outputURL completion:^(NSError *error) {
        
        if(error)
        {
            NSLog(@"Error: %@", error);
        }
        else
        {
            NSDate *end = [NSDate date];
            NSLog(@"Finished (duration: %f seconds)", [end timeIntervalSinceDate:start]);
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
