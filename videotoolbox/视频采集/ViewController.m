//
//  ViewController.m
//  视频采集
//
//  Created by  luzhaoyang on 17/7/25.
//  Copyright © 2017年 Kingstong. All rights reserved.
//


// 真及调试的时候可能会崩溃  https://stackoverflow.com/questions/38600326/cmpedometer-sigabrt-crash-ios-10

#import "ViewController.h"
#import "VideoCapture.h"
#import "ToolBoxVC.h"


@interface ViewController ()

@property(nonatomic , strong) VideoCapture *videoCapture;

@end

@implementation ViewController

- (VideoCapture *)videoCapture
{
    if (_videoCapture == nil) {
        _videoCapture = [[VideoCapture alloc]init];
    }
    return _videoCapture;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)startCaptureAc:(id)sender {
     [self.videoCapture starCapturing:self.view];
}

- (IBAction)stopCaptureAc:(id)sender {
    [self.videoCapture stopCapturing];
}

- (IBAction)goToolBox:(id)sender {
    ToolBoxVC *VC = [[ToolBoxVC alloc]init];
    [self presentViewController:VC animated:YES completion:nil];
}



@end
