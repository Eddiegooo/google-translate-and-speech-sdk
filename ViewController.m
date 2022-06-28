//
//  ViewController.m
//  ArgaDemo
//
//  Created by 范清龙 on 2022/6/14.
//

#import "ViewController.h"
#import <AgoraRtcKit/AgoraRtcEngineKit.h>
#import "VideoViewController.h"
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>
#import "TestViewController.h"
#import "AudioRecorder.h"



@interface ViewController ()<AgoraRtcEngineDelegate, AgoraAudioDataFrameProtocol>{
    NSString *speechKey;
    NSString *serviceRegion;
}

@property (nonatomic, strong) AgoraRtcEngineKit *agoraKit;
@property (strong, nonatomic)  UILabel *recognitionResultLabel;

@property (nonatomic, strong) SPXPushAudioInputStream *pushStream;
@property (nonatomic, strong) SPXSpeechRecognizer *recognize;
@property (nonatomic, strong) SPXTranslationRecognizer *translation;



@end

@implementation ViewController


- (SPXPushAudioInputStream *)pushStream {
    if (!_pushStream) {
        _pushStream = [SPXPushAudioInputStream new];
    }
    return _pushStream;
}

- (SPXSpeechRecognizer *)recognize {
    if (!_recognize) {
        _recognize = [SPXSpeechRecognizer new];
    }
    return _recognize;
}

