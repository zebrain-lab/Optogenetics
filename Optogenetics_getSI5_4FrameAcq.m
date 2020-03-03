function Optogenetics_getSI5_4FrameAcq(source,event,varargin)

    hSI = source.hSI;
    OP = evalin('base','OP');
    lastStripe = hSI.hDisplay.stripeDataBuffer{hSI.hDisplay.stripeDataBufferPointer};
    frame = lastStripe.roiData{1}.imageData{2}{1};
    im_min = hSI.hChannels.channelLUT{2}(1);
    im_max = hSI.hChannels.channelLUT{2}(2);
    frame = (double(frame) - double(im_min))./(double(im_max)-double(im_min));
    OP.images.TwoP = frame';
    notify(OP,'SIframeAcq');
end