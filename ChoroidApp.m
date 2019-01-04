classdef ChoroidApp < handle
    % CHOROIDAPP
    %
    % Constructor:
    %   obj = ChoroidApp(im);
    %
    % Input:
    %   im          Image or file name or OCT class
    %               If empty will prompt to choose image from file
    %
    % Properties:
    %   RPE             RPE-Choroid boundary
    %   ILM             ILM boundary
    %   Choroid         Choroid upper boundary
    %   ChoroidParams   Parameters to create parabola/Choroid
    %   ControlPoints   Points to fit parabola
    %
    % History:
    %   2Aug2018 - SSP - original ChoroidIdentification
    %   18Dec2018 - SSP - new framework, no edge detection
    %   ---------------------------------------------------------------------    

    properties (SetAccess = private)
        RPE
        ILM 
        ChoroidParams
        ControlPoints
    end

    properties (SetObservable, AbortSet)
        Choroid
    end

    properties
        waitingForPoint = false;
    end

    properties (SetAccess = private)
        originalImage
        figHandle
        axHandle
        imHandle
    end

    methods 
        function obj = ChoroidApp(im)
            if nargin == 0
                im = uigetfile({'*.png'; '*.tiff'; '*.jpeg'; '*.jpg'});
                if ~ischar(im)
                    disp('No image selected!');
                    return
                end
            end
            
            obj.parseInput(im);
            
            obj.createUI();
        end
        
        function addControlPoints(obj, newPoints)
            for i = 1:size(newPoints, 1)
                obj.ControlPoints = cat(1, obj.ControlPoints, newPoints(i,:));
                obj.plotLastControlPoint();
            end
            obj.ControlPoints = unique(obj.ControlPoints, 'rows');
            set(findobj(obj.figHandle, 'Tag', 'FitChoroid'),...
                    'Enable', 'on');
        end
    end

    % Analysis functions
    methods (Access = private)
        function detectChoroid(obj)
            % DETECTCHOROID  Run choroid detection fit
            
            [~, ind] = sort(obj.ControlPoints);
            obj.ControlPoints = obj.ControlPoints(ind(:, 1), :);

            % Fit parabola to control points
            [~, obj.ChoroidParams] = parabola_leastsquares(...
                obj.ControlPoints(:, 1), obj.ControlPoints(:, 2), false);
            
            % Evaluate over entire image x-axis
            xpts = 1:size(obj.imHandle.CData, 2);
            obj.Choroid = [xpts; parabola(xpts, obj.ChoroidParams)]';
            
            % Update the user interface accordingly
            set(findobj(obj.figHandle, 'Tag', 'ShowChoroid'),...
                'Enable', 'on', 'Value', 1);
            obj.statusUpdate(sprintf('Fit Choroid: %.2f, %.2f, %.4f',...
                obj.ChoroidParams));
        end

        function detectRetina(obj)
            % DETECTRETINA  Run retinal layer segmentation
            [obj.ILM, obj.RPE] = simpleSegmentation(obj.originalImage);
            obj.plotRetina();
            % Make sure show segmented retina checkbox is checked
            set(findobj(obj.figHandle, 'Tag', 'ShowRetina'), 'Value', 1);
        end
    end
    
    % Plotting functions
    methods (Access = private)
        function plotChoroid(obj)
            % PLOTCHOROID  Plots fitted chroroid
            delete(findobj(obj.figHandle, 'Tag', 'Choroid'));
            line(obj.axHandle, obj.Choroid(:, 1), obj.Choroid(:, 2),...
                'Color', 'r', 'LineWidth', 0.5,...
                'Tag', 'Choroid');
            set(findobj(obj.figHandle, 'Tag', 'ShowChoroid'),...
                'Value', 1);
        end

        function plotRetina(obj)
            % PLOTRETINA  Plots segmented RPE and ILM 
            delete(findobj(obj.figHandle, 'Tag', 'RPE'));
            delete(findobj(obj.figHandle, 'Tag', 'ILM'));
            % Plot new segmentation
            line(obj.RPE(:, 1), obj.RPE(:, 2),...
                'Parent', obj.axHandle,...
                'LineWidth', 1.25, 'Color', 'b',...
                'Tag', 'RPE');
            line(obj.ILM(:, 1), obj.ILM(:, 2),...
                'Parent', obj.axHandle,...
                'LineWidth', 1.25, 'Color', 'b',...
                'Tag', 'ILM');
        end

        function plotLastControlPoint(obj)
            % PLOTCONTROLPOINT  Add most recent control point to plot
            line(obj.ControlPoints(end, 1), obj.ControlPoints(end, 2),...
                'Parent', obj.axHandle,...
                'Marker', '+', 'MarkerSize', 5,...
                'Color', rgb('orange'),...
                'Tag', 'CtrlPt');
        end
    end
    
    % Callback functions
    methods (Access = private)
        function onShowRetinaSegmentation(obj, src, ~)
            if src.Value == 1
                action = 'on';
            else
                action = 'off';
            end
            obj.showByTag('RPE', action);
            obj.showByTag('ILM', action);
        end

        function onSegmentRetina(obj, ~, ~)
            obj.statusUpdate('Segmenting Image...');
            obj.detectRetina();
            obj.statusUpdate('');
        end

        function onAddCtrlPoint(obj, ~, ~)
            obj.waitingForPoint = true;
            obj.statusUpdate('Waiting for control point placement');
        end

        function onClearCtrlPoints(obj, ~, ~)
            % ONCLEARCTRLPTS  Delete control points, remove from plot
            obj.ControlPoints = [];
            delete(findall(obj.axHandle, 'Tag', 'CtrlPt'));
        end

        function onFitChoroid(obj, ~, ~)
            if ~isempty(obj.ControlPoints)
                obj.detectChoroid();
                obj.plotChoroid();
            end
        end

        function onUseHistogramApp(obj, ~, ~)
            x = HistogramPeakSlider(obj.originalImage);
            x.addParent(obj);
        end

        function onShowChoroid(obj, src, ~)
            if src.Value == 1
                action = 'on';
            else
                action = 'off';
            end
            obj.showByTag('Choroid', action);
        end
       
        function onExportFigure(obj, ~, ~)
            % ONEXPORTFIGURE  Export image with any visible segmentation
            newAxes = exportFigure(obj.axHandle);
            [fname, fpath] = uiputfile('*.png');
            print(newAxes.Parent, [fpath, filesep, fname], '-dpng', '-r600');
        end

        function onSaveAll(obj, ~, ~)
            h = findobj(obj.figHandle, 'Tag', 'OCTName');
            if ~isempty(h.String)
                octName = h.String;
            else
                return
            end
            fpath = [uigetdir(), filesep, octName];
            dlmwrite([fpath, '_controlpoints.txt'], obj.ControlPoints);
            dlmwrite([fpath, '_choroid.txt'], obj.Choroid);
            dlmwrite([fpath, '_rpe.txt'], obj.RPE);
            dlmwrite([fpath, '_ilm.txt'], obj.ILM);
            dlmwrite([fpath, '_parabola.txt'], obj.ChoroidParams);
            fprintf('Saved as: %s\n', fpath);
        end
    end

    % Misc user interface helper functions
    methods (Access = private)
        function statusUpdate(obj, str)
            % STATUSUPDATE  Update status text
            if nargin < 2
                str = '';
            else
                assert(ischar(str), 'Status updates must be char');
            end
            set(findobj(obj.figHandle, 'Tag', 'Status'), 'String', str);
            drawnow;
        end

        function showByTag(obj, tag, action)
            % SHOWBYTAG  Toggle visibility of plot object by tag
            set(findobj(obj.figHandle, 'Tag', tag),...
                'Visible', action);
        end

        function flipByTag(obj, tag)
            % FLIPBYTAG  Set visibility to opposite current setting
            h = findobj(obj.figHandle, 'Tag', tag);
            if ~isempty(h)
                set(h, 'Visible', obj.onOff(get(h, 'Visible')));
            end
        end
    end

    % User interaction functions
    methods (Access = private)
        function onWindowButtonUp(obj, src, ~)
            if obj.waitingForPoint
                newPoint = round(src.CurrentAxes.CurrentPoint(1, 1:2));
                obj.ControlPoints = cat(1, obj.ControlPoints, newPoint);
                obj.plotLastControlPoint();
                set(findobj(obj.figHandle, 'Tag', 'FitChoroid'),...
                    'Enable', 'on');
                obj.waitingForPoint = false;
                obj.statusUpdate('');
            end
        end

        function onKeyPress(obj, ~, evt)
            % ONKEYPRESS  Key controls for common actions
            switch evt.Character
                case 'a'                   
                    obj.waitingForPoint = true;
                    obj.statusUpdate('Waiting for control point placement');
                case 'f'
                    if ~isempty(obj.ControlPoints)
                        obj.detectChoroid();
                    end
                case 'c'
                    obj.flipByTag('Choroid');
                case 'r'
                    obj.flipByTag('RPE');
                    obj.flipByTag('ILM');
            end
        end
    end

    % User interface setup functions run at initialization
    methods
        function createUI(obj)
            % CREATEUI  Initialize the user interface
            obj.figHandle = figure(...
                'Name', 'ChoroidApp',...
                'Color', 'w',...
                'DefaultUicontrolBackgroundColor', 'w',...
                'KeyPressFcn', @obj.onKeyPress,...
                'WindowButtonUpFcn', @obj.onWindowButtonUp);
            figPos(obj.figHandle, 1.5, 0.8);
            
            mainLayout = uix.HBoxFlex('Parent', obj.figHandle,...
                'BackgroundColor', 'w');
            octLayout = uix.VBox('Parent', mainLayout,...
                'Padding', 0, 'Spacing', 0,...
                'BackgroundColor', 'w');
            % Status display
            uicontrol(octLayout, 'Style', 'text',...
                'String', '',...
                'FontSize', 16,...
                'FontWeight', 'bold',...
                'Tag', 'Status');
            
            % Setup the image display
            obj.axHandle = axes(...
                'Parent', uipanel(octLayout, 'BackgroundColor', 'w'));
            obj.imHandle = imagesc(obj.axHandle, obj.originalImage);
            colormap(obj.figHandle, gray);
            axis(obj.axHandle, 'equal', 'tight', 'off');
            hold(obj.axHandle, 'on');

            % Set up UI controls
            uiLayout = uix.VBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            
            % UI for retinal layer segmentation
            uix.Empty('Parent', uiLayout);
            uicontrol(uiLayout, 'Style', 'text',...
                'String', 'Retinal Layers:',...
                'FontWeight', 'bold');
            retinaLayout = uix.HBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(retinaLayout, 'Style', 'push',...
                'String', 'Segment',...
                'Callback', @obj.onSegmentRetina);
            uix.Empty('Parent', retinaLayout);
            uicontrol(retinaLayout, 'Style', 'check',...
                'String', 'Show',...
                'TooltipString', 'Toggle display of layers (''r'')',...
                'Tag', 'ShowRetina',...
                'Callback', @obj.onShowRetinaSegmentation);
            set(retinaLayout, 'Widths', [-1, -0.25, -0.75]);
            widths = [-0.25, -0.5, -1];

            % UI for choroid parabola control points
            uix.Empty('Parent', uiLayout);
            uicontrol(uiLayout, 'Style', 'text',...
                'String', 'Control Points:',...
                'FontWeight', 'bold');
            pointLayout = uix.HBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(pointLayout, 'Style', 'push',...
                'String', 'Add Point',...
                'Tag', 'AddPts',...
                'Callback', @obj.onAddCtrlPoint);
            uix.Empty('Parent', pointLayout);
            uicontrol(pointLayout, 'Style', 'push',...
                'String', 'Clear points',...
                'Tag', 'ClearPts',...
                'Callback', @obj.onClearCtrlPoints);
            set(pointLayout, 'Widths', [-1, -0.25, -1]);
            uicontrol(uiLayout, 'Style', 'push',...
                'String', 'Use Histogram App',...
                'Callback', @obj.onUseHistogramApp);
            widths = cat(2, widths, [-0.5, -0.5, -1, -1]);
            
            % UI for fitting choroid
            uix.Empty('Parent', uiLayout);
            uicontrol(uiLayout, 'Style', 'text',...
                'String', 'Choroid:',...
                'FontWeight', 'bold');
            choroidLayout = uix.HBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(choroidLayout, 'Style', 'push',...
                'String', 'Fit',...
                'Tag', 'FitChoroid',...
                'Enable', 'off',...
                'Callback', @obj.onFitChoroid);
            uix.Empty('Parent', choroidLayout);
            uicontrol(choroidLayout, 'Style', 'check',...
                'String', 'Show',...
                'TooltipString', 'Toggle display of choroid (''c'')',...
                'Tag', 'ShowChoroid',...
                'Callback', @obj.onShowChoroid);
            set(choroidLayout, 'Widths', [-1, -0.25, -0.75]);
            widths = cat(2, widths, [-0.5, -0.5, -1]);

            % UI for saving and exporting analysis   
            uix.Empty('Parent', uiLayout);
            uicontrol(uiLayout, 'Style', 'text',...
                'String', 'Export:', 'FontWeight', 'bold');         
            nameLayout = uix.HBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(nameLayout, 'Style', 'text', 'String', 'OCT Name:');
            uicontrol(nameLayout, 'Style', 'edit',...
                'String', '',...
                'Tag', 'OCTName');
            saveLayout = uix.HBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(saveLayout, 'Style', 'push',...
                'String', 'Save Data',...
                'Callback', @obj.onSaveAll);
            uicontrol(saveLayout, 'Style', 'push',...
                'String', 'Save image',...
                'Callback', @obj.onExportFigure);
            uix.Empty('Parent', uiLayout);
            widths = cat(2, widths, [-0.5, -0.5, -0.6, -1, -0.25]);
            

            set(uiLayout, 'Heights', widths);
            set(octLayout, 'Heights', [-0.5, -6]);
            set(mainLayout, 'Widths', [-6, -1.5]);
        end

        function parseInput(obj, x)
            % Get OCT image, other attributes if applicable
            if isa(x, 'OCT')
                if ~isempty(x.ControlPoints)
                    selection = questdlg('Import existing control points?');
                    if strcmp(selection, 'Yes')
                        obj.addControlPoints(x.ControlPoints);
                    end
                end
                im = x.octImage;
            elseif ischar(x)
                im = imread(x);
            elseif isnumeric(x)
                im = x;
            else 
                error('CHOROIDAPP:InvalidInput');
            end

            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
            obj.originalImage = im;
        end
    end

    methods (Static)
        function action = onOff(action)
            if strcmp(action, 'on')
                action = 'off';
            else
                action = 'on';
            end
        end
    end
end