- (SPXTranslationRecognizer *)translation {
    if (!_translation) {
        _translation = [[SPXTranslationRecognizer alloc] init];
    }
    return _translation;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    speechKey = @"";
    serviceRegion = @"";
    
    [self initAgoraKit];
    
    
    
    UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem];
    [start setTitle:@"开始" forState:UIControlStateNormal];
    [start setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    start.layer.borderWidth = 1;
    start.layer.borderColor = UIColor.cyanColor.CGColor;
    start.layer.cornerRadius = 10.0;
    start.frame = CGRectMake(50, UIScreen.mainScreen.bounds.size.height - 150, 50, 45);
    [start addTarget:self action:@selector(joinChannel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:start];
    
    
    UIButton *end = [UIButton buttonWithType:UIButtonTypeSystem];
    [end setTitle:@"离开" forState:UIControlStateNormal];
    [end setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    end.layer.borderWidth = 1;
    end.layer.borderColor = UIColor.cyanColor.CGColor;
    end.layer.cornerRadius = 10.0;
    end.frame = CGRectMake( UIScreen.mainScreen.bounds.size.width - 100, UIScreen.mainScreen.bounds.size.height - 150, 50, 45);
    [end addTarget:self action:@selector(leaveChannel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:end];
    
    
    UIButton *videoVC = [UIButton buttonWithType:UIButtonTypeSystem];
    [videoVC setTitle:@"视频" forState:UIControlStateNormal];
    [videoVC setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    videoVC.layer.borderWidth = 1;
    videoVC.layer.borderColor = UIColor.cyanColor.CGColor;
    videoVC.layer.cornerRadius = 10.0;
    videoVC.frame = CGRectMake( UIScreen.mainScreen.bounds.size.width / 2 - 25, UIScreen.mainScreen.bounds.size.height - 150, 50, 45);
    [videoVC addTarget:self action:@selector(pushToVideoVC) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:videoVC];
    
    
    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(10, 100, 350, 200)];
    lab.textColor = UIColor.blackColor;
    lab.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:lab];
    self.recognitionResultLabel = lab;
}

- (void)initAgoraKit {
    self.agoraKit = [AgoraRtcEngineKit sharedEngineWithAppId:@"" delegate:self];
    // 获取原始音频数据代理
    [self.agoraKit setAudioDataFrame:self];
    
}

- (void)joinChannel {
    NSInteger result = [self.agoraKit joinChannelByToken:@"/y1N//trti" channelId:@"Eddie" info:nil uid:0 joinSuccess:^(NSString * _Nonnull channel, NSUInteger uid, NSInteger elapsed) {
        NSLog(@"加入频道成功！频道：%@，UID=%ld，elapse=%ld", channel, uid, elapsed);
//        [self pushAudioInputStream];
        [self startTranslation];
    }];
    if (result != 0) {
        NSLog(@"加入频道错误了");
    }
}


- (void)leaveChannel {
    [self.agoraKit setAudioDataFrame:nil];
    [self.agoraKit leaveChannel:nil];
}


- (void)pushAudioInputStream {
    // set up the stream
    SPXAudioStreamFormat *audioFormat = [[SPXAudioStreamFormat alloc] initUsingPCMWithSampleRate:44100 bitsPerSample:16 channels:1];
    self.pushStream = [[SPXPushAudioInputStream alloc] initWithAudioFormat:audioFormat];

    SPXAudioConfiguration* audioConfig = [[SPXAudioConfiguration alloc] initWithStreamInput:self.pushStream];
    if (!audioConfig) {
        NSLog(@"Error creating stream!");
        [self updateRecognitionErrorText:(@"Error creating stream!")];
        return;
    }

    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        [self updateRecognitionErrorText:(@"Speech Config Error")];
        return;
    }

    self.recognize = [[SPXSpeechRecognizer alloc] initWithSpeechConfiguration:speechConfig audioConfiguration:audioConfig];
    if (!self.recognize) {
        NSLog(@"Could not create speech recognizer");
        [self updateRecognitionResultText:(@"Speech Recognition Error")];
        return;
    }

    // connect callbacks
    [self.recognize addRecognizingEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
        NSLog(@"Received intermediate result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        [self updateRecognitionStatusText:eventArgs.result.text];
    }];


    [self.recognize addRecognizedEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
        NSLog(@"Received final result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        [self updateRecognitionResultText:eventArgs.result.text];
    }];

    // start recognizing
    [self updateRecognitionStatusText:(@"Recognizing from push stream...")];
    [self.recognize startContinuousRecognition];

}

- (void)startTranslation {
    // set up the stream
    SPXAudioStreamFormat *audioFormat = [[SPXAudioStreamFormat alloc] initUsingPCMWithSampleRate:44100 bitsPerSample:16 channels:1];
    self.pushStream = [[SPXPushAudioInputStream alloc] initWithAudioFormat:audioFormat];

    SPXAudioConfiguration* audioConfig = [[SPXAudioConfiguration alloc] initWithStreamInput:self.pushStream];
    if (!audioConfig) {
        NSLog(@"Error creating stream!");
        [self updateRecognitionErrorText:(@"Error creating stream!")];
        return;
    }
    
    SPXSpeechTranslationConfiguration *transConfig = [[SPXSpeechTranslationConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    if (!transConfig) {
        NSLog(@"Could not load transConfig config");
        [self updateRecognitionErrorText:(@"transConfig Config Error")];
        return;
    }
    [transConfig addTargetLanguage:@"de-DE"];
    
    self.translation = [[SPXTranslationRecognizer alloc] initWithSpeechTranslationConfiguration:transConfig audioConfiguration:audioConfig];
    if (!self.translation) {
        NSLog(@"Could not create speech translation");
        [self updateRecognitionResultText:(@"translation Recognition Error")];
        return;
    }

//    [self.translation addTargetLanguage:@"zh-CN"];
    
//    [self.translation addTargetLanguage:@"en-US"];
    
    [self.translation addRecognizingEventHandler:^(SPXTranslationRecognizer * trans, SPXTranslationRecognitionEventArgs * event) {
        NSLog(@"正在翻译。。。");
        [self updateRecognitionResultText:event.result.translations[@"en"]];
    }];
    [self.translation addRecognizedEventHandler:^(SPXTranslationRecognizer * _Nonnull, SPXTranslationRecognitionEventArgs * event) {
        NSLog(@"翻译结果：：：");
        [self updateRecognitionResultText:event.result.translations[@"en"]];
    }];
    
    [self.translation addSessionStartedEventHandler:^(SPXRecognizer * _Nonnull, SPXSessionEventArgs * _Nonnull) {
        NSLog(@"开始了");
    }];
    
    [self.translation addSessionStoppedEventHandler:^(SPXRecognizer * _Nonnull, SPXSessionEventArgs * _Nonnull) {
        NSLog(@"结束了就？？");
    }];
    
    [self.translation addCanceledEventHandler:^(SPXTranslationRecognizer * _Nonnull, SPXTranslationRecognitionCanceledEventArgs * _Nonnull) {
            NSLog(@"取消了？？??");
    }];
    
    [self updateRecognitionStatusText:(@"Recognizing from push stream start translation...")];
    
    [self.translation startContinuousRecognition];
    
//    [self.translation recognizeOnceAsync:^(SPXTranslationRecognitionResult * result) {
//        [self updateRecognitionResultText:result.text];
//    }];
    
}

// 获取音频流进行识别
- (void)spxAudioRecgnize {
    //    SPXAudioStreamFormat *famt = [[SPXAudioStreamFormat alloc] initUsingPCMWithSampleRate:16000 bitsPerSample:1024 channels:1];
    
//        AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:frame.samplesPerSec channels:frame.channels interleaved:NO];

//        NSError *error = nil;
//        AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:[NSURL new] commonFormat:AVAudioPCMFormatInt16 interleaved:NO error:&error];
//        const NSInteger bytesPerFrame = audioFile.fileFormat.streamDescription->mBytesPerFrame;
    
    
    SPXPullAudioInputStream *inputStream = [[SPXPullAudioInputStream alloc] initWithReadHandler:^NSInteger(NSMutableData * data, NSUInteger size) {
        NSLog(@"data === %@;;  size = %ld", data, size);
//        AVAudioFormat *audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:audioFrame.samplesPerSec channels:(uint32_t)audioFrame.channels interleaved:false];
//            const NSInteger bytesPerFrame = audioFormat.streamDescription->mBytesPerFrame;
//
//            AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:(AVAudioFrameCount)size / bytesPerFrame];
//
//        NSError *bufferError = nil;
////        bool success = [audioFile readIntoBuffer:buffer error:&bufferError];
//
//        NSInteger nBytes = 0;
//        {
//            // number of bytes in the buffer
//            nBytes = [pcmBuffer frameLength] * audioFrame.bytesPerSample;
//
//            NSRange range;
//            range.location = 0;
//            range.length = nBytes;
//
//            NSAssert(1 == pcmBuffer.stride, @"only one channel allowed");
//            NSAssert(nil != pcmBuffer.int16ChannelData, @"assure correct format");
//
//            [data replaceBytesInRange:range withBytes:pcmBuffer.int16ChannelData[0]];
//            NSLog(@"%d bytes data returned", (int)[data length]);
//        }
//        // returns the number of bytes that have been read, 0 closes the stream.
//        return nBytes;
        return 100;
    } closeHandler:^{
        
    }];
    
    SPXAudioConfiguration *audioConfig = [[SPXAudioConfiguration alloc] initWithStreamInput:inputStream];
    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];;
    
    self.recognize = [[SPXSpeechRecognizer alloc] initWithSpeechConfiguration:speechConfig audioConfiguration:audioConfig];
    
    
    [self.recognize addRecognizingEventHandler:^(SPXSpeechRecognizer *recgnize, SPXSpeechRecognitionEventArgs * eventArgs) {
        NSLog(@"======Received intermediate result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
    }];
    
    [self.recognize addRecognizedEventHandler:^(SPXSpeechRecognizer * recgnize, SPXSpeechRecognitionEventArgs * eventArgs) {
        NSLog(@"======Received final result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
    }];
    
    [self.recognize addSessionStartedEventHandler:^(SPXRecognizer * reg, SPXSessionEventArgs * event) {
        NSLog(@"====开始了");
    }];
    
    [self.recognize addSessionStoppedEventHandler:^(SPXRecognizer * reg, SPXSessionEventArgs * event) {
        NSLog(@"====已经结束了");
    }];
    
    [self.recognize startContinuousRecognition];
    
}

- (void)updateRecognitionResultText:(NSString *) resultText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.blackColor;
        self.recognitionResultLabel.text = resultText;
    });
}

- (void)updateRecognitionErrorText:(NSString *) errorText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.redColor;
        self.recognitionResultLabel.text = errorText;
    });
}

