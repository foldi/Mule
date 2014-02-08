//
//  MuleCameraViewController.h
//  Mule
//
//  Created by Vince Allen on 2/7/14.
//  Copyright (c) 2014 Vince Allen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MuleCameraViewController : UIViewController {
    BOOL started;
	CMTime frameDuration;
	CMTime nextPTS;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterInput;
	AVCaptureStillImageOutput *stillImageOutput;
	NSURL *outputURL;
}

@property (nonatomic, retain) IBOutlet UIView *previewView;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *startFinishButton;

- (IBAction)startStop:(id)sender;

@end
