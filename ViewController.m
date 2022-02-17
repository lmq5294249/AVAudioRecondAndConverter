//
//  ViewController.m
//  AVAudioRecondAndConverter
//
//  Created by 林漫钦 on 2022/2/17.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
@property(strong, nonatomic) AVAudioEngine *audioEngine;
@property(strong, nonatomic) AVAudioPlayerNode *playerNode;
@property(nonatomic, strong) AVAudioMixerNode *mixer;
@property(nonatomic, strong) AVAudioFile *file;
@property(nonatomic, strong) dispatch_queue_t audioQueue;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //清除上次缓存的文件
    [self cleanCaches];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //MARK:测试边录音边转码
    [self initAudioEngine];
    //UI
    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [startBtn setFrame:CGRectMake(100, 100, 150, 50)];
    [startBtn setTitle:@"Start" forState:UIControlStateNormal];
    [startBtn setBackgroundColor:[UIColor greenColor]];
    [startBtn addTarget:self action:@selector(btnStartAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startBtn];
    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [stopBtn setFrame:CGRectMake(100, 200, 150, 50)];
    [stopBtn setTitle:@"Stop" forState:UIControlStateNormal];
    [stopBtn setBackgroundColor:[UIColor redColor]];
    [stopBtn addTarget:self action:@selector(btnStopAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopBtn];
}

- (void)initAudioEngine
{
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    
    self.audioQueue = dispatch_queue_create("com.resample.test", 0);
    
    
    [self setupEngine];
}

- (void)setupEngine
{
    double sampleRate = 48000;
    float ioBufferDuration = 0.1;
    int bit = 16;
    
    AVAudioSession *audiosession = [AVAudioSession sharedInstance];
    [audiosession setPreferredSampleRate:sampleRate error:nil];
    [audiosession setPreferredIOBufferDuration:ioBufferDuration error:nil];
    [audiosession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    
    AVAudioInputNode *inputNode = _audioEngine.inputNode;
    NSDictionary *settingTmp =[_audioEngine.inputNode inputFormatForBus:0].settings;
    NSMutableDictionary *setting = [NSMutableDictionary dictionaryWithDictionary:settingTmp];
    [setting setObject:[NSNumber numberWithInt:bit] forKey:AVLinearPCMBitDepthKey];
    [setting setObject:[NSNumber numberWithDouble:sampleRate] forKey:AVSampleRateKey];
    [setting setObject:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    
    // 录音信息
    AVAudioFormat *newFormat = [[AVAudioFormat alloc] initWithSettings:setting];
    
    // 重采样信息
    AVAudioFormat *resampleFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:false];
    AVAudioConverter *formatConverter = [[AVAudioConverter alloc] initFromFormat:newFormat toFormat:resampleFormat];
    
    [inputNode installTapOnBus:0 bufferSize:(AVAudioFrameCount)0.1*sampleRate format:newFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
       
        dispatch_async(self.audioQueue, ^{
            
            AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:resampleFormat frameCapacity:(AVAudioFrameCount)1600];
            
            
            NSError *conversionError = nil;
            AVAudioConverterOutputStatus conversionStatus = [formatConverter convertToBuffer:pcmBuffer error:&conversionError withInputFromBlock:^AVAudioBuffer * _Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus * _Nonnull outStatus) {
                
                *outStatus = AVAudioConverterInputStatus_HaveData;
                
                return buffer;
            }];
            
            if (conversionStatus == AVAudioConverterOutputStatus_HaveData) {
                //[self pcmBufferToData:pcmBuffer];
                if (!self.file) {
                    [self initAVAudioFileWithPCMBuffer:pcmBuffer];
                }
                NSError *error;
                [self.file writeFromBuffer:pcmBuffer error:&error];
                if (error){
                    NSLog(@"writebuffererror =%@",error);
                }
                NSLog(@"打印输出PCMBuffer:%@",pcmBuffer);
            }
            
        });
        
    }];
    
}

- (IBAction)btnStartAction:(id)sender
{
    [self.audioEngine startAndReturnError:nil];
}

- (IBAction)btnStopAction:(id)sender
{
    [self.audioEngine stop];
    [self.audioEngine.inputNode removeTapOnBus:0];
}

- (NSDate *)pcmBufferToData:(AVAudioPCMBuffer *)pcmBuffer
{
    const AudioStreamBasicDescription *description = pcmBuffer.format.streamDescription;
    NSInteger length = pcmBuffer.frameCapacity * description->mBytesPerFrame;
    NSData *data = [[NSData alloc] initWithBytes:pcmBuffer.int16ChannelData length:length];
    return data;
}

- (void)initAVAudioFileWithPCMBuffer:(AVAudioPCMBuffer *)pcmBuffer {
    
    NSError* error;
    NSString* filePath = [self createFilePath];
    
    NSMutableDictionary *setting = [NSMutableDictionary dictionaryWithDictionary:pcmBuffer.format.settings];
    [setting setObject:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsNonInterleaved];
    
    NSLog(@"打印参数设置:%@",pcmBuffer.format.settings);
    _file = [[AVAudioFile alloc] initForWriting:[NSURL fileURLWithPath:filePath] settings:setting commonFormat:AVAudioPCMFormatInt16 interleaved:false error:nil];
    NSLog(@"fileFormat = %@",_file.fileFormat);
    NSLog(@"length = %lld",_file.length);
}

- (NSString *)createFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy_MM_dd__HH_mm_ss";
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSArray *searchPaths    = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                  NSUserDomainMask,
                                                                  YES);
    
    NSString *documentPath  = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"Voice"];
    
    // 先创建子目录. 注意,若果直接调用AudioFileCreateWithURL创建一个不存在的目录创建文件会失败
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:documentPath]) {
        [fileManager createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *fullFileName  = [NSString stringWithFormat:@"%@.caf",date];
    NSString *filePath      = [documentPath stringByAppendingPathComponent:fullFileName];
    return filePath;
}

#pragma mark - 清空缓存
- (void)cleanCaches
{
    NSArray *searchPaths    = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                  NSUserDomainMask,
                                                                  YES);
    NSString *documentPath  = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"Voice"];
    [self cleanCaches:documentPath];
}

- (void)cleanCaches:(NSString *)path
{
    // 利用NSFileManager实现对文件的管理
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        // 获取该路径下面的文件名
        NSArray *childrenFiles = [fileManager subpathsAtPath:path];
        for (NSString *fileName in childrenFiles) {
            // 拼接路径
            NSString *absolutePath = [path stringByAppendingPathComponent:fileName];
            // 将文件删除
            [fileManager removeItemAtPath:absolutePath error:nil];
        }
    }
}

@end