- (void)updateRecognitionStatusText:(NSString *) statusText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.grayColor;
        self.recognitionResultLabel.text = statusText;
    });
}


//在这些回调的返回值中设置想要获取的音频数据格式
- (AgoraAudioParam *)getRecordAudioParams {
    AgoraAudioParam *audio = [AgoraAudioParam new];
    audio.sampleRate = 44100;
    audio.channel = 1;
    audio.mode = AgoraAudioRawFrameOperationModeReadOnly;
    audio.samplesPerCall = 1024;
    return  audio;
}

- (AgoraAudioParam * _Nonnull)getPlaybackAudioParams {
    AgoraAudioParam *audio = [AgoraAudioParam new];
    audio.sampleRate = 44100;
    audio.channel = 1;
    audio.mode = AgoraAudioRawFrameOperationModeReadOnly;
    audio.samplesPerCall = 1024;
    return  audio;
}

- (AgoraAudioParam * _Nonnull)getMixedAudioParams {
    AgoraAudioParam *audio = [AgoraAudioParam new];
    audio.sampleRate = 44100;
    audio.channel = 1;
    audio.mode = AgoraAudioRawFrameOperationModeReadOnly;
    audio.samplesPerCall = 1024;
    return  audio;
}



//返回值中设置想要观测的音频位置和是否获取多个频道的音频数据。
- (AgoraAudioFramePosition)getObservedAudioFramePosition {
    return AgoraAudioFramePositionRecord;
//    return AgoraAudioFramePositionPlayback;
}

