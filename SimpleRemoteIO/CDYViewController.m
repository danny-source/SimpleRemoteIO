//
//  CDYViewController.m
//  SimpleRemoteIO
//
//  Created by danny on 2014/4/14.
//  Copyright (c) 2014年 danny. All rights reserved.
//

#import "CDYViewController.h"
#import <AVFoundation/AVFoundation.h>



@interface CDYViewController ()
{
    AVAudioSession *audioSession;
    AUGraph auGraph;
    AudioUnit remoteIOUnit;
    AUNode remoteIONode;
    AURenderCallbackStruct inputProc;
    BOOL isMute;

}

@end

@implementation CDYViewController

//
static OSStatus	PerformThru(
							void						*inRefCon,
							AudioUnitRenderActionFlags 	*ioActionFlags,
							const AudioTimeStamp 		*inTimeStamp,
							UInt32 						inBusNumber,
							UInt32 						inNumberFrames,
							AudioBufferList 			*ioData)
{
    CDYViewController *THIS=(__bridge CDYViewController*)inRefCon;
    
    OSStatus renderErr = AudioUnitRender(THIS->remoteIOUnit, ioActionFlags,
                                         inTimeStamp, 1, inNumberFrames, ioData);
    
    if (THIS->isMute == YES){
        //Clear two channel mData
        for (UInt32 i=0; i < ioData->mNumberBuffers; i++)
        {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
    }
    
	if (renderErr < 0) {
		return renderErr;
	}


    return noErr;
}




//
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    isMute = NO;
    [self initRemoteIO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) initRemoteIO
{
    audioSession = [AVAudioSession sharedInstance];
    
    NSError *error;
    // set Category for Play and Record
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setPreferredSampleRate:(double)44100.0 error:&error];
    //init RemoteIO
    CheckError (NewAUGraph(&auGraph),"couldn't NewAUGraph");
    CheckError(AUGraphOpen(auGraph),"couldn't AUGraphOpen");
    //
    AudioComponentDescription componentDesc;
    componentDesc.componentType = kAudioUnitType_Output;
    componentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDesc.componentFlags = 0;
    componentDesc.componentFlagsMask = 0;
    //
    CheckError (AUGraphAddNode(auGraph,&componentDesc,&remoteIONode),"couldn't add remote io node");
    CheckError(AUGraphNodeInfo(auGraph,remoteIONode,NULL,&remoteIOUnit),"couldn't get remote io unit from node");
    
    //set BUS
    UInt32 oneFlag = 1;
    UInt32 busZero = 0;
    CheckError(AudioUnitSetProperty(remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output,
                                    busZero,
                                    &oneFlag,
                                    sizeof(oneFlag)),"couldn't kAudioOutputUnitProperty_EnableIO with kAudioUnitScope_Output");
    //
    UInt32 busOne = 1;
    CheckError(AudioUnitSetProperty(remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    busOne,
                                    &oneFlag,
                                    sizeof(oneFlag)),"couldn't kAudioOutputUnitProperty_EnableIO with kAudioUnitScope_Input");
    
    AudioStreamBasicDescription effectDataFormat;
    UInt32 propSize = sizeof(effectDataFormat);
    CheckError(AudioUnitGetProperty(remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    0,
                                    &effectDataFormat,
                                    &propSize),"couldn't get kAudioUnitProperty_StreamFormat with kAudioUnitScope_Output");
    
    CheckError(AudioUnitSetProperty(remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    1,
                                    &effectDataFormat,
                                    propSize),"couldn't set kAudioUnitProperty_StreamFormat with kAudioUnitScope_Output");
    
    CheckError(AudioUnitSetProperty(remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &effectDataFormat,
                                    propSize),"couldn't set kAudioUnitProperty_StreamFormat with kAudioUnitScope_Input");
    
    
    inputProc.inputProc = PerformThru;
    inputProc.inputProcRefCon = (__bridge void *)(self);
    CheckError(AUGraphSetNodeInputCallback(auGraph, remoteIONode, 0, &inputProc),"Error setting io output callback");
    //
    CheckError(AUGraphInitialize(auGraph),"couldn't AUGraphInitialize" );
    CheckError(AUGraphUpdate(auGraph, NULL),"couldn't AUGraphUpdate" );
    CheckError(AUGraphStart(auGraph),"couldn't AUGraphStart");
    //
    CAShow(auGraph);
    
    
}

//
static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	
	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);
    
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
	exit(1);
}

- (IBAction)isMute:(id)sender {
    
    UISwitch *swIsMute = (UISwitch*) sender;
    
    isMute = swIsMute.isOn;
}
@end
