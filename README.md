# AVAudioRecondAndConverter
 AVAudioRecondAndConverter

文章的代码参考https://github.com/954788/Resample
原该作者是Swift写法，网上大部分都是差不多这种，目前没有OC的代码。所以趁着学习AVAudioEngine的机会自己参考后改写代码。

## AVAudioEngine录音 & AVAudioConverter重采样
目前已经实现从AVAudioEngine录音采集音频数据AVAudioPCMBuffer，然后通过AVAudioConverter类对数据进行音频格式转换最后得出想要的数据结果。

补充知识点：
>IOBufferDuration：采样的间隔，假设采样率为16k，那么1秒钟会采样16000个样本，设置IOBufferDuration为0.1秒，设备会按0.1秒一次去进行采样，每次采样数量为16000*0.1 = 1600，由于录音设备有它本身的条件限制，所以不能随意设置采样间隔，例如把IOBufferDuration设置为0.000001秒，系统会自动修改成当前设备支持的最低采样间隔，测试设备8p采样16k的最低采样间隔约为0.016秒

>bufferSize：缓冲区的大小。录制实时音频流的时候，假设IOBufferDuration为0.1秒，音频不是每隔0.1秒给我们输出一次数据，而是每隔0.1秒把音频数据放入缓冲区，缓冲区满了后，再把音频输出一次给我们，例如bufferSize设为512，那么当缓冲区中的音频样本数达到512个，就会输出给我们，我们得到音频的时间间隔是1s/16000x512=0.032秒。由于AVAudioEngine的Tap方法要求缓冲区的大小为100ms～400ms采集音频的大小，0.032低于系统要求的0.1s，所以系统会自动修改缓冲区大小为0.1sx16000 = 1600，每隔0.1s输出一次音频给我们，每次的音频样本数为1600，大小为 3200字节。

>注意:在AVAudioEngine中缓冲区大小的单位是样本数，在AVAudioUnit中单位为字节数，在线性16位PCM格式单声道音频里，一个package含有一个frame,一个frame有1个channel，1个channel有16位，占两个字节，缓冲区512个样本数在使用AVAudioUnit时要设为1024个字节大小

核心的代码如下所示
```
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
```