/**
 SDK 根据 getObservedAudioFramePosition 和 isMultipleChannelFrameWanted 的返回值触发 onRecordAudioFrame、onPlaybackAudioFrame、onPlaybackAudioFrameBeforeMixing/onPlaybackAudioFrameBeforeMixingEx 或 onMixedAudioFrame 回调发送采集到的原始音频数据。
 
 拿到音频数据后，你可以根据场景需要自行进行处理。完成音频数据处理后，你可以根据场景需求再通过 onRecordAudioFrame、onPlaybackAudioFrame、onPlaybackAudioFrameBeforeMixing/onPlaybackAudioFrameBeforeMixingEx 或 onMixedAudioFrame 回调发送给 SDK。
 */

// 获取自己流
- (BOOL)onRecordAudioFrame:(AgoraAudioFrame *)frame {
    // `buffer` = `samplesPerChannel` × `channels` × `bytesPerSample`
    NSData *bufferData = [NSData dataWithBytes:frame.buffer length:frame.channels * frame.bytesPerSample * frame.samplesPerChannel];
    [self.pushStream write: bufferData];
    return NO;
}

// 获取通话流
- (BOOL)onPlaybackAudioFrame:(AgoraAudioFrame *)frame {
    NSData *bufferData = [NSData dataWithBytes:frame.buffer length:frame.channels * frame.bytesPerSample * frame.samplesPerChannel];
    [self.pushStream write: bufferData];
    return NO;
}
//
- (BOOL)onMixedAudioFrame:(AgoraAudioFrame * _Nonnull)frame {
    return YES;
}




- (void)dealloc {
    [AgoraRtcEngineKit destroy];
}

- (void)pushToVideoVC {
    VideoViewController *videoVC = [VideoViewController new];
    [self presentViewController:videoVC animated:YES completion:^{
        
    }];
}

