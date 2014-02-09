//
//  MuleViewController.m
//  Mule
//
//  Created by Vince Allen on 2/7/14.
//  Copyright (c) 2014 Vince Allen. All rights reserved.
//

#import "MuleViewController.h"
#import "MuleCameraViewController.h"

@interface MuleViewController ()
@end

@implementation MuleViewController

@synthesize ble;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    ble = [[BLE alloc] init];
    [ble controlSetup];
    ble.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - BLE delegate

NSTimer *rssiTimer;

- (void)bleDidDisconnect
{
    NSLog(@"->Disconnected");
    
    [btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
    [indConnecting stopAnimating];
    
    [rssiTimer invalidate];
}

// When connected, this will be called
-(void) bleDidConnect
{
    NSLog(@"->Connected");
    
    [indConnecting stopAnimating];
    
    // send reset
    //UInt8 buf[] = {0x04, 0x00, 0x00};
    //NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    //[ble write:data];
    
    // Schedule to read RSSI every 1 sec.
    rssiTimer = [NSTimer scheduledTimerWithTimeInterval:(float)1.0 target:self selector:@selector(readRSSITimer:) userInfo:nil repeats:YES];
}

-(void) bleDidUpdateRSSI:(NSNumber *) rssi
{
    NSLog(@"BLE did update");
}

-(void) bleDidReceiveData:(unsigned char *) data length:(int) length
{
    NSLog(@"Did receive data");
}


-(void) readRSSITimer:(NSTimer *)timer
{
    [ble readRSSI];
}

// Connect button will call to this
- (IBAction)btnScanForPeripherals:(id)sender
{
    if (ble.activePeripheral)
        if(ble.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
            [btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
            return;
        }
    
    if (ble.peripherals)
        ble.peripherals = nil;
    
    [btnConnect setTitle:@"Connecting" forState:UIControlStateNormal];
    [btnConnect setEnabled:false];
    [ble findBLEPeripherals:3];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
    
    [indConnecting startAnimating];
}

-(void) connectionTimer:(NSTimer *)timer
{
    [btnConnect setEnabled:true];
    [btnConnect setTitle:@"Disconnect" forState:UIControlStateNormal];

    if (ble.peripherals.count > 0)
    {
        [ble connectPeripheral:[ble.peripherals objectAtIndex:0]];
        [self performSegueWithIdentifier:@"showCam" sender:self];
    }
    else
    {
        [self performSegueWithIdentifier:@"showCam" sender:self];
        [btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
        [indConnecting stopAnimating];
    }
}

// This will get called too before the view appears
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showCam"]) {
        
        NSLog(@"preparing seque!");
        
        // Get destination view
        MuleCameraViewController *vc = [segue destinationViewController];
        
        // Pass the information to your destination view
        [vc setBle:ble];
    }
}

@end
