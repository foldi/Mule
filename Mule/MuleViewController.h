//
//  MuleViewController.h
//  Mule
//
//  Created by Vince Allen on 2/7/14.
//  Copyright (c) 2014 Vince Allen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLE.h"

@interface MuleViewController : UIViewController <BLEDelegate>
{
    IBOutlet UIButton *btnConnect;
    IBOutlet UIActivityIndicatorView *indConnecting;
}

@property (strong, nonatomic) BLE *ble;

@end