//
//- (void)recognizeFromMicro {
//    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
//    [speechConfig setSpeechRecognitionLanguage:@"en-US"];
//
//    self.pushStream = [[SPXPushAudioInputStream alloc] init];
//    SPXAudioConfiguration *audioConfig = [[SPXAudioConfiguration alloc] initWithStreamInput:self.pushStream];
//    self.recognize = [[SPXSpeechRecognizer alloc] initWithSpeechConfiguration:speechConfig audioConfiguration:audioConfig];
//
//    [self.recognize addRecognizedEventHandler:^(SPXSpeechRecognizer * reco, SPXSpeechRecognitionEventArgs * evt) {
//        NSLog(@"result === %@", evt.result.text);
//    }];
//    [self.recognize addCanceledEventHandler:^(SPXSpeechRecognizer * _Nonnull, SPXSpeechRecognitionCanceledEventArgs * evt) {
//        NSLog(@"cancel ====%@",evt.errorDetails);
//    }];
//
//    [self.recognize recognizeOnceAsync:^(SPXSpeechRecognitionResult * result) {
//        [self.audioEngine startAndReturnError:nil];
//        [self.audioEngine.inputNode removeTapOnBus:0];
//        [self.audioEngine stop];
//    }];
//
//    // 从麦克风采集  === 就是从外部拿到音频
//    [self fromOutSideAudioStream];
//}
//
//
//- (void)fromOutSideAudioStream {
//    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
//    AVAudioFormat *inputFormat = [inputNode outputFormatForBus:0];
//    AVAudioFormat *recordingFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000.0 channels:1 interleaved:NO];
//    AVAudioConverter *formatConverter = [[AVAudioConverter alloc] initFromFormat:inputFormat toFormat:recordingFormat];
//
//    [self.audioEngine.inputNode installTapOnBus:0 bufferSize:1024 format:inputFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull time) {
//        AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:recordingFormat frameCapacity:1024];
//        [formatConverter convertToBuffer:pcmBuffer error:nil withInputFromBlock:^AVAudioBuffer * _Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus * _Nonnull outStatus) {
//            return buffer;
//        }];
//        if (pcmBuffer != nil) {
//            [self.pushStream write:[NSData new]];
//        }
//    }];
//
//    [self.audioEngine prepare];
//
//    [self.audioEngine startAndReturnError:nil];
//}
//
//
//- (void)createFile {
//    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSString *fileName = @"/pullStream.wav";
//    NSString *fileAtPath = [filePath stringByAppendingString:fileName];
//    if (![[NSFileManager defaultManager] fileExistsAtPath:fileAtPath]) {
//        [[NSFileManager defaultManager] createFileAtPath:fileAtPath contents:nil attributes:nil];
//    }
//
//    SPXPullAudioOutputStream *stream = [[SPXPullAudioOutputStream alloc] init];
//    SPXAudioConfiguration *audioConfig = [[SPXAudioConfiguration alloc] initWithStreamOutput:stream];
//
//    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
//    if (!speechConfig) {
//        NSLog(@"Could not load speech config");
//        return;
//    }
//
//    SPXSpeechSynthesizer *synthesizer = [[SPXSpeechSynthesizer alloc] initWithSpeechConfiguration:speechConfig audioConfiguration:audioConfig];
//    if (!synthesizer) {
//        NSLog(@"Could not create speech synthesizer");
//        return;
//    }
//
//    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:fileAtPath];
//    if (file == nil) {
//        NSLog(@"failed to open file");
//    }
////    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:1024];
//    while ([stream read:self.saveData length:1024] > 0) {
//        [file writeData:self.saveData];
//        [file seekToEndOfFile];
//    }
//    [file closeFile];
//}


//+ (Class)class AVAudioPCMBuffer {
//    func data() -> Data {
//        var nBytes = 0
//        nBytes = Int(self.frameLength * (self.format.streamDescription.pointee.mBytesPerFrame))
//        var range: NSRange = NSRange()
//        range.location = 0
//        range.length = nBytes
//        let buffer = NSMutableData()
//        buffer.replaceBytes(in: range, withBytes: (self.int16ChannelData![0]))
//        return buffer as Data
//    }
//}

@end
