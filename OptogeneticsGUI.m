classdef OptogeneticsGUI < handle
    
    properties
        figMain
        figROI
        hardware
    end
    
    methods
        function obj = OptogeneticsGUI(XCiteComPort, DMDindex)
        % declare all elements and initialize hardware
        
            % create the main figure
            obj.figMain.handle = figure;
            obj.figMain.handle.Name = 'OptogeneticsGUI';
            obj.figMain.handle.NumberTitle = 'off';
            obj.figMain.handle.MenuBar = 'none';
            obj.figMain.handle.ToolBar = 'none';
            obj.figMain.handle.CloseRequestFcn = @obj.onCloseMain;
            
            % create main figure tabs
            obj.figMain.tabgroup = uitabgroup(obj.figMain.handle);
            obj.figMain.XCite.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.XCite.tab.Title = 'XCite';
            obj.figMain.DMD.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.DMD.tab.Title = 'DMD';
            obj.figMain.TwoP.tab = uitab(obj.figMain.tabgroup);
            obj.figMain.TwoP.tab.Title = '2P';
            
            % Tab XCite
            obj.figMain.XCite.numled = 4;
            
            obj.figMain.XCite.triggers.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.triggers.panel.Title = 'Triggers';
            
            obj.figMain.XCite.status.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.status.panel.Title = 'Status';
            
            obj.figMain.XCite.leds.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.leds.panel.Title = 'LEDs';
            for ind=1:obj.figMain.XCite.numled
                obj.figMain.XCite.leds.LED(ind).panel = uipanel(obj.figMain.XCite.leds.panel);
                obj.figMain.XCite.leds.LED(ind).button = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).button.Style = 'togglebutton';
                obj.figMain.XCite.leds.LED(ind).button.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).button.String =  ['LED' num2str(ind)];
                obj.figMain.XCite.leds.LED(ind).button.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.leds.LED(ind).intensity = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).intensity.Style = 'slider';
                obj.figMain.XCite.leds.LED(ind).intensity.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).intensity.Min = 0;
                obj.figMain.XCite.leds.LED(ind).intensity.Max = 100;
                obj.figMain.XCite.leds.LED(ind).intensity.SliderStep = [1/100 1/10];
                obj.figMain.XCite.leds.LED(ind).intensity.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.leds.LED(ind).pm = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).pm.Style = 'popupmenu';
                obj.figMain.XCite.leds.LED(ind).pm.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).pm.String = {'None','Int','Ext','Global'};
                obj.figMain.XCite.leds.LED(ind).pm.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.leds.LED(ind).intensityTxt = uicontrol(obj.figMain.XCite.leds.LED(ind).panel);
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Style = 'edit';
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Units = 'normalized';
                obj.figMain.XCite.leds.LED(ind).intensityTxt.String = '0 %';
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Enable = 'inactive';
            end

            obj.figMain.XCite.pwm.panel = uipanel(obj.figMain.XCite.tab);
            obj.figMain.XCite.pwm.panel.Title = 'PWM';
            obj.figMain.XCite.pwm.buttons.panel = uipanel(obj.figMain.XCite.pwm.panel);
            obj.figMain.XCite.pwm.buttons.start = uicontrol(obj.figMain.XCite.pwm.buttons.panel);
            obj.figMain.XCite.pwm.buttons.start.Style = 'togglebutton';
            obj.figMain.XCite.pwm.buttons.start.Units = 'normalized';
            obj.figMain.XCite.pwm.buttons.start.String = 'Start';
            obj.figMain.XCite.pwm.buttons.start.Callback = @obj.XCiteCallback;
            obj.figMain.XCite.pwm.buttons.repeat = uicontrol(obj.figMain.XCite.pwm.buttons.panel);
            obj.figMain.XCite.pwm.buttons.repeat.Style = 'togglebutton';
            obj.figMain.XCite.pwm.buttons.repeat.Units = 'normalized';
            obj.figMain.XCite.pwm.buttons.repeat.String = 'Repeat';
            obj.figMain.XCite.pwm.buttons.repeat.Callback = @obj.XCiteCallback;
            obj.figMain.XCite.pwm.legend.panel = uipanel(obj.figMain.XCite.pwm.panel);
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
            for ind=1:obj.figMain.XCite.numled
                obj.figMain.XCite.pwm.LED(ind).panel = uipanel(obj.figMain.XCite.pwm.edit.panel);
                obj.figMain.XCite.pwm.LED(ind).units = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).units.Style = 'popupmenu';
                obj.figMain.XCite.pwm.LED(ind).units.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).units.String = {'us','ms','s'};
                obj.figMain.XCite.pwm.LED(ind).units.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).coltitle = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).coltitle.Style = 'text';
                obj.figMain.XCite.pwm.LED(ind).coltitle.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).coltitle.String = ['LED' num2str(ind)];
                obj.figMain.XCite.pwm.LED(ind).coltitle.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).ontime = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).ontime.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).ontime.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).ontime.String = '0';
                obj.figMain.XCite.pwm.LED(ind).ontime.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).offtime = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).offtime.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).offtime.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).offtime.String = '0';
                obj.figMain.XCite.pwm.LED(ind).offtime.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).delay = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).delay.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).delay.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).delay.String = '0';
                obj.figMain.XCite.pwm.LED(ind).delay.Callback = @obj.XCiteCallback;
                obj.figMain.XCite.pwm.LED(ind).trigger = uicontrol(obj.figMain.XCite.pwm.LED(ind).panel);
                obj.figMain.XCite.pwm.LED(ind).trigger.Style = 'edit';
                obj.figMain.XCite.pwm.LED(ind).trigger.Units = 'normalized';
                obj.figMain.XCite.pwm.LED(ind).trigger.String = '0';
                obj.figMain.XCite.pwm.LED(ind).trigger.Callback = @obj.XCiteCallback;
            end

            % Tab DMD
            obj.figMain.DMD.status.panel =  uipanel(obj.figMain.DMD.tab);
            obj.figMain.DMD.status.panel.Title = 'Status';
            
            % Tab 2P
            
            % create the ROI manager figure
            obj.figROI.handle = figure;
            obj.figROI.handle.Name = 'ROI Manager';
            obj.figROI.handle.NumberTitle = 'off';
            obj.figROI.handle.MenuBar = 'none';
            obj.figROI.handle.ToolBar = 'none';
            obj.figROI.handle.Resize = 'off';
            obj.figROI.handle.CloseRequestFcn = @obj.onCloseROI;
            
            % initialize hardware interface 
            try 
                obj.hardware.XCite = XciteXLED1(XCiteComPort);
            catch ME
                warning(ME.message)
            end
            
            try
                obj.hardware.DMD = Mosaic3(DMDindex);
            catch ME
                warning(ME.message);
            end
            
            try
                obj.hardware.Cam =  videoinput('winvideo', 1, 'Y800_744x480');
            catch ME
                warning(ME.message);
            end
            
            %obj.XCiteRefresh();
            %obj.DMDRefresh();
            obj.layout();
        end
        
        %% layout related functions
        function layout(obj)
            left = 20;
            bottom = 50;
            width = 800;
            height = 600;
           
            obj.figMain.handle.Position = [left bottom width height];
            obj.figROI.handle.Position = [left+width+20 bottom width/3 height];
            
            % XCite tab
            obj.figMain.XCite.leds.panel.Position = [0 0 .5 .5];
            for ind=1:obj.figMain.XCite.numled
                obj.figMain.XCite.leds.LED(ind).panel.Position = [0 (1-ind/obj.figMain.XCite.numled) 1 0.25];
                obj.figMain.XCite.leds.LED(ind).pm.Position = [0 0.75 0.33 0.25];
                obj.figMain.XCite.leds.LED(ind).button.Position = [0 0 0.33 0.75];
                obj.figMain.XCite.leds.LED(ind).intensityTxt.Position = [0.33 0.75 0.66 0.25];
                obj.figMain.XCite.leds.LED(ind).intensity.Position = [0.33 0 0.66 0.75];
            end
            
            obj.figMain.XCite.pwm.panel.Position = [.5 0 .5 .5];
            obj.figMain.XCite.pwm.buttons.panel.Position = [0.2 .8 .8 .2];
            obj.figMain.XCite.pwm.buttons.start.Position = [0 0 .5 1];
            obj.figMain.XCite.pwm.buttons.repeat.Position = [.5 0 .5 1];
            obj.figMain.XCite.pwm.legend.panel.Position = [0 0 .2 .8];
            obj.figMain.XCite.pwm.legend.ontimetxt.Position = [0 0.6 1 0.2];
            obj.figMain.XCite.pwm.legend.offtimetxt.Position = [0 0.4 1 0.2];
            obj.figMain.XCite.pwm.legend.delaytxt.Position = [0 0.2 1 0.2];
            obj.figMain.XCite.pwm.legend.triggertxt.Position = [0 0 1 0.2];
            obj.figMain.XCite.pwm.edit.panel.Position = [.2 0 .8 .8];
            for ind=1:obj.figMain.XCite.numled
                obj.figMain.XCite.pwm.LED(ind).panel.Position = [(ind-1)/obj.figMain.XCite.numled 0 0.25 1];
                obj.figMain.XCite.pwm.LED(ind).coltitle.Position = [0 0.9 1 0.1];
                obj.figMain.XCite.pwm.LED(ind).units.Position = [0 0.8 1 0.1];
                obj.figMain.XCite.pwm.LED(ind).ontime.Position = [0 0.6 1 0.2];
                obj.figMain.XCite.pwm.LED(ind).offtime.Position = [0 0.4 1 0.2];
                obj.figMain.XCite.pwm.LED(ind).delay.Position = [0 0.2 1 0.2];
                obj.figMain.XCite.pwm.LED(ind).trigger.Position = [0 0 1 0.2];
            end
            
            obj.figMain.XCite.triggers.panel.Position = [.5 .5 .5 .5];
            obj.figMain.XCite.status.panel.Position = [0 .5 .5 .5];
        end
        
        
        %% Windows Callback functions
        function onCloseMain(obj,~,~)
           selection = questdlg('Close OptogeneticsGUI?',...
                              'Confirmation',...
                              'Yes','No','Yes'); 
           switch selection 
              case 'Yes'
                  delete(obj.figROI.handle);
                  delete(obj.figMain.handle);
                  obj.delete();
              case 'No'
              return 
           end
        end
        
        function onCloseROI(obj,~,~)
            % do nothing
        end
        
        %% Components Callback functions 
        function XCiteCallback(obj,~,~)

            for ind = 1:obj.figMain.XCite.numled
                if (obj.figMain.XCite.leds.LED(ind).button.Value)
                    obj.hardware.XCite.setLedOn(ind);
                end
            end

            obj.hardware.XCite.setIntensity(...
                (255/100) * obj.figMain.XCite.leds.LED(1).intensity.Value,...
                (255/100) * obj.figMain.XCite.leds.LED(2).intensity.Value,...
                (255/100) * obj.figMain.XCite.leds.LED(3).intensity.Value,...
                (255/100) * obj.figMain.XCite.leds.LED(4).intensity.Value);
                
            obj.hardware.XCite.setPulseMode(...
                obj.figMain.XCite.leds.LED(1).pm.Value - 1,...
                obj.figMain.XCite.leds.LED(2).pm.Value - 1,...
                obj.figMain.XCite.leds.LED(3).pm.Value - 1,...
                obj.figMain.XCite.leds.LED(4).pm.Value - 1);
                
            obj.hardware.XCite.setISGdelayTime(...
                obj.figMain.XCite.pwm.LED(1).delay.Value,...
                obj.figMain.XCite.pwm.LED(2).delay.Value,...
                obj.figMain.XCite.pwm.LED(3).delay.Value,...
                obj.figMain.XCite.pwm.LED(4).delay.Value);
            
            obj.hardware.XCite.setISGonTime(...
                obj.figMain.XCite.pwm.LED(1).ontime.Value,...
                obj.figMain.XCite.pwm.LED(2).ontime.Value,...
                obj.figMain.XCite.pwm.LED(3).ontime.Value,...
                obj.figMain.XCite.pwm.LED(4).ontime.Value);
                
            obj.hardware.XCite.setISGoffTime(...
                obj.figMain.XCite.pwm.LED(1).offtime.Value,...
                obj.figMain.XCite.pwm.LED(2).offtime.Value,...
                obj.figMain.XCite.pwm.LED(3).offtime.Value,...
                obj.figMain.XCite.pwm.LED(4).offtime.Value);
                
            obj.hardware.XCite.setISGtriggerTime(...
                obj.figMain.XCite.pwm.LED(1).trigger.Value,...
                obj.figMain.XCite.pwm.LED(2).trigger.Value,...
                obj.figMain.XCite.pwm.LED(3).trigger.Value,...
                obj.figMain.XCite.pwm.LED(4).trigger.Value);
            
            obj.hardware.XCite.setPWM(...
                obj.figMain.XCite.pwm.buttons.start.Value);
                
            obj.hardware.XCite.setRepeatLoop(...
                obj.figMain.XCite.pwm.buttons.repeat.Value);
                
            obj.hardware.XCite.setPWMunits(...
                obj.figMain.XCite.pwm.LED(1).units.Value - 1,...
                obj.figMain.XCite.pwm.LED(2).units.Value - 1,...
                obj.figMain.XCite.pwm.LED(3).units.Value - 1,...
                obj.figMain.XCite.pwm.LED(4).units.Value - 1);
                
            obj.XCiteRefresh();
        end
        
        function XCiteRefresh(obj)
        
            [w,x,y,z] = obj.hardware.XCite.getLedOn();
            obj.figMain.XCite.leds.LED(1).button.Value = w;
            obj.figMain.XCite.leds.LED(2).button.Value = x;
            obj.figMain.XCite.leds.LED(3).button.Value = y;
            obj.figMain.XCite.leds.LED(4).button.Value = z;

            [w,x,y,z] = (100/255) * obj.hardware.XCite.getIntensity();
            obj.figMain.XCite.leds.LED(1).intensity.Value = w;
            obj.figMain.XCite.leds.LED(2).intensity.Value = x;
            obj.figMain.XCite.leds.LED(3).intensity.Value = y;
            obj.figMain.XCite.leds.LED(4).intensity.Value = z;
                
            [w,x,y,z] = obj.hardware.XCite.getPulseMode() + 1;
            obj.figMain.XCite.leds.LED(1).pm.Value = w;
            obj.figMain.XCite.leds.LED(2).pm.Value = x;
            obj.figMain.XCite.leds.LED(3).pm.Value = y;
            obj.figMain.XCite.leds.LED(4).pm.Value = z;
                
            [w,x,y,z] = obj.hardware.XCite.getISGdelayTime();
            obj.figMain.XCite.pwm.LED(1).delay.Value = w;
            obj.figMain.XCite.pwm.LED(2).delay.Value = x;
            obj.figMain.XCite.pwm.LED(3).delay.Value = y;
            obj.figMain.XCite.pwm.LED(4).delay.Value = z;
            
            [w,x,y,z] = obj.hardware.XCite.getISGonTime();
            obj.figMain.XCite.pwm.LED(1).ontime.Value = w;
            obj.figMain.XCite.pwm.LED(2).ontime.Value = x;
            obj.figMain.XCite.pwm.LED(3).ontime.Value = y;
            obj.figMain.XCite.pwm.LED(4).ontime.Value = z;
                
            [w,x,y,z] = obj.hardware.XCite.getISGoffTime();
            obj.figMain.XCite.pwm.LED(1).offtime.Value = w;
            obj.figMain.XCite.pwm.LED(2).offtime.Value = x;
            obj.figMain.XCite.pwm.LED(3).offtime.Value = y;
            obj.figMain.XCite.pwm.LED(4).offtime.Value = z;
                
            [w,x,y,z] = obj.hardware.XCite.getISGtriggerTime();
            obj.figMain.XCite.pwm.LED(1).trigger.Value = w;
            obj.figMain.XCite.pwm.LED(2).trigger.Value = x;
            obj.figMain.XCite.pwm.LED(3).trigger.Value = y;
            obj.figMain.XCite.pwm.LED(4).trigger.Value = z;
            
            x = obj.hardware.XCite.getPWM();
            obj.figMain.XCite.pwm.buttons.start.Value = x;
                
            x = obj.hardware.XCite.getRepeatLoop();
            obj.figMain.XCite.pwm.buttons.repeat.Value = x;
                
            [w,x,y,z] = obj.hardware.XCite.getPWMunits() + 1;
            obj.figMain.XCite.pwm.LED(1).units.Value = w;
            obj.figMain.XCite.pwm.LED(2).units.Value = x;
            obj.figMain.XCite.pwm.LED(3).units.Value = y;
            obj.figMain.XCite.pwm.LED(4).units.Value = z;
        end
        
        function DMDCallback(obj,~,~)
        end
        
        function DMDRefresh(obj);
        end
    end
    
    events
        DMDConnected
        XCiteConnected
    end
end

