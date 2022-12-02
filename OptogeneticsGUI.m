classdef OptogeneticsGUI < handle
    
    properties
        figMain
        hardware
        settings
        roiList
        frameList
        images 
        affineTransform
    end
    
    methods
        function obj = OptogeneticsGUI(XCiteComPort, DMDindex)
        % declare all elements and initialize hardware
        
            obj.init_mainFig();
            
            obj.addlistener('SIframeAcq',@obj.SIframeAcqListener);
            
            % initialize affine transform matrices
            % update this to reflect current calibration
            cam2twop_slope = [-0.3110,0.0025,0;
                              0.0048,0.3135,0;
                              118.9785,-84.5478,0];
                          
            cam2twop_icpt = [-0.0002,0.0100,0;
                             0.0031,0.0002,0;
                             256.3331,251.4713,1];
                         
            cam2sensor = [0.6469,0.0120,-0.0000;
                          -0.0050,0.6479,-0.0000;
                          154.6732,180.9265,1.0000];
                      
            sensor2cam = [1.5456,-0.0286,-0.0000;
                          0.0119,1.5432,0.0000;
                          -241.2150,-274.7817,1.0000];
            
            obj.affineTransform.Cam2TwoP = @(z) z.*cam2twop_slope + cam2twop_icpt;
            obj.affineTransform.TwoP2Cam = @(z) inv(obj.affineTransform.Cam2TwoP(z));
            obj.affineTransform.Cam2Sensor = cam2sensor;
            obj.affineTransform.Sensor2Cam = sensor2cam;
            obj.affineTransform.TwoP2Sensor = @(z) obj.affineTransform.TwoP2Cam(z) * obj.affineTransform.Cam2Sensor;                        
            obj.affineTransform.Sensor2TwoP = @(z) obj.affineTransform.Sensor2Cam * obj.affineTransform.Cam2TwoP(z); 
            
            % Initialize roiList
            obj.roiList.selectedRow = [];
            obj.roiList.selectedCol = [];
            obj.roiList.maskList = [];
            obj.roiList.numRoi = 0;
            obj.frameList.selectedRow = [];
            
            % initialize hardware interface 
            try 
                obj.hardware.XCite = XciteXLED1(XCiteComPort);
                obj.settings.XCite.numled = 4;
            catch ME
                warning(ME.message)
            end
            
            try
                obj.hardware.DMD = Mosaic3(DMDindex);
                obj.settings.DMD.SensorWidth = obj.hardware.DMD.getInt('SensorWidth');
                obj.settings.DMD.SensorHeight = obj.hardware.DMD.getInt('SensorHeight');
                obj.settings.DMD.ImageSizeBytes = obj.hardware.DMD.getInt('ImageSizeBytes');
            catch ME
                warning(ME.message);
            end
            
            try
                obj.hardware.Cam =  videoinput('winvideo', 1, 'Y800_744x480');
                src = getselectedsource(obj.hardware.Cam);  
                src.ExposureMode = 'manual';
                src.GainMode = 'manual';
                srcinfo = propinfo(src);
                vidinfo = propinfo(obj.hardware.Cam);
                obj.settings.cam.Exposure = srcinfo.Exposure;
                obj.settings.cam.ExposureMode = srcinfo.ExposureMode;
                obj.settings.cam.Gain = srcinfo.Gain;
                obj.settings.cam.GainMode = srcinfo.GainMode;
                obj.settings.cam.FrameRate = srcinfo.FrameRate;
                obj.settings.cam.VideoResolution = vidinfo.VideoResolution;
            catch ME
                warning(ME.message);
            end
            
            try
                if evalin('base','~exist(''hSI'')')
                    disp('launching scanimage');
                    scanimage;
                end
                obj.hardware.hSI = evalin('base','hSI');
                obj.hardware.hSICtl = evalin('base','hSICtl');
                obj.settings.SI.pixelsPerLine = obj.hardware.hSI.hRoiManager.pixelsPerLine;
                obj.settings.SI.linesPerFrame = obj.hardware.hSI.hRoiManager.linesPerFrame;
                obj.settings.SI.zoomFactor = obj.hardware.hSI.hRoiManager.scanZoomFactor;
            catch ME
                warning(ME.message);
            end
            
            % initialize images
            obj.images.TwoP = zeros(obj.settings.SI.linesPerFrame,obj.settings.SI.pixelsPerLine);
            obj.images.Cam = zeros(obj.settings.cam.VideoResolution.DefaultValue(2),...
                    obj.settings.cam.VideoResolution.DefaultValue(1));
            obj.images.Sensor = zeros(obj.settings.DMD.SensorHeight,obj.settings.DMD.SensorWidth);
            
            obj.init_XciteTab();
            obj.init_DMDTab(); 
            obj.init_CalibrationTab();
            obj.init_SegmentationTab();
            
            obj.XCiteRefresh();
            obj.DMDRefresh();
            obj.layout();
        end
        
        function init_mainFig(obj)
            % create the main figure
            obj.figMain.handle = figure;
            obj.figMain.handle.Name = 'OptogeneticsGUI';
            obj.figMain.handle.NumberTitle = 'off';
            obj.figMain.handle.MenuBar = 'none';
            obj.figMain.handle.ToolBar = 'none';
            obj.figMain.handle.CloseRequestFcn = @obj.onCloseMain;
            
            % create main figure tabs
            obj.figMain.tabgroup = uitabgroup(obj.figMain.handle);
            obj.figMain.tabgroup.SelectionChangedFcn = @obj.onTabChange;
            obj.figMain.XCite.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.XCite.tab.Title = 'XCite';
            obj.figMain.DMD.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.DMD.tab.Title = 'DMD';
            obj.figMain.Calibration.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.Calibration.tab.Title = 'Calibration';
            obj.figMain.Segmentation.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.Segmentation.tab.Title = 'Segmentation';
        end
        
        function init_XciteTab(obj)
            obj.figMain.XCite.status.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.status.panel.Title = 'Status';
            obj.figMain.XCite.status.button = uicontrol(obj.figMain.XCite.status.panel);
            obj.figMain.XCite.status.button.Style = 'pushbutton';
            obj.figMain.XCite.status.button.Units = 'normalized';
            obj.figMain.XCite.status.button.String = 'Refresh';
            obj.figMain.XCite.status.button.Tag = 'RefreshButton';
            obj.figMain.XCite.status.button.Callback = @obj.XCiteRefresh;
            obj.figMain.XCite.status.softwareversion = uicontrol(obj.figMain.XCite.status.panel);
            obj.figMain.XCite.status.softwareversion.Style = 'edit';
            obj.figMain.XCite.status.softwareversion.Units = 'normalized';
            obj.figMain.XCite.status.softwareversion.String = 'not connected'; 
            obj.figMain.XCite.status.softwareversion.Enable = 'inactive';
            obj.figMain.XCite.status.serialnumber = uicontrol(obj.figMain.XCite.status.panel);
            obj.figMain.XCite.status.serialnumber.Style = 'edit';
            obj.figMain.XCite.status.serialnumber.Units = 'normalized';
            obj.figMain.XCite.status.serialnumber.String = 'not connected';
            obj.figMain.XCite.status.serialnumber.Enable = 'inactive';
            obj.figMain.XCite.status.legend.panel = uipanel(obj.figMain.XCite.status.panel);
            obj.figMain.XCite.status.legend.panel.BorderType = 'none';
            obj.figMain.XCite.status.legend.ledname = uicontrol(obj.figMain.XCite.status.legend.panel);
            obj.figMain.XCite.status.legend.ledname.Style = 'edit';
            obj.figMain.XCite.status.legend.ledname.Units = 'normalized';
            obj.figMain.XCite.status.legend.ledname.String = 'LED name';
            obj.figMain.XCite.status.legend.ledname.Enable = 'inactive';
            obj.figMain.XCite.status.legend.ledhours = uicontrol(obj.figMain.XCite.status.legend.panel);
            obj.figMain.XCite.status.legend.ledhours.Style = 'edit';
            obj.figMain.XCite.status.legend.ledhours.Units = 'normalized';
            obj.figMain.XCite.status.legend.ledhours.String = 'LED hours';
            obj.figMain.XCite.status.legend.ledhours.Enable = 'inactive';
            obj.figMain.XCite.status.legend.ledmintemp = uicontrol(obj.figMain.XCite.status.legend.panel);
            obj.figMain.XCite.status.legend.ledmintemp.Style = 'edit';
            obj.figMain.XCite.status.legend.ledmintemp.Units = 'normalized';
            obj.figMain.XCite.status.legend.ledmintemp.String = 'Min Tmp';
            obj.figMain.XCite.status.legend.ledmintemp.Enable = 'inactive';
            obj.figMain.XCite.status.legend.ledtemp = uicontrol(obj.figMain.XCite.status.legend.panel);
            obj.figMain.XCite.status.legend.ledtemp.Style = 'edit';
            obj.figMain.XCite.status.legend.ledtemp.Units = 'normalized';
            obj.figMain.XCite.status.legend.ledtemp.String = 'Tmp';
            obj.figMain.XCite.status.legend.ledtemp.Enable = 'inactive';
            obj.figMain.XCite.status.legend.ledmaxtemp = uicontrol(obj.figMain.XCite.status.legend.panel);
            obj.figMain.XCite.status.legend.ledmaxtemp.Style = 'edit';
            obj.figMain.XCite.status.legend.ledmaxtemp.Units = 'normalized';
            obj.figMain.XCite.status.legend.ledmaxtemp.String = 'Max Tmp';
            obj.figMain.XCite.status.legend.ledmaxtemp.Enable = 'inactive';
            for ind=1:obj.settings.XCite.numled
                obj.figMain.XCite.status.LED(ind).panel = uipanel(obj.figMain.XCite.status.panel);
                obj.figMain.XCite.status.LED(ind).panel.BorderType = 'none';
                obj.figMain.XCite.status.LED(ind).ledname = uicontrol(obj.figMain.XCite.status.LED(ind).panel);
                obj.figMain.XCite.status.LED(ind).ledname.Style = 'edit';
                obj.figMain.XCite.status.LED(ind).ledname.Units = 'normalized';
                obj.figMain.XCite.status.LED(ind).ledname.String = ['LED' num2str(ind)];
                obj.figMain.XCite.status.LED(ind).ledname.Enable = 'inactive';
                obj.figMain.XCite.status.LED(ind).ledhours = uicontrol(obj.figMain.XCite.status.LED(ind).panel);
                obj.figMain.XCite.status.LED(ind).ledhours.Style = 'edit';
                obj.figMain.XCite.status.LED(ind).ledhours.Units = 'normalized';
                obj.figMain.XCite.status.LED(ind).ledhours.String = '0';
                obj.figMain.XCite.status.LED(ind).ledhours.Enable = 'inactive';
                obj.figMain.XCite.status.LED(ind).ledtemp = uicontrol(obj.figMain.XCite.status.LED(ind).panel);
                obj.figMain.XCite.status.LED(ind).ledtemp.Style = 'edit';
                obj.figMain.XCite.status.LED(ind).ledtemp.Units = 'normalized';
                obj.figMain.XCite.status.LED(ind).ledtemp.String = '0';
                obj.figMain.XCite.status.LED(ind).ledtemp.Enable = 'inactive';
                obj.figMain.XCite.status.LED(ind).ledmintemp = uicontrol(obj.figMain.XCite.status.LED(ind).panel);
                obj.figMain.XCite.status.LED(ind).ledmintemp.Style = 'edit';
                obj.figMain.XCite.status.LED(ind).ledmintemp.Units = 'normalized';
                obj.figMain.XCite.status.LED(ind).ledmintemp.String = '0';
                obj.figMain.XCite.status.LED(ind).ledmintemp.Enable = 'inactive';
                obj.figMain.XCite.status.LED(ind).ledmaxtemp = uicontrol(obj.figMain.XCite.status.LED(ind).panel);
                obj.figMain.XCite.status.LED(ind).ledmaxtemp.Style = 'edit';
                obj.figMain.XCite.status.LED(ind).ledmaxtemp.Units = 'normalized';
                obj.figMain.XCite.status.LED(ind).ledmaxtemp.String = '0';
                obj.figMain.XCite.status.LED(ind).ledmaxtemp.Enable = 'inactive';
            end
            
            obj.figMain.XCite.leds.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.leds.panel.Title = 'LEDs';
            for ind=1:obj.settings.XCite.numled
                obj.figMain.XCite.leds.LED(ind).panel = uipanel(obj.figMain.XCite.leds.panel);
                obj.figMain.XCite.leds.LED(ind).panel.BorderType = 'none';
                obj.figMain.XCite.leds.LED(ind).button = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).button.Style = 'togglebutton';
                obj.figMain.XCite.leds.LED(ind).button.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).button.String =  ['LED' num2str(ind)];
                obj.figMain.XCite.leds.LED(ind).button.Tag = 'LEDButton';
                obj.figMain.XCite.leds.LED(ind).button.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.leds.LED(ind).intensity = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).intensity.Style = 'slider';
                obj.figMain.XCite.leds.LED(ind).intensity.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).intensity.Min = 0;
                obj.figMain.XCite.leds.LED(ind).intensity.Max = 100;
                obj.figMain.XCite.leds.LED(ind).intensity.SliderStep = [1/100 1/10];
                obj.figMain.XCite.leds.LED(ind).intensity.Tag = 'LEDIntensitySlider';
                obj.figMain.XCite.leds.LED(ind).intensity.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.leds.LED(ind).pm = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).pm.Style = 'popupmenu';
                obj.figMain.XCite.leds.LED(ind).pm.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).pm.String = {'Manual','Internal PWM','External','Global'};
                obj.figMain.XCite.leds.LED(ind).pm.Tag = 'LEDPulseModePopupmenu';
                obj.figMain.XCite.leds.LED(ind).pm.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.leds.LED(ind).intensityTxt = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Style = 'edit';
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).intensityTxt.String = '0 %';
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Enable = 'inactive';
            end

            obj.figMain.XCite.pwm.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.pwm.panel.Title = 'Internal PWM';
            obj.figMain.XCite.pwm.buttons.panel = uipanel(obj.figMain.XCite.pwm.panel);
            obj.figMain.XCite.pwm.buttons.panel.BorderType = 'none';
            obj.figMain.XCite.pwm.buttons.start = uicontrol(obj.figMain.XCite.pwm.buttons.panel);
            obj.figMain.XCite.pwm.buttons.start.Style = 'togglebutton';
            obj.figMain.XCite.pwm.buttons.start.Units = 'normalized';
            obj.figMain.XCite.pwm.buttons.start.String = 'Start';
            obj.figMain.XCite.pwm.buttons.start.Tag = 'PWMStartButton';
            obj.figMain.XCite.pwm.buttons.start.Callback = @obj.XCiteCallback;
            obj.figMain.XCite.pwm.buttons.repeat = uicontrol(obj.figMain.XCite.pwm.buttons.panel);
            obj.figMain.XCite.pwm.buttons.repeat.Style = 'togglebutton';
            obj.figMain.XCite.pwm.buttons.repeat.Units = 'normalized';
            obj.figMain.XCite.pwm.buttons.repeat.String = 'Repeat';
            obj.figMain.XCite.pwm.buttons.repeat.Tag = 'PWMRepeatButton';
            obj.figMain.XCite.pwm.buttons.repeat.Callback = @obj.XCiteCallback;
            obj.figMain.XCite.pwm.legend.panel = uipanel(obj.figMain.XCite.pwm.panel);
            obj.figMain.XCite.pwm.legend.panel.BorderType = 'none';
            obj.figMain.XCite.pwm.legend.ontimetxt = uicontrol(obj.figMain.XCite.pwm.legend.panel);
            obj.figMain.XCite.pwm.legend.ontimetxt.Style = 'edit';
            obj.figMain.XCite.pwm.legend.ontimetxt.Units = 'normalized';
            obj.figMain.XCite.pwm.legend.ontimetxt.String = 'On';
            obj.figMain.XCite.pwm.legend.ontimetxt.Enable = 'inactive';
            obj.figMain.XCite.pwm.legend.offtimetxt = uicontrol(obj.figMain.XCite.pwm.legend.panel);
            obj.figMain.XCite.pwm.legend.offtimetxt.Style = 'edit';
            obj.figMain.XCite.pwm.legend.offtimetxt.Units = 'normalized';
            obj.figMain.XCite.pwm.legend.offtimetxt.String = 'Off';
            obj.figMain.XCite.pwm.legend.offtimetxt.Enable = 'inactive';
            obj.figMain.XCite.pwm.legend.delaytxt = uicontrol(obj.figMain.XCite.pwm.legend.panel);
            obj.figMain.XCite.pwm.legend.delaytxt.Style = 'edit';
            obj.figMain.XCite.pwm.legend.delaytxt.Units = 'normalized';
            obj.figMain.XCite.pwm.legend.delaytxt.String = 'Delay';
            obj.figMain.XCite.pwm.legend.delaytxt.Enable = 'inactive';
            obj.figMain.XCite.pwm.legend.triggertxt = uicontrol(obj.figMain.XCite.pwm.legend.panel);
            obj.figMain.XCite.pwm.legend.triggertxt.Style = 'edit';
            obj.figMain.XCite.pwm.legend.triggertxt.Units = 'normalized';
            obj.figMain.XCite.pwm.legend.triggertxt.String = 'Trigger';
            obj.figMain.XCite.pwm.legend.triggertxt.Enable = 'inactive';
            obj.figMain.XCite.pwm.edit.panel = uipanel(obj.figMain.XCite.pwm.panel);
            obj.figMain.XCite.pwm.edit.panel.BorderType = 'none';
            for ind=1:obj.settings.XCite.numled
                obj.figMain.XCite.pwm.LED(ind).panel = uipanel(obj.figMain.XCite.pwm.edit.panel);
                obj.figMain.XCite.pwm.LED(ind).panel.BorderType = 'none';
                obj.figMain.XCite.pwm.LED(ind).units = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).units.Style = 'popupmenu';
                obj.figMain.XCite.pwm.LED(ind).units.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).units.String = {'10 us','ms','s'};
                obj.figMain.XCite.pwm.LED(ind).units.Tag = 'LEDUnitsPopupmenu';
                obj.figMain.XCite.pwm.LED(ind).units.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).coltitle = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).coltitle.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).coltitle.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).coltitle.String = ['LED' num2str(ind)];
                obj.figMain.XCite.pwm.LED(ind).coltitle.Enable = 'inactive';
                obj.figMain.XCite.pwm.LED(ind).ontime = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).ontime.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).ontime.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).ontime.String = '1';
                obj.figMain.XCite.pwm.LED(ind).ontime.Tag = 'LEDOntimeEdit';
                obj.figMain.XCite.pwm.LED(ind).ontime.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).offtime = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).offtime.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).offtime.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).offtime.String = '1';
                obj.figMain.XCite.pwm.LED(ind).offtime.Tag = 'LEDOfftimeEdit';
                obj.figMain.XCite.pwm.LED(ind).offtime.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).delay = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).delay.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).delay.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).delay.String = '0';
                obj.figMain.XCite.pwm.LED(ind).delay.Tag = 'LEDDelayEdit';
                obj.figMain.XCite.pwm.LED(ind).delay.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).trigger = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).trigger.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).trigger.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).trigger.String = '0';
                obj.figMain.XCite.pwm.LED(ind).trigger.Tag = 'LEDTriggerEdit';
                obj.figMain.XCite.pwm.LED(ind).trigger.Callback = @obj.XCiteCallback;
            end
        end
        
        function init_DMDTab(obj)
            obj.figMain.DMD.status.panel =  uipanel(obj.figMain.DMD.tab);
            obj.figMain.DMD.status.panel.Title = 'Status';
                obj.figMain.DMD.status.controllerfirmwaretextlegend = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.controllerfirmwaretextlegend.Style = 'edit';
                obj.figMain.DMD.status.controllerfirmwaretextlegend.Units = 'normalized';
                obj.figMain.DMD.status.controllerfirmwaretextlegend.String = 'Controller Firmware';
                obj.figMain.DMD.status.controllerfirmwaretextlegend.Enable = 'inactive';
                
                obj.figMain.DMD.status.devicecounttextlegend = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.devicecounttextlegend.Style = 'edit';
                obj.figMain.DMD.status.devicecounttextlegend.Units = 'normalized';
                obj.figMain.DMD.status.devicecounttextlegend.String = 'Device Count';
                obj.figMain.DMD.status.devicecounttextlegend.Enable = 'inactive';
                
                obj.figMain.DMD.status.devicetypetextlegend = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.devicetypetextlegend.Style = 'edit';
                obj.figMain.DMD.status.devicetypetextlegend.Units = 'normalized';
                obj.figMain.DMD.status.devicetypetextlegend.String = 'Device Type';
                obj.figMain.DMD.status.devicetypetextlegend.Enable = 'inactive';
                
                obj.figMain.DMD.status.firmwaretextlegend = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.firmwaretextlegend.Style = 'edit';
                obj.figMain.DMD.status.firmwaretextlegend.Units = 'normalized';
                obj.figMain.DMD.status.firmwaretextlegend.String = 'Firmware';
                obj.figMain.DMD.status.firmwaretextlegend.Enable = 'inactive';
                
                obj.figMain.DMD.status.serialnumbertextlegend = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.serialnumbertextlegend.Style = 'edit';
                obj.figMain.DMD.status.serialnumbertextlegend.Units = 'normalized';
                obj.figMain.DMD.status.serialnumbertextlegend.String = 'Serial Number';
                obj.figMain.DMD.status.serialnumbertextlegend.Enable = 'inactive';
                
                obj.figMain.DMD.status.softwaretextlegend = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.softwaretextlegend.Style = 'edit';
                obj.figMain.DMD.status.softwaretextlegend.Units = 'normalized';
                obj.figMain.DMD.status.softwaretextlegend.String = 'Software';
                obj.figMain.DMD.status.softwaretextlegend.Enable = 'inactive';
                
            	obj.figMain.DMD.status.controllerfirmwaretext = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.controllerfirmwaretext.Style = 'edit';
                obj.figMain.DMD.status.controllerfirmwaretext.Units = 'normalized';
                obj.figMain.DMD.status.controllerfirmwaretext.String = '';
                obj.figMain.DMD.status.controllerfirmwaretext.Enable = 'inactive';
                
                obj.figMain.DMD.status.devicecounttext = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.devicecounttext.Style = 'edit';
                obj.figMain.DMD.status.devicecounttext.Units = 'normalized';
                obj.figMain.DMD.status.devicecounttext.String = '';
                obj.figMain.DMD.status.devicecounttext.Enable = 'inactive';
                
                obj.figMain.DMD.status.devicetypetext = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.devicetypetext.Style = 'edit';
                obj.figMain.DMD.status.devicetypetext.Units = 'normalized';
                obj.figMain.DMD.status.devicetypetext.String = '';
                obj.figMain.DMD.status.devicetypetext.Enable = 'inactive';
                
                obj.figMain.DMD.status.firmwaretext = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.firmwaretext.Style = 'edit';
                obj.figMain.DMD.status.firmwaretext.Units = 'normalized';
                obj.figMain.DMD.status.firmwaretext.String = '';
                obj.figMain.DMD.status.firmwaretext.Enable = 'inactive';
                
                obj.figMain.DMD.status.serialnumbertext = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.serialnumbertext.Style = 'edit';
                obj.figMain.DMD.status.serialnumbertext.Units = 'normalized';
                obj.figMain.DMD.status.serialnumbertext.String = '';
                obj.figMain.DMD.status.serialnumbertext.Enable = 'inactive';
                
                obj.figMain.DMD.status.softwaretext = uicontrol(obj.figMain.DMD.status.panel);
                obj.figMain.DMD.status.softwaretext.Style = 'edit';
                obj.figMain.DMD.status.softwaretext.Units = 'normalized';
                obj.figMain.DMD.status.softwaretext.String = '';
                obj.figMain.DMD.status.softwaretext.Enable = 'inactive';
                
            obj.figMain.DMD.controls.panel = uipanel(obj.figMain.DMD.tab);
                obj.figMain.DMD.controls.drawroi = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.drawroi.Style = 'pushbutton';
                obj.figMain.DMD.controls.drawroi.Units = 'normalized';
                obj.figMain.DMD.controls.drawroi.String = 'Draw ROI';
                obj.figMain.DMD.controls.drawroi.Tag = 'DrawRoiButton';
                obj.figMain.DMD.controls.drawroi.Callback = @obj.DMDCallback;

                obj.figMain.DMD.controls.clearroi = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.clearroi.Style = 'pushbutton';
                obj.figMain.DMD.controls.clearroi.Units = 'normalized';
                obj.figMain.DMD.controls.clearroi.String = 'Clear ROI';
                obj.figMain.DMD.controls.clearroi.Tag = 'ClearRoiButton';
                obj.figMain.DMD.controls.clearroi.Callback = @obj.DMDCallback;

                obj.figMain.DMD.controls.Checkerboard = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.Checkerboard.Style = 'pushbutton';
                obj.figMain.DMD.controls.Checkerboard.Units = 'normalized';
                obj.figMain.DMD.controls.Checkerboard.String = 'Checkerboard';
                obj.figMain.DMD.controls.Checkerboard.Tag = 'CheckerboardButton';
                obj.figMain.DMD.controls.Checkerboard.Callback = @obj.DMDCallback;

                obj.figMain.DMD.controls.whitefiled = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.whitefiled.Style = 'pushbutton';
                obj.figMain.DMD.controls.whitefiled.Units = 'normalized';
                obj.figMain.DMD.controls.whitefiled.String = 'Whitefield';
                obj.figMain.DMD.controls.whitefiled.Tag = 'WhitefieldButton';
                obj.figMain.DMD.controls.whitefiled.Callback = @obj.DMDCallback;

                obj.figMain.DMD.controls.trigger = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.trigger.Style = 'popupmenu';
                obj.figMain.DMD.controls.trigger.Units = 'normalized';
                obj.figMain.DMD.controls.trigger.String = {'InternalExpose',...
                                                           'InternalSoftware',...
                                                           'ExternalExpose',...
                                                           'ExternalSequenceStart',...
                                                           'ExternalBulb'};
                obj.figMain.DMD.controls.trigger.Tag = 'TriggerPopupmenu';
                obj.figMain.DMD.controls.trigger.Callback = @obj.DMDCallback;
                
                obj.figMain.DMD.controls.triggertext = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.triggertext.Style = 'edit';
                obj.figMain.DMD.controls.triggertext.Units = 'normalized';
                obj.figMain.DMD.controls.triggertext.String = 'Trigger';
                obj.figMain.DMD.controls.triggertext.Enable = 'inactive';
                
                obj.figMain.DMD.controls.operation = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.operation.Style = 'popupmenu';
                obj.figMain.DMD.controls.operation.Units = 'normalized';
                obj.figMain.DMD.controls.operation.String = {'Live',...
                                                             'FrameMemory',...
                                                             'FrameSequence',...
                                                             'ContinuousFrameSequence'};  
                obj.figMain.DMD.controls.operation.Tag = 'OperationPopupmenu';
                obj.figMain.DMD.controls.operation.Callback = @obj.DMDCallback;
                
                obj.figMain.DMD.controls.operationtext = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.operationtext.Style = 'edit';
                obj.figMain.DMD.controls.operationtext.Units = 'normalized';
                obj.figMain.DMD.controls.operationtext.String = 'Operation';
                obj.figMain.DMD.controls.operationtext.Enable = 'inactive';
                
                obj.figMain.DMD.controls.frameIdxSource = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.frameIdxSource.Style = 'popupmenu';
                obj.figMain.DMD.controls.frameIdxSource.Units = 'normalized';
                obj.figMain.DMD.controls.frameIdxSource.String = {'Software',...
                                                             'Hardware'};  
                obj.figMain.DMD.controls.frameIdxSource.Tag = 'frameIdxSourcePopupmenu';
                obj.figMain.DMD.controls.frameIdxSource.Callback = @obj.DMDCallback;
                
                obj.figMain.DMD.controls.frameIdxSourcetext = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.frameIdxSourcetext.Style = 'edit';
                obj.figMain.DMD.controls.frameIdxSourcetext.Units = 'normalized';
                obj.figMain.DMD.controls.frameIdxSourcetext.String = 'Frame Idx Src';
                obj.figMain.DMD.controls.frameIdxSourcetext.Enable = 'inactive';
                
                obj.figMain.DMD.controls.pixelEncoding = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.pixelEncoding.Style = 'popupmenu';
                obj.figMain.DMD.controls.pixelEncoding.Units = 'normalized';
                obj.figMain.DMD.controls.pixelEncoding.String = {'Mono1Packed',...
                                                             'Mono1'};  
                obj.figMain.DMD.controls.pixelEncoding.Tag = 'pixelEncodingPopupmenu';
                obj.figMain.DMD.controls.pixelEncoding.Callback = @obj.DMDCallback;
                
                obj.figMain.DMD.controls.pixelEncodingtext = uicontrol(obj.figMain.DMD.controls.panel);
                obj.figMain.DMD.controls.pixelEncodingtext.Style = 'edit';
                obj.figMain.DMD.controls.pixelEncodingtext.Units = 'normalized';
                obj.figMain.DMD.controls.pixelEncodingtext.String = 'Pixel Encoding';
                obj.figMain.DMD.controls.pixelEncodingtext.Enable = 'inactive'; 
                
            obj.figMain.DMD.mask.panel = uipanel(obj.figMain.DMD.tab);
            obj.figMain.DMD.mask.panel.Title = 'Mask'; 
                obj.figMain.DMD.mask.tabgroup = uitabgroup(obj.figMain.DMD.mask.panel);

                obj.figMain.DMD.mask.tab2P = uitab(obj.figMain.DMD.mask.tabgroup);
                obj.figMain.DMD.mask.tab2P.Title = '2P';
                
                %TODO put axis inside a panel
                obj.figMain.DMD.mask.axis2P = axes(obj.figMain.DMD.mask.tab2P);
                obj.figMain.DMD.mask.image2P = imshow(obj.images.TwoP,...
                    'Parent',obj.figMain.DMD.mask.axis2P);
                obj.figMain.DMD.mask.poly2P = [];

                obj.figMain.DMD.mask.tabCam = uitab(obj.figMain.DMD.mask.tabgroup);
                obj.figMain.DMD.mask.tabCam.Title = 'Camera';
                
                %TODO put axis inside a panel
                obj.figMain.DMD.mask.axisCam = axes(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.imageCam = imshow(obj.images.Cam,[0 255],...
                    'Parent',obj.figMain.DMD.mask.axisCam);
                setappdata(obj.figMain.DMD.mask.imageCam,'UpdatePreviewWindowFcn',@obj.CamFramePreviewedFcn);
                obj.figMain.DMD.mask.polyCam = [];

                %TODO put those inside a panel
                obj.figMain.DMD.mask.startpreview = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.startpreview.Style = 'pushbutton';
                obj.figMain.DMD.mask.startpreview.Units = 'normalized';
                obj.figMain.DMD.mask.startpreview.String = 'Preview';
                obj.figMain.DMD.mask.startpreview.Tag = 'StartPreviewButton';
                obj.figMain.DMD.mask.startpreview.Callback = @obj.DMDCallback;

                obj.figMain.DMD.mask.stoppreview = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.stoppreview.Style = 'pushbutton';
                obj.figMain.DMD.mask.stoppreview.Units = 'normalized';
                obj.figMain.DMD.mask.stoppreview.String = 'Stop';
                obj.figMain.DMD.mask.stoppreview.Tag = 'StopPreviewButton';
                obj.figMain.DMD.mask.stoppreview.Callback = @obj.DMDCallback; 

                obj.figMain.DMD.mask.exposuretext = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.exposuretext.Style = 'edit';
                obj.figMain.DMD.mask.exposuretext.Units = 'normalized';
                obj.figMain.DMD.mask.exposuretext.String = 'Exposure';
                obj.figMain.DMD.mask.exposuretext.Enable = 'inactive';

                obj.figMain.DMD.mask.exposure = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.exposure.Style = 'slider';
                obj.figMain.DMD.mask.exposure.Units = 'normalized';
                obj.figMain.DMD.mask.exposure.Tag = 'CamExposureSlider';
                obj.figMain.DMD.mask.exposure.Value = obj.settings.cam.Exposure.DefaultValue;
                obj.figMain.DMD.mask.exposure.Min = obj.settings.cam.Exposure.ConstraintValue(1);
                obj.figMain.DMD.mask.exposure.Max = obj.settings.cam.Exposure.ConstraintValue(2);
                obj.figMain.DMD.mask.exposure.Callback = @obj.DMDCallback;

                obj.figMain.DMD.mask.gaintext = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.gaintext.Style = 'edit';
                obj.figMain.DMD.mask.gaintext.Units = 'normalized';
                obj.figMain.DMD.mask.gaintext.String = 'Gain';
                obj.figMain.DMD.mask.gaintext.Enable = 'inactive';

                obj.figMain.DMD.mask.gain = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.gain.Style = 'slider';
                obj.figMain.DMD.mask.gain.Units = 'normalized';
                obj.figMain.DMD.mask.gain.Tag = 'CamGainSlider';
                obj.figMain.DMD.mask.gain.Value = obj.settings.cam.Gain.DefaultValue;
                obj.figMain.DMD.mask.gain.Min = obj.settings.cam.Gain.ConstraintValue(1);
                obj.figMain.DMD.mask.gain.Max = obj.settings.cam.Gain.ConstraintValue(2);
                obj.figMain.DMD.mask.gain.Callback = @obj.DMDCallback;

                obj.figMain.DMD.mask.framerate = uicontrol(obj.figMain.DMD.mask.tabCam);
                obj.figMain.DMD.mask.framerate.Style = 'popupmenu';
                obj.figMain.DMD.mask.framerate.Units = 'normalized';
                obj.figMain.DMD.mask.framerate.Tag = 'CamFrameRatePopumenu';
                obj.figMain.DMD.mask.framerate.String = obj.settings.cam.FrameRate.ConstraintValue;
                obj.figMain.DMD.mask.framerate.Callback = @obj.DMDCallback;

                obj.figMain.DMD.mask.tabSensor = uitab(obj.figMain.DMD.mask.tabgroup);
                obj.figMain.DMD.mask.tabSensor.Title = 'DMD Sensor';
                %TODO put axis inside a panel
                obj.figMain.DMD.mask.axisSensor = axes(obj.figMain.DMD.mask.tabSensor);
                obj.figMain.DMD.mask.imageSensor = imshow(obj.images.Sensor,...
                    'Parent',obj.figMain.DMD.mask.axisSensor);
                obj.figMain.DMD.mask.polySensor = [];
            
            obj.figMain.DMD.roi.panel = uipanel(obj.figMain.DMD.tab);
                obj.figMain.DMD.roi.masklist.panel = uipanel(obj.figMain.DMD.roi.panel);
                obj.figMain.DMD.roi.masklist.panel.Title = 'Live';
                    obj.figMain.DMD.roi.masklist.table = uitable(obj.figMain.DMD.roi.masklist.panel);
                    obj.figMain.DMD.roi.masklist.table.Data = [];
                    obj.figMain.DMD.roi.masklist.table.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.table.ColumnName = {'Name','Exp Time', 'Visible'};
                    obj.figMain.DMD.roi.masklist.table.ColumnFormat = {'char','numeric','logical'};
                    obj.figMain.DMD.roi.masklist.table.RowName = [];
                    obj.figMain.DMD.roi.masklist.table.ColumnEditable = [false true true]; 
                    obj.figMain.DMD.roi.masklist.table.Tag = 'RoiListTable';
                    obj.figMain.DMD.roi.masklist.table.CellSelectionCallback = @obj.DMDCallback;
                    obj.figMain.DMD.roi.masklist.table.CellEditCallback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.masklist.editnamelegend = uicontrol(obj.figMain.DMD.roi.masklist.panel); 
                    obj.figMain.DMD.roi.masklist.editnamelegend.Style = 'edit';
                    obj.figMain.DMD.roi.masklist.editnamelegend.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.editnamelegend.String = 'Mask name';
                    obj.figMain.DMD.roi.masklist.editnamelegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.masklist.editname = uicontrol(obj.figMain.DMD.roi.masklist.panel); 
                    obj.figMain.DMD.roi.masklist.editname.Style = 'edit';
                    obj.figMain.DMD.roi.masklist.editname.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.editname.String = 'none';
                    
                    obj.figMain.DMD.roi.masklist.flatten = uicontrol(obj.figMain.DMD.roi.masklist.panel);                
                    obj.figMain.DMD.roi.masklist.flatten.Style = 'pushbutton';
                    obj.figMain.DMD.roi.masklist.flatten.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.flatten.String = 'Flatten Masks';
                    obj.figMain.DMD.roi.masklist.flatten.Tag = 'FlattenButton';
                    obj.figMain.DMD.roi.masklist.flatten.Callback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.masklist.add = uicontrol(obj.figMain.DMD.roi.masklist.panel);
                    obj.figMain.DMD.roi.masklist.add.Style = 'pushbutton';
                    obj.figMain.DMD.roi.masklist.add.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.add.String = 'Add';
                    obj.figMain.DMD.roi.masklist.add.Tag = 'AddRoiButton';
                    obj.figMain.DMD.roi.masklist.add.Callback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.masklist.remove = uicontrol(obj.figMain.DMD.roi.masklist.panel);
                    obj.figMain.DMD.roi.masklist.remove.Style = 'pushbutton';
                    obj.figMain.DMD.roi.masklist.remove.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.remove.String = 'Remove';
                    obj.figMain.DMD.roi.masklist.remove.Tag = 'RemoveRoiButton';
                    obj.figMain.DMD.roi.masklist.remove.Callback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.masklist.queue = uicontrol(obj.figMain.DMD.roi.masklist.panel);
                    obj.figMain.DMD.roi.masklist.queue.Style = 'pushbutton';
                    obj.figMain.DMD.roi.masklist.queue.Units = 'normalized';
                    obj.figMain.DMD.roi.masklist.queue.String = 'Queue Buffer';
                    obj.figMain.DMD.roi.masklist.queue.Tag = 'QueueButton';
                    obj.figMain.DMD.roi.masklist.queue.Callback = @obj.DMDCallback;
                    
                obj.figMain.DMD.roi.framemem.panel = uipanel(obj.figMain.DMD.roi.panel);
                obj.figMain.DMD.roi.framemem.panel.Title = 'Frame Memory';
                    obj.figMain.DMD.roi.framemem.table = uitable(obj.figMain.DMD.roi.framemem.panel);
                    obj.figMain.DMD.roi.framemem.table.Data = [];
                    obj.figMain.DMD.roi.framemem.table.Units = 'normalized';
                    obj.figMain.DMD.roi.framemem.table.ColumnName = {'Frame Ind','Name','Exp Time'};
                    obj.figMain.DMD.roi.framemem.table.RowName = [];
                    obj.figMain.DMD.roi.framemem.table.ColumnEditable = [false false true];
                    obj.figMain.DMD.roi.framemem.table.Tag = 'FrameMemoryTable';
                    obj.figMain.DMD.roi.framemem.table.CellSelectionCallback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.framemem.upload = uicontrol(obj.figMain.DMD.roi.framemem.panel);
                    obj.figMain.DMD.roi.framemem.upload.Style = 'pushbutton';
                    obj.figMain.DMD.roi.framemem.upload.Units = 'normalized';
                    obj.figMain.DMD.roi.framemem.upload.String = 'Upload';
                    obj.figMain.DMD.roi.framemem.upload.Tag = 'UploadFrameButton';
                    obj.figMain.DMD.roi.framemem.upload.Callback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.framemem.clear = uicontrol(obj.figMain.DMD.roi.framemem.panel);
                    obj.figMain.DMD.roi.framemem.clear.Style = 'pushbutton';
                    obj.figMain.DMD.roi.framemem.clear.Units = 'normalized';
                    obj.figMain.DMD.roi.framemem.clear.String = 'Clear';
                    obj.figMain.DMD.roi.framemem.clear.Tag = 'ClearFrameButton';
                    obj.figMain.DMD.roi.framemem.clear.Callback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.framemem.framecounttextlegend = uicontrol(obj.figMain.DMD.roi.framemem.panel); 
                    obj.figMain.DMD.roi.framemem.framecounttextlegend.Style = 'edit';
                    obj.figMain.DMD.roi.framemem.framecounttextlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.framemem.framecounttextlegend.String = 'Frame Count';
                    obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.framemem.framecounttext = uicontrol(obj.figMain.DMD.roi.framemem.panel); 
                    obj.figMain.DMD.roi.framemem.framecounttext.Style = 'edit';
                    obj.figMain.DMD.roi.framemem.framecounttext.Units = 'normalized';
                    obj.figMain.DMD.roi.framemem.framecounttext.String = 'none';
                    obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                    
                obj.figMain.DMD.roi.seqmem.panel = uipanel(obj.figMain.DMD.roi.panel);
                obj.figMain.DMD.roi.seqmem.panel.Title = 'Sequence Memory';
                    obj.figMain.DMD.roi.seqmem.table = uitable(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.table.Data = [];
                    obj.figMain.DMD.roi.seqmem.table.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.table.ColumnName = {'Frame Ind',...
                                                            'Frame Count',...
                                                            'Frame Cycle',...
                                                            'Exp Time',...
                                                            'Gap Time'};
                    obj.figMain.DMD.roi.seqmem.table.RowName = [];
                    obj.figMain.DMD.roi.seqmem.table.ColumnEditable = false;
                    
                    obj.figMain.DMD.roi.seqmem.frameindextextlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.frameindextextlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.frameindextextlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.frameindextextlegend.String = 'Frame Ind';
                    obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.frameindextext = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.frameindextext.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.frameindextext.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.frameindextext.String = 'none';
                    obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.framecounteditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.framecounteditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.framecounteditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.framecounteditlegend.String = 'Frame Count';
                    obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.framecountedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.framecountedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.framecountedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.framecountedit.String = 'none';
                    
                    obj.figMain.DMD.roi.seqmem.loopeditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.loopeditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.loopeditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.loopeditlegend.String = 'Frame Cycle';
                    obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.loopedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.loopedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.loopedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.loopedit.String = 'none';
                    
                    obj.figMain.DMD.roi.seqmem.expeditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.expeditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.expeditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.expeditlegend.String = 'Exp Time';
                    obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.expedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.expedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.expedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.expedit.String = 'none';
                    
                    obj.figMain.DMD.roi.seqmem.gapeditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.gapeditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.gapeditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.gapeditlegend.String = 'Gap Time';
                    obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.gapedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.gapedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.gapedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.gapedit.String = 'none';
                                                        
                    obj.figMain.DMD.roi.seqmem.uploadseq = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.uploadseq.Style = 'pushbutton';
                    obj.figMain.DMD.roi.seqmem.uploadseq.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.uploadseq.String = 'Upload Sequence';
                    obj.figMain.DMD.roi.seqmem.uploadseq.Tag = 'UploadSequenceButton';
                    obj.figMain.DMD.roi.seqmem.uploadseq.Callback = @obj.DMDCallback;

                    obj.figMain.DMD.roi.seqmem.clearseq = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.clearseq.Style = 'pushbutton';
                    obj.figMain.DMD.roi.seqmem.clearseq.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.clearseq.String = 'Clear Sequence';
                    obj.figMain.DMD.roi.seqmem.clearseq.Tag = 'ClearSequenceButton';
                    obj.figMain.DMD.roi.seqmem.clearseq.Callback = @obj.DMDCallback;
                    
                    obj.figMain.DMD.roi.seqmem.seqcounteditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqcounteditlegend.String = 'Seq Count';
                    obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.seqcountedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqcountedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqcountedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqcountedit.String = 'none';
                    obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.seqstartindeditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.String = 'Seq Start';
                    obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.seqstartindedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqstartindedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqstartindedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqstartindedit.String = 'none';
                    
                    obj.figMain.DMD.roi.seqmem.seqlengtheditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.String = 'Seq Length';
                    obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.seqlengthedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqlengthedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqlengthedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqlengthedit.String = 'none';
                    
                    obj.figMain.DMD.roi.seqmem.seqloopeditlegend = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqloopeditlegend.String = 'Seq Loop';
                    obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'inactive';
                    
                    obj.figMain.DMD.roi.seqmem.seqloopedit = uicontrol(obj.figMain.DMD.roi.seqmem.panel);
                    obj.figMain.DMD.roi.seqmem.seqloopedit.Style = 'edit';
                    obj.figMain.DMD.roi.seqmem.seqloopedit.Units = 'normalized';
                    obj.figMain.DMD.roi.seqmem.seqloopedit.String = 'none';
                    
                obj.figMain.DMD.roi.roictrl.panel = uipanel(obj.figMain.DMD.roi.panel);
                    
                    obj.figMain.DMD.roi.roictrl.expose = uicontrol(obj.figMain.DMD.roi.roictrl.panel);
                    obj.figMain.DMD.roi.roictrl.expose.Style = 'pushbutton';
                    obj.figMain.DMD.roi.roictrl.expose.Units = 'normalized';
                    obj.figMain.DMD.roi.roictrl.expose.String = 'Expose';
                    obj.figMain.DMD.roi.roictrl.expose.Tag = 'ExposeButton';
                    obj.figMain.DMD.roi.roictrl.expose.Callback = @obj.DMDCallback;

                    obj.figMain.DMD.roi.roictrl.abort = uicontrol(obj.figMain.DMD.roi.roictrl.panel);
                    obj.figMain.DMD.roi.roictrl.abort.Style = 'pushbutton';
                    obj.figMain.DMD.roi.roictrl.abort.Units = 'normalized';
                    obj.figMain.DMD.roi.roictrl.abort.String = 'Abort';
                    obj.figMain.DMD.roi.roictrl.abort.Tag = 'AbortButton';
                    obj.figMain.DMD.roi.roictrl.abort.Callback = @obj.DMDCallback;
        end
        
        function init_CalibrationTab(obj)
            obj.figMain.Calibration.twop.panel = uipanel(obj.figMain.Calibration.tab);
            obj.figMain.Calibration.twop.panel.Title = '2P';
                obj.figMain.Calibration.twop.axis.panel = uipanel(obj.figMain.Calibration.twop.panel);
                obj.figMain.Calibration.twop.axis.axis2P = axes(obj.figMain.Calibration.twop.axis.panel);
                    obj.figMain.Calibration.twop.axis.image2P = imshow(obj.images.TwoP,...
                        'Parent',obj.figMain.Calibration.twop.axis.axis2P);

                obj.figMain.Calibration.twop.register.panel = uipanel(obj.figMain.Calibration.twop.panel);
                    obj.figMain.Calibration.twop.register.registerbutton = uicontrol(obj.figMain.Calibration.twop.register.panel);
                    obj.figMain.Calibration.twop.register.registerbutton.Style = 'pushbutton';
                    obj.figMain.Calibration.twop.register.registerbutton.Units = 'normalized';
                    obj.figMain.Calibration.twop.register.registerbutton.String = '2P <-> Cam';
                    obj.figMain.Calibration.twop.register.registerbutton.Tag = 'Register2PCamButton';
                    obj.figMain.Calibration.twop.register.registerbutton.Callback = @obj.CalibrationCallback;
                    
                obj.figMain.Calibration.twop.transform.panel = uipanel(obj.figMain.Calibration.twop.panel);
                    obj.figMain.Calibration.twop.transform.twop2camtable = uitable(obj.figMain.Calibration.twop.transform.panel);
                    obj.figMain.Calibration.twop.transform.twop2camtable.Data = [];
                    obj.figMain.Calibration.twop.transform.twop2camtable.Units = 'normalized';
                    obj.figMain.Calibration.twop.transform.twop2camtable.ColumnEditable = false; 
                    
                    obj.figMain.Calibration.twop.transform.twop2sensortable = uitable(obj.figMain.Calibration.twop.transform.panel);
                    obj.figMain.Calibration.twop.transform.twop2sensortable.Data = [];
                    obj.figMain.Calibration.twop.transform.twop2sensortable.Units = 'normalized';
                    obj.figMain.Calibration.twop.transform.twop2sensortable.ColumnEditable = false; 
                    
            obj.figMain.Calibration.cam.panel = uipanel(obj.figMain.Calibration.tab);
            obj.figMain.Calibration.cam.panel.Title = 'Camera';
                obj.figMain.Calibration.cam.axis.panel = uipanel(obj.figMain.Calibration.cam.panel);
                    obj.figMain.DMD.mask.axis.axisCam = axes(obj.figMain.Calibration.cam.axis.panel);
                    obj.figMain.Calibration.cam.axis.imageCam = imshow(obj.images.Cam,[0 255],...
                        'Parent',obj.figMain.DMD.mask.axis.axisCam);
                    
                obj.figMain.Calibration.cam.register.panel = uipanel(obj.figMain.Calibration.cam.panel);
                    obj.figMain.Calibration.cam.register.registerbutton = uicontrol(obj.figMain.Calibration.cam.register.panel);
                    obj.figMain.Calibration.cam.register.registerbutton.Style = 'pushbutton';
                    obj.figMain.Calibration.cam.register.registerbutton.Units = 'normalized';
                    obj.figMain.Calibration.cam.register.registerbutton.String = 'Cam <-> Sensor';
                    obj.figMain.Calibration.cam.register.registerbutton.Tag = 'RegisterCamSensorButton';
                    obj.figMain.Calibration.cam.register.registerbutton.Callback = @obj.CalibrationCallback;
                    
                obj.figMain.Calibration.cam.transform.panel = uipanel(obj.figMain.Calibration.cam.panel);
                    obj.figMain.Calibration.cam.transform.cam2twoptable = uitable(obj.figMain.Calibration.cam.transform.panel);
                    obj.figMain.Calibration.cam.transform.cam2twoptable.Data = [];
                    obj.figMain.Calibration.cam.transform.cam2twoptable.Units = 'normalized';
                    obj.figMain.Calibration.cam.transform.cam2twoptable.ColumnEditable = false; 
                    
                    obj.figMain.Calibration.cam.transform.cam2sensortable = uitable(obj.figMain.Calibration.cam.transform.panel);
                    obj.figMain.Calibration.cam.transform.cam2sensortable.Data = [];
                    obj.figMain.Calibration.cam.transform.cam2sensortable.Units = 'normalized';
                    obj.figMain.Calibration.cam.transform.cam2sensortable.ColumnEditable = false; 
                    
            obj.figMain.Calibration.sensor.panel = uipanel(obj.figMain.Calibration.tab);
            obj.figMain.Calibration.sensor.panel.Title = 'Sensor';
                obj.figMain.Calibration.sensor.axis.panel = uipanel(obj.figMain.Calibration.sensor.panel);
                    obj.figMain.Calibration.sensor.axis.axisSensor = axes(obj.figMain.Calibration.sensor.axis.panel);
                    obj.figMain.Calibration.sensor.axis.imageSensor = imshow(obj.images.Sensor,...
                        'Parent',obj.figMain.Calibration.sensor.axis.axisSensor);
                    
                obj.figMain.Calibration.sensor.register.panel = uipanel(obj.figMain.Calibration.sensor.panel);
                    obj.figMain.Calibration.sensor.register.registerbutton = uicontrol(obj.figMain.Calibration.sensor.register.panel);
                    obj.figMain.Calibration.sensor.register.registerbutton.Style = 'pushbutton';
                    obj.figMain.Calibration.sensor.register.registerbutton.Units = 'normalized';
                    obj.figMain.Calibration.sensor.register.registerbutton.String = 'Sensor <-> 2P';
                    obj.figMain.Calibration.sensor.register.registerbutton.Tag = 'RegisterSensor2PButton';
                    obj.figMain.Calibration.sensor.register.registerbutton.Callback = @obj.CalibrationCallback;
                    
                obj.figMain.Calibration.sensor.transform.panel = uipanel(obj.figMain.Calibration.sensor.panel);  
                    obj.figMain.Calibration.sensor.transform.sensor2twoptable = uitable(obj.figMain.Calibration.sensor.transform.panel);
                    obj.figMain.Calibration.sensor.transform.sensor2twoptable.Data = [];
                    obj.figMain.Calibration.sensor.transform.sensor2twoptable.Units = 'normalized';
                    obj.figMain.Calibration.sensor.transform.sensor2twoptable.ColumnEditable = false; 
                    
                    obj.figMain.Calibration.sensor.transform.sensor2camtable = uitable(obj.figMain.Calibration.sensor.transform.panel);
                    obj.figMain.Calibration.sensor.transform.sensor2camtable.Data = [];
                    obj.figMain.Calibration.sensor.transform.sensor2camtable.Units = 'normalized';
                    obj.figMain.Calibration.sensor.transform.sensor2camtable.ColumnEditable = false; 
        end
        
        function init_SegmentationTab(obj)
            obj.figMain.Segmentation.twop.panel = uipanel(obj.figMain.Segmentation.tab);
            obj.figMain.Segmentation.twop.panel.Title = '2P Image';
            obj.figMain.Segmentation.roitable.panel = uipanel(obj.figMain.Segmentation.tab);
            obj.figMain.Segmentation.roitable.panel.Title = 'ROI List';
            obj.figMain.Segmentation.roitable.table = uitable(obj.figMain.Segmentation.roitable.panel);
            obj.figMain.Segmentation.roitable.table.Units = 'normalized';
        end
        
        %% layout related functions
        function layout(obj)
            left = 20;
            bottom = 50;
            width = 1200;
            height = 800;
            
            % Windows layout
            obj.figMain.handle.Position = [left bottom width height];
    
            obj.layout_XCiteTab();
            obj.layout_DMDTab();
            obj.layout_CalibrationTab();
            obj.layout_SegmentationTab();
        end
        
        function layout_XCiteTab(obj)
            status = obj.figMain.XCite.status;
            status.panel.Position = [0 .5 1 .5];
            status.button.Position = [.6 0.4 .3 .4];
            status.softwareversion.Position = [0.5 0.1 .5 .1];
            status.serialnumber.Position = [0.5 0 .5 .1];
            status.legend.panel.Position = [0 .8 .5 .2];
            status.legend.ledname.Position = [0 0 .2 1];
            status.legend.ledhours.Position = [.2 0 .2 1];
            status.legend.ledmintemp.Position = [.4 0 .2 1];
            status.legend.ledtemp.Position = [.6 0 .2 1];
            status.legend.ledmaxtemp.Position = [.8 0 .2 1];
            for ind=1:obj.settings.XCite.numled
                status.LED(ind).panel.Position = [0 0.8*(1 - ind/obj.settings.XCite.numled) .5 .2];
                status.LED(ind).ledname.Position = [0 0 .2 1];
                status.LED(ind).ledhours.Position = [.2 0 .2 1];
                status.LED(ind).ledmintemp.Position = [.4 0 .2 1];
                status.LED(ind).ledtemp.Position = [.6 0 .2 1];
                status.LED(ind).ledmaxtemp.Position = [.8 0 .2 1];
            end
            
            leds = obj.figMain.XCite.leds;
            leds.panel.Position = [0 0 .5 .5];
            for ind=1:obj.settings.XCite.numled
                leds.LED(ind).panel.Position = [0 (1-ind/obj.settings.XCite.numled) 1 0.25];
                leds.LED(ind).pm.Position = [0 0.75 0.33 0.25];
                leds.LED(ind).button.Position = [0 0 0.33 0.75];
                leds.LED(ind).intensityTxt.Position = [0.33 0.75 0.66 0.25];
                leds.LED(ind).intensity.Position = [0.33 0 0.66 0.75];
            end
            
            pwm = obj.figMain.XCite.pwm;
            pwm.panel.Position = [.5 0 .5 .5];
            pwm.buttons.panel.Position = [0.2 .8 .8 .2];
            pwm.buttons.start.Position = [0 0 .5 1];
            pwm.buttons.repeat.Position = [.5 0 .5 1];
            pwm.legend.panel.Position = [0 0 .2 .8];
            pwm.legend.ontimetxt.Position = [0 0.6 1 0.2];
            pwm.legend.offtimetxt.Position = [0 0.4 1 0.2];
            pwm.legend.delaytxt.Position = [0 0.2 1 0.2];
            pwm.legend.triggertxt.Position = [0 0 1 0.2];
            pwm.edit.panel.Position = [.2 0 .8 .8];
            for ind=1:obj.settings.XCite.numled
                pwm.LED(ind).panel.Position = [(ind-1)/obj.settings.XCite.numled 0 0.25 1];
                pwm.LED(ind).coltitle.Position = [0 0.9 1 0.1];
                pwm.LED(ind).units.Position = [0 0.8 1 0.1];
                pwm.LED(ind).ontime.Position = [0 0.6 1 0.2];
                pwm.LED(ind).offtime.Position = [0 0.4 1 0.2];
                pwm.LED(ind).delay.Position = [0 0.2 1 0.2];
                pwm.LED(ind).trigger.Position = [0 0 1 0.2];
            end
        end
        
        function layout_DMDTab(obj)
            obj.figMain.DMD.status.panel.Position = [0 0 0.7 0.1];
                obj.figMain.DMD.status.controllerfirmwaretextlegend.Position = [0 0.5 1/6 0.5];
                obj.figMain.DMD.status.controllerfirmwaretext.Position = [0 0 1/6 0.5];
                
                obj.figMain.DMD.status.devicecounttextlegend.Position = [1/6 0.5 1/6 0.5];
                obj.figMain.DMD.status.devicecounttext.Position = [1/6 0 1/6 0.5];
                
                obj.figMain.DMD.status.devicetypetextlegend.Position = [2/6 0.5 1/6 0.5];
                obj.figMain.DMD.status.devicetypetext.Position = [2/6 0 1/6 0.5];
                
                obj.figMain.DMD.status.firmwaretextlegend.Position = [3/6 0.5 1/6 0.5];
                obj.figMain.DMD.status.firmwaretext.Position = [3/6 0 1/6 0.5];
                
                obj.figMain.DMD.status.serialnumbertextlegend.Position = [4/6 0.5 1/6 0.5];
                obj.figMain.DMD.status.serialnumbertext.Position = [4/6 0 1/6 0.5];
                
                obj.figMain.DMD.status.softwaretextlegend.Position = [5/6 0.5 1/6 0.5];
                obj.figMain.DMD.status.softwaretext.Position = [5/6 0 1/6 0.5];
                
            obj.figMain.DMD.controls.panel.Position = [0 0.9 0.7 0.1];
                obj.figMain.DMD.controls.drawroi.Position = [0 0 0.1 1];
                obj.figMain.DMD.controls.clearroi.Position = [0.1 0 0.1 1];
                obj.figMain.DMD.controls.Checkerboard.Position = [0.2 0 0.1 1];
                obj.figMain.DMD.controls.whitefiled.Position = [0.3 0 0.1 1];
                
                obj.figMain.DMD.controls.trigger.Position = [0.6 0 0.1 0.5];
                obj.figMain.DMD.controls.triggertext.Position = [0.6 0.5 0.1 0.5];
                obj.figMain.DMD.controls.operation.Position = [0.7 0 0.1 0.5];
                obj.figMain.DMD.controls.operationtext.Position = [0.7 0.5 0.1 0.5];
                obj.figMain.DMD.controls.frameIdxSource.Position = [0.8 0 0.1 0.5];
                obj.figMain.DMD.controls.frameIdxSourcetext.Position = [0.8 0.5 0.1 0.5];
                obj.figMain.DMD.controls.pixelEncoding.Position = [0.9 0 0.1 0.5];
                obj.figMain.DMD.controls.pixelEncodingtext.Position = [0.9 0.5 0.1 0.5];
            
            obj.figMain.DMD.mask.panel.Position = [0 0.1 0.7 0.8];
                obj.figMain.DMD.mask.startpreview.Position = [0 0.9 0.1 0.1]; 
                obj.figMain.DMD.mask.stoppreview.Position = [0.1 0.9 0.1 0.1];
                obj.figMain.DMD.mask.exposuretext.Position = [0.2 0.9 0.1 0.1];
                obj.figMain.DMD.mask.exposure.Position = [0.3 0.9 0.2 0.1];
                obj.figMain.DMD.mask.gaintext.Position = [0.5 0.9 0.1 0.1];
                obj.figMain.DMD.mask.gain.Position = [0.6 0.9 0.2 0.1];
                obj.figMain.DMD.mask.framerate.Position = [0.8 0.9 0.1 0.1];
            
            obj.figMain.DMD.roi.panel.Position = [0.7 0 0.3 1];
                obj.figMain.DMD.roi.masklist.panel.Position = [0 0.7 1 0.3];
                    obj.figMain.DMD.roi.masklist.table.Position = [0 0.6 1 0.4];
                    obj.figMain.DMD.roi.masklist.editname.Position = [0 0.4 0.5 0.1];
                    obj.figMain.DMD.roi.masklist.editnamelegend.Position = [0 0.5 0.5 0.1];
                    obj.figMain.DMD.roi.masklist.add.Position = [0 0.2 0.5 0.2];
                    obj.figMain.DMD.roi.masklist.remove.Position = [0.5 0.2 0.5 0.2];
                    obj.figMain.DMD.roi.masklist.queue.Position = [0 0 0.5 0.2];
                    obj.figMain.DMD.roi.masklist.flatten.Position = [0.5 0 0.5 0.2];

                obj.figMain.DMD.roi.framemem.panel.Position = [0 0.4 1 0.3];
                    obj.figMain.DMD.roi.framemem.table.Position = [0 0.4 1 0.6];
                    obj.figMain.DMD.roi.framemem.upload.Position = [0 0.2 0.5 0.2];
                    obj.figMain.DMD.roi.framemem.clear.Position =  [0.5 0.2 0.5 0.2];
                    obj.figMain.DMD.roi.framemem.framecounttext.Position = [0 0 0.5 0.1];
                    obj.figMain.DMD.roi.framemem.framecounttextlegend.Position = [0 0.1 0.5 0.1];

                obj.figMain.DMD.roi.seqmem.panel.Position = [0 0.1 1 0.3];
                    obj.figMain.DMD.roi.seqmem.table.Position = [0 0.6 1 0.4];
                    obj.figMain.DMD.roi.seqmem.frameindextext.Position = [0 0.4 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.frameindextextlegend.Position = [0 0.5 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.framecountedit.Position = [0.2 0.4 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.framecounteditlegend.Position = [0.2 0.5 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.loopedit.Position = [0.4 0.4 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.loopeditlegend.Position = [0.4 0.5 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.expedit.Position = [0.6 0.4 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.expeditlegend.Position = [0.6 0.5 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.gapedit.Position = [0.8 0.4 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.gapeditlegend.Position = [0.8 0.5 0.2 0.1];
                    obj.figMain.DMD.roi.seqmem.uploadseq.Position = [0 0.2 0.5 0.2];
                    obj.figMain.DMD.roi.seqmem.clearseq.Position = [0.5 0.2 0.5 0.2];
                    obj.figMain.DMD.roi.seqmem.seqcountedit.Position = [0 0 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Position = [0 0.1 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqstartindedit.Position = [0.25 0 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Position = [0.25 0.1 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqlengthedit.Position = [0.5 0 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Position = [0.5 0.1 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqloopedit.Position = [0.75 0 0.25 0.1];
                    obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Position = [0.75 0.1 0.25 0.1];

                obj.figMain.DMD.roi.roictrl.panel.Position = [0 0 1 0.1];
                    obj.figMain.DMD.roi.roictrl.expose.Position = [0 0 0.5 1];
                    obj.figMain.DMD.roi.roictrl.abort.Position = [0.5 0 0.5 1];
                    
           
        end
        
        function layout_CalibrationTab(obj)
            
            obj.figMain.Calibration.twop.panel.Position = [0 0 0.33 1];
                obj.figMain.Calibration.twop.axis.panel.Position = [0 0.66 1 0.33];

                obj.figMain.Calibration.twop.register.panel.Position = [0 0.33 1 0.33];
                    obj.figMain.Calibration.twop.register.registerbutton.Position = [0 0 1 0.1];
                    
                obj.figMain.Calibration.twop.transform.panel.Position = [0 0 1 0.33];
                    obj.figMain.Calibration.twop.transform.twop2camtable.Position = [0 0 0.5 1];
                    obj.figMain.Calibration.twop.transform.twop2sensortable.Position = [0.5 0 0.5 1];
                    
            obj.figMain.Calibration.cam.panel.Position = [0.33 0 0.33 1];
                obj.figMain.Calibration.cam.axis.panel.Position = [0 0.66 1 0.33];
                
                obj.figMain.Calibration.cam.register.panel.Position = [0 0.33 1 0.33];
                    obj.figMain.Calibration.cam.register.registerbutton.Position = [0 0 1 0.1];
                    
                obj.figMain.Calibration.cam.transform.panel.Position = [0 0 1 0.33];
                    obj.figMain.Calibration.cam.transform.cam2twoptable.Position = [0 0 0.5 1];
                    obj.figMain.Calibration.cam.transform.cam2sensortable.Position = [0.5 0 0.5 1];
                    
            obj.figMain.Calibration.sensor.panel.Position = [0.66 0 0.33 1];
                obj.figMain.Calibration.sensor.axis.panel.Position = [0 0.66 1 0.33];
                    
                obj.figMain.Calibration.sensor.register.panel.Position = [0 0.33 1 0.33];
                    obj.figMain.Calibration.sensor.register.registerbutton.Position = [0 0 1 0.1];
                    
                obj.figMain.Calibration.sensor.transform.panel.Position = [0 0 1 0.33];
                    obj.figMain.Calibration.sensor.transform.sensor2twoptable.Position = [0 0 0.5 1];
                    obj.figMain.Calibration.sensor.transform.sensor2camtable.Position = [0.5 0 0.5 1];
        end
        
        function layout_SegmentationTab(obj)
            obj.figMain.Segmentation.twop.panel.Position = [0 0 0.5 1];
            obj.figMain.Segmentation.roitable.panel.Position = [0.5 0 0.5 1];
            obj.figMain.Segmentation.roitable.table.Position = [0 0.3 1 0.7]; 
        end
        
        %% Windows Callback functions
        function onCloseMain(obj,~,~)
           selection = questdlg('Close OptogeneticsGUI?',...
                              'Confirmation',...
                              'Yes','No','Yes'); 
           switch selection 
              case 'Yes'
                  stoppreview(obj.hardware.Cam);
                  delete(obj.figMain.handle);
                  obj.delete();
              case 'No'
              return 
           end
        end
        
        function onTabChange(obj,src,evt)
            switch evt.NewValue
                case obj.figMain.XCite.tab
                    obj.XCiteRefresh();
                case obj.figMain.DMD.tab
                    obj.DMDRefresh();
            end
        end
        
        %% Components Callback functions 
        function XCiteCallback(obj,src,~)
            
            obj.hardware.XCite.connect();
            switch src.Tag
                case 'LEDButton'
                    % validate 
                    
                    % set
                    for ind = 1:obj.settings.XCite.numled
                        if (obj.figMain.XCite.leds.LED(ind).pm.Value == 1)
                            if (obj.figMain.XCite.leds.LED(ind).button.Value) 
                                obj.hardware.XCite.setLedOn(ind);
                            else
                                obj.hardware.XCite.setLedOff(ind);
                            end
                        end
                    end
                    
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getLedOn();
                    obj.figMain.XCite.leds.LED(1).button.Value = w;
                    obj.figMain.XCite.leds.LED(2).button.Value = x;
                    obj.figMain.XCite.leds.LED(3).button.Value = y;
                    obj.figMain.XCite.leds.LED(4).button.Value = z; 
                    
                    % update GUI
                    
                case 'LEDIntensitySlider'
                    % validate 
                    for ind = 1:obj.settings.XCite.numled
                        if (obj.figMain.XCite.leds.LED(ind).intensity.Value > 0 && ...
                            obj.figMain.XCite.leds.LED(ind).intensity.Value < 5)
                            obj.figMain.XCite.leds.LED(ind).intensity.Value = 5;
                        end
                    end
                    
                    % set
                    obj.hardware.XCite.setIntensity(...
                    round(10 * obj.figMain.XCite.leds.LED(1).intensity.Value),...
                    round(10 * obj.figMain.XCite.leds.LED(2).intensity.Value),...
                    round(10 * obj.figMain.XCite.leds.LED(3).intensity.Value),...
                    round(10 * obj.figMain.XCite.leds.LED(4).intensity.Value));
                
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getIntensity();
                    obj.figMain.XCite.leds.LED(1).intensity.Value = w/10;
                    obj.figMain.XCite.leds.LED(2).intensity.Value = x/10;
                    obj.figMain.XCite.leds.LED(3).intensity.Value = y/10;
                    obj.figMain.XCite.leds.LED(4).intensity.Value = z/10;
                    
                    % update GUI
                    for ind = 1:obj.settings.XCite.numled
                        obj.figMain.XCite.leds.LED(ind).intensityTxt.String = ...
                            [num2str(obj.figMain.XCite.leds.LED(ind).intensity.Value) '%'];
                    end
            
                case 'LEDPulseModePopupmenu'
                    % validate
                    
                    % set 
                    obj.hardware.XCite.setPulseMode(...
                    obj.figMain.XCite.leds.LED(1).pm.Value - 1,...
                    obj.figMain.XCite.leds.LED(2).pm.Value - 1,...
                    obj.figMain.XCite.leds.LED(3).pm.Value - 1,...
                    obj.figMain.XCite.leds.LED(4).pm.Value - 1);
                    
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getPulseMode();
                    obj.figMain.XCite.leds.LED(1).pm.Value = w + 1;
                    obj.figMain.XCite.leds.LED(2).pm.Value = x + 1;
                    obj.figMain.XCite.leds.LED(3).pm.Value = y + 1;
                    obj.figMain.XCite.leds.LED(4).pm.Value = z + 1;
                    
                    % update GUI
                    for ind = 1:obj.settings.XCite.numled
                        obj.figMain.XCite.pwm.LED(ind).units.Enable = 'off';
                        obj.figMain.XCite.pwm.LED(ind).ontime.Enable = 'off';
                        obj.figMain.XCite.pwm.LED(ind).offtime.Enable = 'off';
                        obj.figMain.XCite.pwm.LED(ind).delay.Enable = 'off';
                        obj.figMain.XCite.pwm.LED(ind).trigger.Enable = 'off';
                        obj.figMain.XCite.pwm.LED(ind).coltitle.Enable = 'off';
                        obj.figMain.XCite.leds.LED(ind).button.Enable = 'off';
                        if (obj.figMain.XCite.leds.LED(ind).pm.Value == 2)
                            obj.figMain.XCite.pwm.LED(ind).units.Enable = 'on';
                            obj.figMain.XCite.pwm.LED(ind).ontime.Enable = 'on';
                            obj.figMain.XCite.pwm.LED(ind).offtime.Enable = 'on';
                            obj.figMain.XCite.pwm.LED(ind).delay.Enable = 'on';
                            obj.figMain.XCite.pwm.LED(ind).trigger.Enable = 'on';
                            obj.figMain.XCite.pwm.LED(ind).coltitle.Enable = 'inactive';
                        elseif (obj.figMain.XCite.leds.LED(ind).pm.Value == 1)
                            obj.figMain.XCite.leds.LED(ind).button.Enable = 'on';
                        end
                    end
                
                case 'PWMStartButton'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setPWM(...
                    obj.figMain.XCite.pwm.buttons.start.Value);
            
                    % check
                    x = obj.hardware.XCite.getPWM();
                    obj.figMain.XCite.pwm.buttons.start.Value = x;
                    
                    % update GUI
                    
                case 'PWMRepeatButton'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setRepeatLoop(...
                    ~obj.figMain.XCite.pwm.buttons.repeat.Value);
            
                    % check
                    x = obj.hardware.XCite.getRepeatLoop();
                    obj.figMain.XCite.pwm.buttons.repeat.Value = ~x;
                    
                    % update GUI
                    
                case 'LEDUnitsPopupmenu'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setPWMunits(...
                    obj.figMain.XCite.pwm.LED(1).units.Value - 1,...
                    obj.figMain.XCite.pwm.LED(2).units.Value - 1,...
                    obj.figMain.XCite.pwm.LED(3).units.Value - 1,...
                    obj.figMain.XCite.pwm.LED(4).units.Value - 1);
            
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getPWMunits();
                    obj.figMain.XCite.pwm.LED(1).units.Value = w + 1;
                    obj.figMain.XCite.pwm.LED(2).units.Value = x + 1;
                    obj.figMain.XCite.pwm.LED(3).units.Value = y + 1;
                    obj.figMain.XCite.pwm.LED(4).units.Value = z + 1;
                    
                    % update GUI
                    
                case 'LEDOntimeEdit'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setISGonTime(...
                    str2num(obj.figMain.XCite.pwm.LED(1).ontime.String),...
                    str2num(obj.figMain.XCite.pwm.LED(2).ontime.String),...
                    str2num(obj.figMain.XCite.pwm.LED(3).ontime.String),...
                    str2num(obj.figMain.XCite.pwm.LED(4).ontime.String));
                
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getISGonTime();
                    obj.figMain.XCite.pwm.LED(1).ontime.String = num2str(w);
                    obj.figMain.XCite.pwm.LED(2).ontime.String = num2str(x);
                    obj.figMain.XCite.pwm.LED(3).ontime.String = num2str(y);
                    obj.figMain.XCite.pwm.LED(4).ontime.String = num2str(z);
                    
                    % update GUI
                    
                case 'LEDOfftimeEdit'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setISGoffTime(...
                    str2num(obj.figMain.XCite.pwm.LED(1).offtime.String),...
                    str2num(obj.figMain.XCite.pwm.LED(2).offtime.String),...
                    str2num(obj.figMain.XCite.pwm.LED(3).offtime.String),...
                    str2num(obj.figMain.XCite.pwm.LED(4).offtime.String));
                
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getISGoffTime();
                    obj.figMain.XCite.pwm.LED(1).offtime.String = num2str(w);
                    obj.figMain.XCite.pwm.LED(2).offtime.String = num2str(x);
                    obj.figMain.XCite.pwm.LED(3).offtime.String = num2str(y);
                    obj.figMain.XCite.pwm.LED(4).offtime.String = num2str(z);
                    
                    % update GUI
                    
                case 'LEDDelayEdit'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setISGdelayTime(...
                    str2num(obj.figMain.XCite.pwm.LED(1).delay.String),...
                    str2num(obj.figMain.XCite.pwm.LED(2).delay.String),...
                    str2num(obj.figMain.XCite.pwm.LED(3).delay.String),...
                    str2num(obj.figMain.XCite.pwm.LED(4).delay.String));
                
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getISGdelayTime();
                    obj.figMain.XCite.pwm.LED(1).delay.String = num2str(w);
                    obj.figMain.XCite.pwm.LED(2).delay.String = num2str(x);
                    obj.figMain.XCite.pwm.LED(3).delay.String = num2str(y);
                    obj.figMain.XCite.pwm.LED(4).delay.String = num2str(z);
                    
                    % update GUI
                    
                case 'LEDTriggerEdit'
                    % validate
                    
                    % set
                    obj.hardware.XCite.setISGtriggerTime(...
                    str2num(obj.figMain.XCite.pwm.LED(1).trigger.String),...
                    str2num(obj.figMain.XCite.pwm.LED(2).trigger.String),...
                    str2num(obj.figMain.XCite.pwm.LED(3).trigger.String),...
                    str2num(obj.figMain.XCite.pwm.LED(4).trigger.String));
                
                    % check
                    [w,x,y,z] = obj.hardware.XCite.getISGtriggerTime();
                    obj.figMain.XCite.pwm.LED(1).trigger.String = num2str(w);
                    obj.figMain.XCite.pwm.LED(2).trigger.String = num2str(x);
                    obj.figMain.XCite.pwm.LED(3).trigger.String = num2str(y);
                    obj.figMain.XCite.pwm.LED(4).trigger.String = num2str(z);
                    
                    % update GUI
            end
        end
        
        function XCiteRefresh(obj,~,~)
            obj.hardware.XCite.connect();
            
            obj.figMain.XCite.status.softwareversion.String = ...
            ['Software version: ' obj.hardware.XCite.getSoftwareVersion()];
            
            obj.figMain.XCite.status.serialnumber.String = ...
            ['Serial number: ' obj.hardware.XCite.getSerialNumber()];
            
            [w,x,y,z] = obj.hardware.XCite.getLedHours();
            obj.figMain.XCite.status.LED(1).ledhours.String = w;
            obj.figMain.XCite.status.LED(2).ledhours.String = x;
            obj.figMain.XCite.status.LED(3).ledhours.String = y;
            obj.figMain.XCite.status.LED(4).ledhours.String = z;
            
            [w,x,y,z] = obj.hardware.XCite.getLEDtemp();
            obj.figMain.XCite.status.LED(1).ledtemp.String = w;
            obj.figMain.XCite.status.LED(2).ledtemp.String = x;
            obj.figMain.XCite.status.LED(3).ledtemp.String = y;
            obj.figMain.XCite.status.LED(4).ledtemp.String = z;
            
            [w,x,y,z] = obj.hardware.XCite.getLEDminTemp();
            obj.figMain.XCite.status.LED(1).ledmintemp.String = w;
            obj.figMain.XCite.status.LED(2).ledmintemp.String = x;
            obj.figMain.XCite.status.LED(3).ledmintemp.String = y;
            obj.figMain.XCite.status.LED(4).ledmintemp.String = z;
            
            [w,x,y,z] = obj.hardware.XCite.getLEDmaxTemp();
            obj.figMain.XCite.status.LED(1).ledmaxtemp.String = w;
            obj.figMain.XCite.status.LED(2).ledmaxtemp.String = x;
            obj.figMain.XCite.status.LED(3).ledmaxtemp.String = y;
            obj.figMain.XCite.status.LED(4).ledmaxtemp.String = z;
            
            [w,x,y,z] = obj.hardware.XCite.getLEDname();
            obj.figMain.XCite.leds.LED(1).button.String = w;
            obj.figMain.XCite.leds.LED(2).button.String = x;
            obj.figMain.XCite.leds.LED(3).button.String = y;
            obj.figMain.XCite.leds.LED(4).button.String = z;
            obj.figMain.XCite.pwm.LED(1).coltitle.String = w;
            obj.figMain.XCite.pwm.LED(2).coltitle.String = x;
            obj.figMain.XCite.pwm.LED(3).coltitle.String = y;
            obj.figMain.XCite.pwm.LED(4).coltitle.String = z;
            obj.figMain.XCite.status.LED(1).ledname.String = w;
            obj.figMain.XCite.status.LED(2).ledname.String = x;
            obj.figMain.XCite.status.LED(3).ledname.String = y;
            obj.figMain.XCite.status.LED(4).ledname.String = z;
            
            [w,x,y,z] = obj.hardware.XCite.getPulseMode();
            obj.figMain.XCite.leds.LED(1).pm.Value = w + 1;
            obj.figMain.XCite.leds.LED(2).pm.Value = x + 1;
            obj.figMain.XCite.leds.LED(3).pm.Value = y + 1;
            obj.figMain.XCite.leds.LED(4).pm.Value = z + 1;

            for ind = 1:obj.settings.XCite.numled
                obj.figMain.XCite.pwm.LED(ind).units.Enable = 'off';
                obj.figMain.XCite.pwm.LED(ind).ontime.Enable = 'off';
                obj.figMain.XCite.pwm.LED(ind).offtime.Enable = 'off';
                obj.figMain.XCite.pwm.LED(ind).delay.Enable = 'off';
                obj.figMain.XCite.pwm.LED(ind).trigger.Enable = 'off';
                obj.figMain.XCite.leds.LED(ind).button.Enable = 'off';
                if (obj.figMain.XCite.leds.LED(ind).pm.Value == 2)
                    obj.figMain.XCite.pwm.LED(ind).units.Enable = 'on';
                    obj.figMain.XCite.pwm.LED(ind).ontime.Enable = 'on';
                    obj.figMain.XCite.pwm.LED(ind).offtime.Enable = 'on';
                    obj.figMain.XCite.pwm.LED(ind).delay.Enable = 'on';
                    obj.figMain.XCite.pwm.LED(ind).trigger.Enable = 'on';
                elseif (obj.figMain.XCite.leds.LED(ind).pm.Value == 1)
                    obj.figMain.XCite.leds.LED(ind).button.Enable = 'on';
                end
            end
            
            [w,x,y,z] = obj.hardware.XCite.getIntensity();
            obj.figMain.XCite.leds.LED(1).intensity.Value = w/10;
            obj.figMain.XCite.leds.LED(2).intensity.Value = x/10;
            obj.figMain.XCite.leds.LED(3).intensity.Value = y/10;
            obj.figMain.XCite.leds.LED(4).intensity.Value = z/10;

            for ind = 1:obj.settings.XCite.numled
                obj.figMain.XCite.leds.LED(ind).intensityTxt.String = ...
                    [num2str(obj.figMain.XCite.leds.LED(ind).intensity.Value) '%'];
            end
            
            [w,x,y,z] = obj.hardware.XCite.getLedOn();
            obj.figMain.XCite.leds.LED(1).button.Value = w;
            obj.figMain.XCite.leds.LED(2).button.Value = x;
            obj.figMain.XCite.leds.LED(3).button.Value = y;
            obj.figMain.XCite.leds.LED(4).button.Value = z; 
            
            x = obj.hardware.XCite.getPWM();
            obj.figMain.XCite.pwm.buttons.start.Value = x;
            
            x = obj.hardware.XCite.getRepeatLoop();
            obj.figMain.XCite.pwm.buttons.repeat.Value = ~x;
            
            [w,x,y,z] = obj.hardware.XCite.getPWMunits();
            obj.figMain.XCite.pwm.LED(1).units.Value = w + 1;
            obj.figMain.XCite.pwm.LED(2).units.Value = x + 1;
            obj.figMain.XCite.pwm.LED(3).units.Value = y + 1;
            obj.figMain.XCite.pwm.LED(4).units.Value = z + 1;
            
            [w,x,y,z] = obj.hardware.XCite.getISGonTime();
            obj.figMain.XCite.pwm.LED(1).ontime.String = num2str(w);
            obj.figMain.XCite.pwm.LED(2).ontime.String = num2str(x);
            obj.figMain.XCite.pwm.LED(3).ontime.String = num2str(y);
            obj.figMain.XCite.pwm.LED(4).ontime.String = num2str(z);        
            
            [w,x,y,z] = obj.hardware.XCite.getISGoffTime();
            obj.figMain.XCite.pwm.LED(1).offtime.String = num2str(w);
            obj.figMain.XCite.pwm.LED(2).offtime.String = num2str(x);
            obj.figMain.XCite.pwm.LED(3).offtime.String = num2str(y);
            obj.figMain.XCite.pwm.LED(4).offtime.String = num2str(z);
            
            [w,x,y,z] = obj.hardware.XCite.getISGdelayTime();
            obj.figMain.XCite.pwm.LED(1).delay.String = num2str(w);
            obj.figMain.XCite.pwm.LED(2).delay.String = num2str(x);
            obj.figMain.XCite.pwm.LED(3).delay.String = num2str(y);
            obj.figMain.XCite.pwm.LED(4).delay.String = num2str(z);
            
            [w,x,y,z] = obj.hardware.XCite.getISGtriggerTime();
            obj.figMain.XCite.pwm.LED(1).trigger.String = num2str(w);
            obj.figMain.XCite.pwm.LED(2).trigger.String = num2str(x);
            obj.figMain.XCite.pwm.LED(3).trigger.String = num2str(y);
            obj.figMain.XCite.pwm.LED(4).trigger.String = num2str(z);
        end
        
        function DMDRefreshImages(obj)
            obj.figMain.DMD.mask.imageCam.CData = im2uint8(obj.images.Cam);
            obj.figMain.DMD.mask.image2P.CData = obj.images.TwoP;
            obj.figMain.DMD.mask.imageSensor.CData = obj.images.Sensor;
            for ind = 1:obj.roiList.numRoi
                if cell2mat(obj.figMain.DMD.roi.masklist.table.Data(ind,3))
                    obj.figMain.DMD.mask.imageCam.CData = ...
                        obj.figMain.DMD.mask.imageCam.CData + ...
                        im2uint8(obj.roiList.maskList(ind).maskCam);
                    obj.figMain.DMD.mask.image2P.CData = ...
                        obj.figMain.DMD.mask.image2P.CData + ...
                        obj.roiList.maskList(ind).mask2P;
                    obj.figMain.DMD.mask.imageSensor.CData = ...
                        obj.figMain.DMD.mask.imageSensor.CData + ...
                        obj.roiList.maskList(ind).maskSensor;
                end
            end
        end
        
        function DMDCallback(obj,src,evt)
            switch src.Tag
                case 'DrawRoiButton'
                    % validate
                    obj.settings.SI.zoomFactor = obj.hardware.hSI.hRoiManager.scanZoomFactor;
                   
                    % set 
                    % check
                    % update GUI
                    switch obj.figMain.DMD.mask.tabgroup.SelectedTab.Title
                        case 'Camera'
                            obj.figMain.DMD.mask.polyCam = impoly(obj.figMain.DMD.mask.axisCam);
                            positionCam = obj.figMain.DMD.mask.polyCam.getPosition();
                            positionCam = [positionCam, ones(size(positionCam,1),1)];
                            position2P = positionCam * obj.affineTransform.Cam2TwoP(obj.settings.SI.zoomFactor);
                            positionSensor = positionCam * obj.affineTransform.Cam2Sensor;
                            obj.figMain.DMD.mask.poly2P = impoly(obj.figMain.DMD.mask.axis2P,position2P);
                            obj.figMain.DMD.mask.polySensor = impoly(obj.figMain.DMD.mask.axisSensor,positionSensor);
                        case '2P'
                            obj.figMain.DMD.mask.poly2P = impoly(obj.figMain.DMD.mask.axis2P);
                            position2P = obj.figMain.DMD.mask.poly2P.getPosition();
                            position2P = [position2P, ones(size(position2P,1),1)];
                            positionCam = position2P * obj.affineTransform.TwoP2Cam(obj.settings.SI.zoomFactor);
                            positionSensor = position2P * obj.affineTransform.TwoP2Sensor(obj.settings.SI.zoomFactor);
                            obj.figMain.DMD.mask.polyCam = impoly(obj.figMain.DMD.mask.axisCam,positionCam);
                            obj.figMain.DMD.mask.polySensor = impoly(obj.figMain.DMD.mask.axisSensor,positionSensor);
                        case 'DMD Sensor'
                            obj.figMain.DMD.mask.polySensor = impoly(obj.figMain.DMD.mask.axisSensor);
                            positionSensor = obj.figMain.DMD.mask.polySensor.getPosition();
                            positionSensor = [positionSensor, ones(size(positionSensor,1),1)];
                            position2P = positionSensor * obj.affineTransform.Sensor2TwoP(obj.settings.SI.zoomFactor);
                            positionCam = positionSensor * obj.affineTransform.Sensor2Cam;
                            obj.figMain.DMD.mask.poly2P = impoly(obj.figMain.DMD.mask.axis2P,position2P);
                            obj.figMain.DMD.mask.polyCam = impoly(obj.figMain.DMD.mask.axisCam,positionCam);
                    end
                    obj.figMain.DMD.mask.maskCam = obj.figMain.DMD.mask.polyCam.createMask();
                    obj.figMain.DMD.mask.mask2P = obj.figMain.DMD.mask.poly2P.createMask();
                    obj.figMain.DMD.mask.maskSensor = obj.figMain.DMD.mask.polySensor.createMask();
                    obj.DMDRefreshImages();
                    
                case 'ClearRoiButton'
                    % validate
                    % set 
                    % check
                    % update GUI
                    delete(obj.figMain.DMD.mask.polyCam);
                    delete(obj.figMain.DMD.mask.poly2P);
                    delete(obj.figMain.DMD.mask.polySensor);
                    obj.figMain.DMD.mask.maskCam = zeros(size(obj.figMain.DMD.mask.imageCam.CData));
                    obj.figMain.DMD.mask.mask2P = zeros(size(obj.figMain.DMD.mask.image2P.CData));
                    obj.figMain.DMD.mask.maskSensor = zeros(size(obj.figMain.DMD.mask.imageSensor.CData));
                    obj.DMDRefreshImages();
                    
                case 'CheckerboardButton'
                    % validate
                    obj.settings.SI.zoomFactor = obj.hardware.hSI.hRoiManager.scanZoomFactor;
                    
                    % set
                    % check
                    % update GUI
                    n = 100;
                    p = size(obj.figMain.DMD.mask.imageSensor.CData,1)/(2*n);
                    q = size(obj.figMain.DMD.mask.imageSensor.CData,2)/(2*n);
                    Cb = checkerboard(n,p,q)>0;
                    obj.roiList.numRoi = obj.roiList.numRoi + 1;
                    obj.figMain.DMD.roi.masklist.table.Data = ...
                    vertcat(obj.figMain.DMD.roi.masklist.table.Data,{'checkerboard' 1 true});  
                    obj.roiList.maskList(obj.roiList.numRoi).maskSensor = Cb;
                    obj.roiList.maskList(obj.roiList.numRoi).mask2P = ...
                        imwarp(Cb,...
                            affine2d(obj.affineTransform.Sensor2TwoP(obj.settings.SI.zoomFactor)),...
                            'OutputView',...
                            imref2d(size(obj.figMain.DMD.mask.image2P.CData)));
                    obj.roiList.maskList(obj.roiList.numRoi).maskCam = ...
                        imwarp(Cb,...
                            affine2d(obj.affineTransform.Sensor2Cam),...
                            'OutputView',...
                            imref2d(size(obj.figMain.DMD.mask.imageCam.CData)));
                    obj.DMDRefreshImages();
                    
                case 'WhitefieldButton'
                    % validate
                    obj.settings.SI.zoomFactor = obj.hardware.hSI.hRoiManager.scanZoomFactor;
                    
                    % set
                    % check
                    % update GUI
                    obj.roiList.numRoi = obj.roiList.numRoi + 1;
                    WF = ones(size(obj.figMain.DMD.mask.imageSensor.CData));
                    obj.figMain.DMD.roi.masklist.table.Data = ...
                    vertcat(obj.figMain.DMD.roi.masklist.table.Data,{'whitefield' 1 true});  
                    obj.roiList.maskList(obj.roiList.numRoi).maskSensor = WF;
                    obj.roiList.maskList(obj.roiList.numRoi).mask2P = ...
                        imwarp(WF,...
                            affine2d(obj.affineTransform.Sensor2TwoP(obj.settings.SI.zoomFactor)),...
                            'OutputView',...
                            imref2d(size(obj.figMain.DMD.mask.image2P.CData)));
                    obj.roiList.maskList(obj.roiList.numRoi).maskCam = ...
                        imwarp(WF,...
                            affine2d(obj.affineTransform.Sensor2Cam),...
                            'OutputView',...
                            imref2d(size(obj.figMain.DMD.mask.imageCam.CData)));
                    obj.DMDRefreshImages();
                    
                case 'TriggerPopupmenu'
                    % validate
                    switch src.Value
                        case 2
                            if obj.figMain.DMD.controls.operation.Value > 2
                                disp('Trigger mode available only in Live/FrameMemory mode');
                                return
                            end
                        case 4
                            if obj.figMain.DMD.controls.operation.Value < 3
                                disp('Trigger mode available only in FrameSequence/ContinuousFrameSequence mode');
                                return
                            end
                    end
                    
                    % set
                    obj.hardware.DMD.setEnumString('TriggerMode',src.String{src.Value})
                    
                    % check
                    % update GUI
                    
                case 'OperationPopupmenu'
                    % validate
                    % set
                    obj.hardware.DMD.setEnumString('OperationMode',src.String{src.Value})
                    
                    % check
                    % update GUI
                    switch src.Value
                        case 1
                            obj.figMain.DMD.roi.framemem.table.Enable = 'off';
                            obj.figMain.DMD.roi.framemem.upload.Enable = 'off';
                            obj.figMain.DMD.roi.framemem.clear.Enable = 'off';
                            obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'off';
                            obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.table.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.expedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'off'; 
                            obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'off'; 
                            obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'off';
                        case 2
                            obj.figMain.DMD.roi.framemem.table.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.upload.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.clear.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                            obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.table.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.expedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'off'; 
                            obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'off'; 
                            obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'off';
                            obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'off';
                        case 3
                            obj.figMain.DMD.roi.framemem.table.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.upload.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.clear.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                            obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.table.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.expedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'inactive';
                        case 4
                            obj.figMain.DMD.roi.framemem.table.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.upload.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.clear.Enable = 'on';
                            obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                            obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.table.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.expedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'inactive';
                            obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'on';
                            obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'inactive';
                    end
                    
                case 'frameIdxSourcePopupmenu'
                    % validate
                    % set
                    obj.hardware.DMD.setEnumString('FrameIndexSource',src.String{src.Value})
                    
                    % check
                    % update GUI
                    
                case 'pixelEncodingPopupmenu'
                    % validate
                    % set
                    obj.hardware.DMD.setEnumString('PixelEncoding',src.String{src.Value})
                    
                    % check
                    % update GUI
                    
                case 'StartPreviewButton'
                    % validate
                    % set 
                    % check
                    % update GUI
                    preview(obj.hardware.Cam,obj.figMain.DMD.mask.imageCam);
                    
                case 'StopPreviewButton'
                    % validate
                    % set 
                    % check
                    % update GUI
                    stoppreview(obj.hardware.Cam);
                    
                case 'CamExposureSlider'
                    % validate
                    % set
                    % check
                    % update GUI
                    vidsrc = getselectedsource(obj.hardware.Cam);
                    vidsrc.Exposure = round(src.Value);
                    
                    
                case 'CamGainSlider'
                    % validate
                    % set
                    % check
                    % update GUI
                    vidsrc = getselectedsource(obj.hardware.Cam);
                    vidsrc.Gain = round(src.Value);
                    
                case 'CamFrameRatePopupmenu'
                    % validate
                    % set
                    % check
                    % update GUI
                    vidsrc = getselectedsource(obj.hardware.Cam);
                    vidsrc.FrameRate = obj.settings.cam.FrameRate.ConstraintValue{src.Value};
                
                case 'AddRoiButton'
                    % validate
                    % set
                    % check
                    % update GUI
                    name = obj.figMain.DMD.roi.masklist.editname.String; 
                    obj.figMain.DMD.roi.masklist.table.Data = ...
                    vertcat(obj.figMain.DMD.roi.masklist.table.Data,{name 1 true});
                    obj.roiList.numRoi = obj.roiList.numRoi + 1;                 
                    obj.roiList.maskList(obj.roiList.numRoi).mask2P = obj.figMain.DMD.mask.mask2P;
                    obj.roiList.maskList(obj.roiList.numRoi).maskCam = obj.figMain.DMD.mask.maskCam;
                    obj.roiList.maskList(obj.roiList.numRoi).maskSensor = obj.figMain.DMD.mask.maskSensor;
                    delete(obj.figMain.DMD.mask.poly2P);
                    delete(obj.figMain.DMD.mask.polyCam);
                    delete(obj.figMain.DMD.mask.polySensor);
                    obj.DMDRefreshImages();
                    
                case 'RemoveRoiButton'
                    % validate
                    % set
                    % check
                    % update GUI
                    if ~isempty(obj.roiList.selectedRow)
                        obj.figMain.DMD.roi.masklist.table.Data(obj.roiList.selectedRow,:) = [];
                        obj.roiList.maskList(obj.roiList.selectedRow) = [];
                        obj.roiList.numRoi = obj.roiList.numRoi - 1;
                        obj.DMDRefreshImages();
                    else
                        disp('Please select ROI')
                    end
                    
                case 'FlattenButton'
                    % validate
                    % set
                    % check
                    % update GUI
                    new_maskCam = zeros(size(obj.figMain.DMD.mask.imageCam.CData));
                    new_mask2P = zeros(size(obj.figMain.DMD.mask.image2P.CData));
                    new_maskSensor = zeros(size(obj.figMain.DMD.mask.imageSensor.CData));
                    for ind = 1:obj.roiList.numRoi
                        new_maskCam = new_maskCam + obj.roiList.maskList(ind).maskCam;
                        new_mask2P = new_mask2P + obj.roiList.maskList(ind).mask2P;
                        new_maskSensor = new_maskSensor + obj.roiList.maskList(ind).maskSensor;
                    end
                    obj.roiList.maskList = [];
                    obj.roiList.numRoi = 1;
                    obj.roiList.maskList(1).maskCam = (new_maskCam>0);
                    obj.roiList.maskList(1).mask2P = (new_mask2P>0);
                    obj.roiList.maskList(1).maskSensor = (new_maskSensor>0);
                    obj.figMain.DMD.roi.masklist.table.Data = {'flattened_mask' 1 true};
                
                case 'QueueButton'
                    % validate
                    if isempty(obj.roiList.selectedRow)
                        disp('Please select ROI')
                        return;
                    end
                    
                    exptime = cell2mat(obj.figMain.DMD.roi.masklist.table.Data(obj.roiList.selectedRow,2));
                    if (exptime <= 0) || (exptime >= 200)
                        disp('Exposure time must be strictly positive and less than 200 s');
                        return;
                    end
                        
                    % set
                    buffer = uint8(obj.roiList.maskList(obj.roiList.selectedRow).maskSensor'); 
                    obj.hardware.DMD.queueBuffer(buffer(:));
                    obj.hardware.DMD.setFloat('ExposureTime',exptime);
                    
                    % check
                    
                    % update GUI
                    
                case 'UploadFrameButton'
                    % validate
                    count = obj.hardware.DMD.getInt('FrameMemoryCount');
                    
                    if isempty(obj.roiList.selectedRow)
                        disp('Please select ROI')
                        obj.figMain.DMD.roi.framemem.framecounttext.String = num2str(count);
                        return;
                    end
                    
                    if (count == 139)
                        disp('Frame Memory full, please clear memory before adding a new frame');
                        return;
                    end
                    
                    framebuffer = uint8(obj.roiList.maskList(obj.roiList.selectedRow).maskSensor'); 
                    
                    % set 
                    obj.hardware.DMD.queueBuffer(framebuffer(:));
                    obj.hardware.DMD.command('UploadFrame');
                    obj.figMain.DMD.roi.framemem.table.Data = vertcat(...
                        obj.figMain.DMD.roi.framemem.table.Data, ... 
                        {count ...
                        cell2mat(obj.figMain.DMD.roi.masklist.table.Data(obj.roiList.selectedRow,1)) ...
                        cell2mat(obj.figMain.DMD.roi.masklist.table.Data(obj.roiList.selectedRow,2))});    
                    
                    % check
                    count = obj.hardware.DMD.getInt('FrameMemoryCount');
                    
                    % update GUI
                    obj.figMain.DMD.roi.framemem.framecounttext.String = num2str(count);
                    
                case 'ClearFrameButton'
                    % validate
                    % set
                    obj.hardware.DMD.command('ClearSequenceMemory');
                    obj.hardware.DMD.command('ClearFrameMemory');
                    
                    % check
                    count = obj.hardware.DMD.getInt('FrameMemoryCount');
                    countseq = obj.hardware.DMD.getInt('SequenceEventCount');
                    
                    % update GUI
                    obj.figMain.DMD.roi.framemem.table.Data = [];
                    obj.figMain.DMD.roi.framemem.framecounttext.String = num2str(count);
                    obj.figMain.DMD.roi.seqmem.seqcountedit.String = num2str(countseq);
                    
                case 'UploadSequenceButton'
                    % validate
                    count = obj.hardware.DMD.getInt('SequenceEventCount');
                    if (count == 65536)
                        disp('Sequence Memory full, please clear memory before adding a new sequence');
                    end
                    
                    frameind = str2num(obj.figMain.DMD.roi.seqmem.frameindextext.String);
                    if (frameind < 0) || (frameind > 138)
                        disp('Frame Index should be between 0 and 138');
                        return;
                    end
                    
                    framecount = str2num(obj.figMain.DMD.roi.seqmem.framecountedit.String);
                    if (framecount <1) || (framecount > 139)
                        disp('Frame Count should be between 1 and 139');
                        return;
                    end
                    
                    framecycle = str2num(obj.figMain.DMD.roi.seqmem.loopedit.String);
                    if (framecycle <1) || (framecycle > 65536)
                        disp('Frame Cycle should be between 1 and 65536');
                        return;
                    end
                    
                    seqexptime = str2num(obj.figMain.DMD.roi.seqmem.expedit.String);
                    if (seqexptime < 0.000087) || (seqexptime > 200)
                        disp('Exposure Time should be between 87 us and 200 s');
                        return;
                    end
                    
                    seqgaptime = str2num(obj.figMain.DMD.roi.seqmem.gapedit.String);
                    if (seqgaptime < 0.000084) || (seqgaptime > 200)
                        disp('Gap Time should be between 84 us and 200 s');
                        return;
                    end
        
                    % set
                    obj.hardware.DMD.setInt('FrameIndex',frameind);
                    obj.hardware.DMD.setInt('FrameCount',framecount);
                    obj.hardware.DMD.setInt('FrameCycleCount',framecycle);
                    obj.hardware.DMD.setFloat('SequenceExposureTime',seqexptime);
                    obj.hardware.DMD.setFloat('SequenceGapTime',seqgaptime);
                    obj.hardware.DMD.command('UploadSequenceEvent');
                    
                    % check
                    count = obj.hardware.DMD.getInt('SequenceEventCount');
                     
                    % update GUI
                    obj.figMain.DMD.roi.seqmem.seqcountedit.String = num2str(count);
                    obj.figMain.DMD.roi.seqmem.table.Data = vertcat(...
                        obj.figMain.DMD.roi.seqmem.table.Data,...
                        {frameind framecount framecycle seqexptime seqgaptime});
                    
                case 'ClearSequenceButton'
                    % validate
                    % set
                    obj.hardware.DMD.command('ClearSequenceMemory');
                    
                    % check
                    % update GUI
                    obj.figMain.DMD.roi.seqmem.table.Data = [];
                    % check
                    count = obj.hardware.DMD.getInt('SequenceEventCount');
                     
                    % update GUI
                    obj.figMain.DMD.roi.seqmem.seqcountedit.String = num2str(count);
                    
                case 'FrameMemoryTable'
                    % validate
                    ind_selected = evt.Indices;
                    if isempty(ind_selected)
                        obj.frameList.selectedRow = [];
                        return;
                    end
                    
                    row = ind_selected(1);
                    obj.frameList.selectedRow = row;
                        
                    exptime = cell2mat(obj.figMain.DMD.roi.framemem.table.Data(row,3));
                    if (exptime < 0.000087) || (exptime > 200)
                        disp('Exposure Time should be between 87 us and 200 s');
                        return;
                    end
                    
                    frameind = cell2mat(obj.figMain.DMD.roi.framemem.table.Data(row,1));
                    if (frameind <0) || (frameind > 138)
                        disp('Frame Index should be between 0 and 138');
                        return;
                    end
                    
                    % set
                    obj.hardware.DMD.setFloat('ExposureTime',exptime);
                    obj.hardware.DMD.setInt('FrameIndex',frameind);
                    
                    % check
                    % update GUI
                    obj.figMain.DMD.roi.seqmem.frameindextext.String = num2str(frameind);
                    
                    
                case 'RoiListTable'
                    % validate
                    ind_selected = evt.Indices;
                    if isempty(ind_selected)
                        obj.roiList.selectedRow = [];
                        obj.roiList.selectedCol = [];
                        return;
                    end 
                    
                    row = ind_selected(1);
                    col = ind_selected(2);
                    obj.roiList.selectedRow = row;
                    obj.roiList.selectedCol = col;
                    
                    % set
                    % check
                    % update GUI
                    obj.DMDRefreshImages();
                    
                case 'ExposeButton'
                    % validate
                    switch obj.figMain.DMD.controls.operation.Value
                        case {3,4}
                            startind = str2num(obj.figMain.DMD.roi.seqmem.seqstartindedit.String);
                            if (startind < 0) || (startind > 1023)
                                disp('Sequence Start Index should be between 0 and 1023');
                                return;
                            end
                            
                            seqlen = str2num(obj.figMain.DMD.roi.seqmem.seqlengthedit.String);
                            if (seqlen < 1) || (seqlen > 1024)
                                disp('Sequence Length should be between 1 and 1024');
                                return;
                            end
                            
                            seqloop = str2num(obj.figMain.DMD.roi.seqmem.seqloopedit.String);
                            if (seqlen < 1) || (seqlen > 65536)
                                disp('Sequence Loop Count should be between 1 and 65536');
                                return;
                            end
                    end
                    
                    % set
                    switch obj.figMain.DMD.controls.operation.Value
                        case {3,4}
                            obj.hardware.DMD.setInt('SequenceStartIndex',startind);
                            obj.hardware.DMD.setInt('SequenceLoopCount',seqloop);
                            obj.hardware.DMD.setInt('SequenceLoopLength',seqlen);
                    end
                    obj.hardware.DMD.command('Abort');
                    obj.hardware.DMD.command('Expose'); 
                    
                    % check
                    % update GUI
                    
                case 'AbortButton'
                    % validate
                    % set
                    obj.hardware.DMD.command('Abort');
                    
                    % check
                    % update GUI
                    
            end
        end
        
        function DMDRefresh(obj)
                % status
                obj.figMain.DMD.status.controllerfirmwaretext.String = ...
                    obj.hardware.DMD.getString('ControllerFirmwareVersion');
                obj.figMain.DMD.status.devicecounttext.String = ...
                    num2str(obj.hardware.DMD.System_getInt('DeviceCount'));
                obj.figMain.DMD.status.devicetypetext.String = ...
                    obj.hardware.DMD.getString('DeviceType');
                obj.figMain.DMD.status.firmwaretext.String = ...
                    obj.hardware.DMD.getString('FirmwareVersion');
                obj.figMain.DMD.status.serialnumbertext.String = ...
                    obj.hardware.DMD.getString('SerialNumber');
                obj.figMain.DMD.status.softwaretext.String = ...
                    obj.hardware.DMD.System_getString('SoftwareVersion');
                
                % operation mode
                opmode = obj.hardware.DMD.getEnumIndex('OperationMode');
                opmode = opmode + 1;
                obj.figMain.DMD.controls.operation.Value = opmode;
                switch opmode
                    case 1
                        obj.figMain.DMD.roi.framemem.table.Enable = 'off';
                        obj.figMain.DMD.roi.framemem.upload.Enable = 'off';
                        obj.figMain.DMD.roi.framemem.clear.Enable = 'off';
                        obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'off';
                        obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.table.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.expedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'off'; 
                        obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'off'; 
                        obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'off';
                    case 2
                        obj.figMain.DMD.roi.framemem.table.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.upload.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.clear.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                        obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.table.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.expedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'off'; 
                        obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'off'; 
                        obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'off';
                        obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'off';
                    case 3
                        obj.figMain.DMD.roi.framemem.table.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.upload.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.clear.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                        obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.table.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.expedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'inactive';
                    case 4
                        obj.figMain.DMD.roi.framemem.table.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.upload.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.clear.Enable = 'on';
                        obj.figMain.DMD.roi.framemem.framecounttext.Enable = 'inactive';
                        obj.figMain.DMD.roi.framemem.framecounttextlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.table.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.frameindextext.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.frameindextextlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.framecountedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.framecounteditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.loopedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.loopeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.expedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.expeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.gapedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.gapeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.uploadseq.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.clearseq.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqcountedit.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqcounteditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqstartindedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqstartindeditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqlengthedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqlengtheditlegend.Enable = 'inactive';
                        obj.figMain.DMD.roi.seqmem.seqloopedit.Enable = 'on';
                        obj.figMain.DMD.roi.seqmem.seqloopeditlegend.Enable = 'inactive';
                end
                
                % trigger mode
                trigmode = obj.hardware.DMD.getEnumIndex('TriggerMode');
                trigmode = trigmode + 1;
                obj.figMain.DMD.controls.trigger.Value = trigmode;
                
                % frame index source
                framesrc = obj.hardware.DMD.getEnumIndex('FrameIndexSource');
                framesrc = framesrc + 1;
                obj.figMain.DMD.controls.frameIdxSource.Value = framesrc;
                
                % pixel encoding
                pixencode = obj.hardware.DMD.getEnumIndex('PixelEncoding');
                pixencode = pixencode + 1;
                obj.figMain.DMD.controls.pixelEncoding.Value = pixencode;
                
                % frame memory count
                count = obj.hardware.DMD.getInt('FrameMemoryCount');
                obj.figMain.DMD.roi.framemem.framecounttext.String = num2str(count);
                
                % sequence memory count
                countseq = obj.hardware.DMD.getInt('SequenceEventCount');
                obj.figMain.DMD.roi.seqmem.seqcountedit.String = num2str(countseq);
        end
        
        function CalibrationCallback(obj,src,~)
             switch src.Tag
                case 'Register2PCamButton'
                    zoomlist = [1.0 1.5 2.0 2.5 3.0 3.5];
                    preview(obj.hardware.Cam,obj.figMain.DMD.mask.imageCam);    
                    
                    % acquire average image from camera 
                    disp('Acquiring camera image')
                    imgaccumCam = zeros(size(obj.images.Cam));
                    tic;
                    while toc < 10
                        imgaccumCam = imgaccumCam + obj.images.Cam;
                        pause(0.5);
                    end
                    imgaccumCam = imadjust(imgaccumCam);
            
                    for i = 1:length(zoomlist)
                        disp('Acquiring 2P image')
                        % set scanimage zoom factor
                        obj.hardware.hSI.hRoiManager.scanZoomFactor = zoomlist(i);
                        
                        % acquire and average 2P frames
                        imgaccum2P = zeros(size(obj.images.TwoP));
                        tic;
                        while toc < 10
                            imgaccum2P = imgaccum2P + obj.images.TwoP;
                            pause(0.5);
                        end
                        imgaccum2P = imadjust(imgaccum2P);
                        
                        [movingPoints fixedPoints] = cpselect(imgaccum2P,imgaccumCam,'Wait',true);
                        movingPoints = [movingPoints ones(size(movingPoints,1),1)];
                        fixedPoints = [fixedPoints ones(size(fixedPoints,1),1)];
                        T = fixedPoints\movingPoints;
                        T(:,3) = [0;0;1];
                        Tforward(:,:,i) = T;
                    end
                    
                    % fit model for each matrix coefficient
                    lm11 = fitlm(zoomlist,squeeze(Tforward(1,1,:)));
                    lm12 = fitlm(zoomlist,squeeze(Tforward(1,2,:)));
                    lm21 = fitlm(zoomlist,squeeze(Tforward(2,1,:)));
                    lm22 = fitlm(zoomlist,squeeze(Tforward(2,2,:)));
                    lm31 = fitlm(zoomlist,squeeze(Tforward(3,1,:)));
                    lm32 = fitlm(zoomlist,squeeze(Tforward(3,2,:)));

                    cam2twop_slope = [lm11.Coefficients.Estimate(2) lm12.Coefficients.Estimate(2) 0;
                                  lm21.Coefficients.Estimate(2) lm22.Coefficients.Estimate(2) 0;
                                  lm31.Coefficients.Estimate(2) lm32.Coefficients.Estimate(2) 0];

                    cam2twop_icpt = [lm11.Coefficients.Estimate(1) lm12.Coefficients.Estimate(1) 0;
                                  lm21.Coefficients.Estimate(1) lm22.Coefficients.Estimate(1) 0;
                                  lm31.Coefficients.Estimate(1) lm32.Coefficients.Estimate(1) 1];
                    
                    obj.affineTransform.Cam2TwoP = @(z) z.*cam2twop_slope + cam2twop_icpt;
                    obj.affineTransform.TwoP2Cam = @(z) inv(obj.affineTransform.Cam2TwoP(z));
                    disp('Done')
                    
                case 'RegisterSensor2PButton'
                    % compute transform as the composition of the other two
                    TwoP2Sensor = @(z) obj.affineTransform.TwoP2Cam(z) * obj.affineTransform.Cam2Sensor;
                    Sensor2TwoP = @(z) obj.affineTransform.Sensor2Cam * obj.affineTransform.Cam2TwoP(z);
                    obj.affineTransform.TwoP2Sensor = TwoP2Sensor;                       
                    obj.affineTransform.Sensor2TwoP = Sensor2TwoP;
                    
                case 'RegisterCamSensorButton'
                   
                    preview(obj.hardware.Cam,obj.figMain.DMD.mask.imageCam);
                    
                    obj.hardware.DMD.setEnumString('OperationMode','Live');
                    
                    numpoints = 10;
                    width = obj.settings.DMD.SensorWidth;
                    height = obj.settings.DMD.SensorHeight;
                    radius = max(5,min(width,height)/(16*(numpoints+1)));
                    [y,x] = meshgrid(height/(numpoints+1)*(1:numpoints),...
                                    width/(numpoints+1)*(1:numpoints));
                    pointscal = [x(:) y(:)];
                    [Y,X] = meshgrid(1:height,1:width);
                    points = [X(:) Y(:)];
                    [camX,camY] = meshgrid(1:obj.settings.cam.VideoResolution.DefaultValue(1),...
                        1:obj.settings.cam.VideoResolution.DefaultValue(2));
                    pointscam = zeros(size(pointscal));
                    
                    hf = figure;
                    hi = imagesc(zeros(size(obj.images.Cam)));
                    ha = hi.Parent;
                    axis image;
                    hold on
                    hp = plot(NaN,NaN,'r+');
                    
                    % expose whitefield to determine threshold value
                    imgaccum = zeros(size(obj.images.Cam));
                    maskcal = uint8(sum((points-[width/2 height/2]).^2,2) < radius^2);
                    obj.hardware.DMD.queueBuffer(maskcal);
                    obj.hardware.DMD.setFloat('ExposureTime',0.33);
                    obj.hardware.DMD.command('Abort');
                    obj.hardware.DMD.command('Expose'); 
                    exposing = obj.hardware.DMD.getBool('IsExposing');
                    while exposing
                        imgaccum = imgaccum + obj.images.Cam;
                        exposing = obj.hardware.DMD.getBool('IsExposing');
                        pause(0.05);
                    end
                    hi.CData = imgaccum;
                    threshold = max(imgaccum(:))/2;
                    
                        
                    for p=1:size(pointscal,1)
                        imgaccum = zeros(size(obj.images.Cam));
                        maskcal = uint8(sum((points-pointscal(p,:)).^2,2) < radius^2);
                        obj.hardware.DMD.queueBuffer(maskcal);
                        obj.hardware.DMD.setFloat('ExposureTime',0.33);
                        obj.hardware.DMD.command('Abort');
                    	obj.hardware.DMD.command('Expose'); 
                        exposing = obj.hardware.DMD.getBool('IsExposing');
                        while exposing
                            imgaccum = imgaccum + obj.images.Cam;
                            exposing = obj.hardware.DMD.getBool('IsExposing');
                            pause(0.05);
                        end
                        bw = (imgaccum > threshold);
                        if ~isempty(bw)
                            [ys,xs] = find(bw);
                            pointscam(p,:) = [nanmean(xs) nanmean(ys)];
                        else
                            pointscam(p,:) = [NaN NaN];                  
                        end
                        
                        hi.CData = imgaccum;
                        ha.CLim = [0 threshold];
                        hp.XData = pointscam(p,1);
                        hp.YData = pointscam(p,2);
                        pause(0.33);
                    end
                    close(hf);
                    
                    tokeep = ~isnan(pointscam(:,1));
                    pointscal = [pointscal ones(size(pointscal,1),1)];
                    pointscam = [pointscam ones(size(pointscam,1),1)];
                    Cam2Sensor = pointscam(tokeep,:)\pointscal(tokeep,:);
                    Sensor2Cam = pointscal(tokeep,:)\pointscam(tokeep,:);
                    Cam2Sensor(:,3) = [0; 0; 1]
                    Sensor2Cam(:,3) = [0; 0; 1]
                    obj.affineTransform.Cam2Sensor = Cam2Sensor;
                    obj.affineTransform.Sensor2Cam = Sensor2Cam;
             end
        end
        
        function SIframeAcqListener(obj,~,~)
            obj.figMain.DMD.mask.image2P.CData = obj.images.TwoP;
            for ind = 1:obj.roiList.numRoi
                if cell2mat(obj.figMain.DMD.roi.masklist.table.Data(ind,3))
                    obj.figMain.DMD.mask.image2P.CData = ...
                        obj.figMain.DMD.mask.image2P.CData + ...
                        obj.roiList.maskList(ind).mask2P;
                end
            end
            obj.figMain.Calibration.cam.axis.image2P.CData = ...
                obj.figMain.DMD.mask.image2P.CData;
        end
        
        function CamFramePreviewedFcn(obj,videoinputobj,evt,himage)
            obj.images.Cam = im2double(evt.Data);
            obj.figMain.DMD.mask.imageCam.CData = evt.Data;
            for ind = 1:obj.roiList.numRoi
                if cell2mat(obj.figMain.DMD.roi.masklist.table.Data(ind,3))
                    obj.figMain.DMD.mask.imageCam.CData = ...
                        obj.figMain.DMD.mask.imageCam.CData + ...
                        im2uint8(obj.roiList.maskList(ind).maskCam);
                end
            end
            obj.figMain.Calibration.cam.axis.imageCam.CData = ...
                obj.figMain.DMD.mask.imageCam.CData;
        end
    end
    
    events
        SIframeAcq;
    end
end


