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

    properties
        RPE
        ILM 
        Choroid
        ChoroidParams
        ControlPoints
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
                im = uigetfile({'*.png'; '*.tiff'; '*.jpeg'});
                if ~ischar(im)
                    disp('No image selected!');
                    return
                end
            end
            
            % Parse input file, get image
            if isa(im, 'OCT')
                im = im.octImage;
            elseif ischar(im)
                im = imread(im);
            end

            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
            obj.originalImage = im;

            % Compile the InPolygon function, if necessary
            octDir = [fileparts(mfilename('fullpath')), filesep, 'lib'];
            if ~exist([octDir, filesep, 'InPolygon.mex64'], 'file')
                try
                    mex([octDir, filesep, 'InPolygon.c']);
                catch
                    error('Need to compile InPolygon.c');
                end
            end

            obj.createUI();
        end
    end

    % Analysis functions
    methods (Access = private)
        function detectChoroid(obj)
            % DETECTCHOROID  Run choroid detection fit
            
            % Fit parabola to control points
            [~, ind] = sort(obj.ControlPoints);
            obj.ControlPoints = obj.ControlPoints(ind(:, 1), :);

            [~, obj.ChoroidParams] = parabola_leastsquares(...
                obj.ControlPoints(:, 1), obj.ControlPoints(:, 2), false);
            
            % Evaluate over entire image x-axis
            xpts = 1:size(obj.imHandle.CData, 2);
            obj.Choroid = [xpts; parabola(xpts, obj.ChoroidParams)]';
            
            % Must have a fitted choroid to display it
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
            % PLOTCONTROLPOINT
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
            % set(src, 'BackgroundColor', [0.5, 0.5, 0.5],...
            %     'String', 'Waiting...');
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
    end

    % User interface setup functions run at initialization
    methods
        function createUI(obj)
            % CREATEUI  Initialize the user interface
            obj.figHandle = figure(...
                'Name', 'ChoroidApp',...
                'Color', 'w',...
                'DefaultUicontrolBackgroundColor', 'w',...
                'WindowButtonUpFcn', @obj.onWindowButtonUp);
            
            mainLayout = uix.VBoxFlex('Parent', obj.figHandle,...
                'BackgroundColor', 'w');

            % Status display
            uicontrol(mainLayout, 'Style', 'text',...
                'String', '',...
                'FontSize', 16,...
                'FontWeight', 'bold',...
                'Tag', 'Status');
            
            % Setup the image display
            obj.axHandle = axes(...
                'Parent', uipanel(mainLayout, 'BackgroundColor', 'w'));
            obj.imHandle = imagesc(obj.axHandle, obj.originalImage);
            colormap(obj.figHandle, gray);
            axis(obj.axHandle, 'equal', 'tight', 'off');
            hold(obj.axHandle, 'on');

            % Set up UI controls
            uiLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            
            % UI for retinal layer segmentation
            segmentLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(segmentLayout, 'Style', 'push',...
                'String', 'Segment RPE and ILM',...
                'Callback', @obj.onSegmentRetina);
            uicontrol(segmentLayout, 'Style', 'check',...
                'String', 'Show RPE and ILM',...
                'Tag', 'ShowRetina',...
                'Callback', @obj.onShowRetinaSegmentation);

            % UI for choroid parabola control points
            controlLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(controlLayout, 'Style', 'text',...
                'String', 'Control Points:',...
                'FontWeight', 'bold');
            uicontrol(controlLayout, 'Style', 'push',...
                'String', 'Add Point',...
                'Tag', 'AddPts',...
                'Callback', @obj.onAddCtrlPoint);
            uicontrol(controlLayout, 'Style', 'push',...
                'String', 'Clear points',...
                'Tag', 'ClearPts',...
                'Callback', @obj.onClearCtrlPoints);
            
            % UI for fitting choroid
            choroidLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(choroidLayout, 'Style', 'text',...
                'String', 'Choroid:',...
                'FontWeight', 'bold');
            uicontrol(choroidLayout, 'Style', 'push',...
                'String', 'Fit Choroid',...
                'Tag', 'FitChoroid',...
                'Enable', 'off',...
                'Callback', @obj.onFitChoroid);
            uicontrol(choroidLayout, 'Style', 'check',...
                'String', 'Show Choroid',...
                'Tag', 'ShowChoroid',...
                'Callback', @obj.onShowChoroid);

            % UI for saving and exporting analysis
            saveLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(saveLayout, 'Style', 'text', 'String', 'OCT Name:');
            uicontrol(saveLayout, 'Style', 'edit',...
                'String', '',...
                'Tag', 'OCTName');
            uicontrol(saveLayout, 'Style', 'push',...
                'String', 'Save All',...
                'Callback', @obj.onSaveAll);
            uicontrol(saveLayout, 'Style', 'push',...
                'String', 'Save image',...
                'Callback', @obj.onExportFigure);

            set(uiLayout, 'Widths', [-1, -1, -1, -0.5]);
            set(mainLayout, 'Heights', [-0.5, -6, -1.5]);
        end
    end
end