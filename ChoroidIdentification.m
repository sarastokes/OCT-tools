classdef ChoroidIdentification < handle
    % CHOROIDIDENTIFICATION
    %
    % Constructor:
    %   obj = ChoroidIdentification(im);
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
    %   Edges           Canny edge detection result, modified by user
    %
    % History:
    %   2Aug2018 - SSP
    % ---------------------------------------------------------------------

    properties
        RPE
        ILM
        Choroid
        ChoroidParams
        Vertex 		% [x, y] array
    end

    properties (SetObservable, AbortSet)
        Edges 		% Nx2 array
    end

    properties
        waitingForVertex = false;
        waitingForEdge = false;
    end

    properties (SetAccess = private)
        originalImage
        figureHandle
        axHandle
        imHandle
    end

    methods
        function obj = ChoroidIdentification(im)
            if nargin == 0
                im = uigetfile();
            end
            
            if isa(im, 'OCT')
                im = im.octImage;
            end

            % Read image from file if necessary
            if ischar(im)
                im = imread(im);
            end
            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
            obj.originalImage = im;

            obj.createUI();

            % Compile the InPolygon function, if necessary
            if ~exist('InPolygon.mexw64', 'file')
                mex('InPolygon.c');
            end

            addlistener(obj, 'Edges', 'PostSet', @obj.onEdgesChanged);
        end
    end

    % User interface functions
    methods (Access = private)
        function plotChoroid(obj)
            % PLOTCHOROID
            delete(findobj(obj.figureHandle, 'Tag', 'Choroid'));
            line(obj.axHandle, obj.Choroid(:, 1), obj.Choroid(:, 2),...
                'Color', 'r', 'LineWidth', 0.5,...
                'Tag', 'Choroid');
            set(findobj(obj.figureHandle, 'Tag', 'ShowChoroid'),...
                'Value', 1);
        end

        function plotEdges(obj, newEdges)
            % PLOTEDGES
            line(obj.axHandle,...
                newEdges(:, 1), newEdges(:, 2),...
                'Marker', '.', 'MarkerSize', 1,...
                'Color', [0 1 1], 'LineStyle', 'none',...
                'Tag', 'Edges');
            set(findobj(obj.figureHandle, 'Tag', 'ShowEdges'),...
                'Value', 1);
        end

        function addSegmentation(obj)
            % ADDSEGMENTATION
            [obj.ILM, obj.RPE] = simpleSegmentation(obj.originalImage);
            % Delete existing
            delete(findobj(obj.figureHandle, 'Tag', 'RPE'));
            delete(findobj(obj.figureHandle, 'Tag', 'ILM'));
            % Plot ILM and RPE lines
            line(obj.RPE(:, 1), obj.RPE(:, 2),...
                'Parent', obj.axHandle,...
                'LineWidth', 1.25,...
                'Color', 'b',...
                'Tag', 'RPE');
            line(obj.ILM(:, 1), obj.ILM(:, 2),...
                'Parent', obj.axHandle,...
                'LineWidth', 1.25,...
                'Color', 'b',...
                'Tag', 'ILM');
            set(findobj(obj.figureHandle, 'Tag', 'ShowSegments'),...
                'Value', 1)
        end

        function createUI(obj)
            obj.figureHandle = figure(...
                'Name', 'Choroid Identification',...
                'Color', 'w',...
                'DefaultUicontrolBackgroundColor', 'w',...
                'WindowButtonUpFcn', @obj.buttonUpFcn,...
                'KeyPressFcn', @obj.onKeyPress);
            mainLayout = uix.VBoxFlex('Parent', obj.figureHandle,...
                'BackgroundColor', 'w');

            uicontrol(mainLayout,...
                'Style', 'text',...
                'String', '',...
                'Tag', 'Stat');

            % Set up image display
            obj.axHandle = axes('Parent', uipanel(mainLayout,...
                'BackgroundColor', 'w'));
            obj.imHandle = imagesc(obj.axHandle, obj.originalImage);
            colormap(obj.figureHandle, gray);
            axis(obj.axHandle, 'equal', 'tight', 'off');
            hold(obj.axHandle, 'on');

            % Set up UI controls
            uiLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            segmentLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(segmentLayout,...
                'Style', 'push',...
                'String', 'Segment RPE and ILM',...
                'Callback', @obj.onSegmentImage);
            uicontrol(segmentLayout,...
                'Style', 'check',...
                'String', 'Show RPE and ILM',...
                'Tag', 'ShowSegments',...
                'Callback', @obj.onShowSegments);
            choroidLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(choroidLayout,...
                'Style', 'push',...
                'String', 'Assign choroid vertex',...
                'Tag', 'AssignVertex',...
                'Callback', @obj.onAssignVertex);
            uicontrol(choroidLayout,...
                'Style', 'push',...
                'String', 'Fit Choroid',...
                'Tag', 'FitChoroid',...
                'Callback', @obj.onFitChoroid);
            uicontrol(choroidLayout,...
                'Style', 'check',...
                'String', 'Show Choroid',...
                'Enable', 'off',...
                'Tag', 'ShowChoroid',...
                'Callback', @obj.onShowChoroid);
            edgeLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            getEdgeLayout = uix.HBox('Parent', edgeLayout,...
                'BackgroundColor', 'w');
            uicontrol(getEdgeLayout,...
                'Style', 'text',...
                'String', 'Edges: ');
            uicontrol(getEdgeLayout,...
                'Style', 'push',...
                'String', 'Detect',...
                'Tag', 'DetectEdges',...
                'Enable', 'off',...
                'Callback', @obj.onDetectEdges);
            uicontrol(getEdgeLayout,...
                'Style', 'push',...
                'String', 'Load',...
                'Tag', 'LoadEdges',...
                'Callback', @obj.onLoadEdges);
            uicontrol(getEdgeLayout,...
                'Style', 'push',...
                'String', 'Save',...
                'Tag', 'SaveEdges',...
                'Enable', 'off',...
                'Callback', @obj.onSaveEdges);
            uicontrol(edgeLayout,...
                'Style', 'check',...
                'String', 'Show Edges',...
                'Tag', 'ShowEdges',...
                'Enable', 'off',...
                'Callback', @obj.onShowEdges);
            excludeLayout = uix.HBox('Parent', edgeLayout,...
                'BackgroundColor', 'w');
            uicontrol(excludeLayout,...
                'Style', 'push',...
                'String', 'Exclude Edges',...
                'Tag', 'ExcludeEdges',...
                'Enable', 'off',...
                'Callback', @obj.onExcludeEdges);
            uicontrol(excludeLayout,...
                'Style', 'push',...
                'String', 'Cut outliers',...
                'Callback', @obj.onExcludeOutliers);
            uicontrol(excludeLayout,...
                'Style', 'edit',...
                'String', '',...
                'Tag', 'Bound');
            saveLayout = uix.VBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            uicontrol(saveLayout, 'Style', 'text', 'String', 'OCT Name:');
            uicontrol(saveLayout,...
                'Style', 'edit',...
                'String', '',...
                'Tag', 'OCTName');
            uicontrol(saveLayout,...
                'Style', 'push',...
                'String', 'Save All',...
                'Callback', @obj.onSaveAll);
            uicontrol(saveLayout,...
                'Style', 'push',...
                'String', 'Save image',...
                'Callback', @obj.onExportFigure);
            set(uiLayout, 'Widths', [-1, -1, -1.5, -0.5]);
            set(mainLayout, 'Heights', [-0.5, -6, -1.5]);
        end
    end

    methods (Access = private)
        function onEdgesChanged(obj, ~, ~)
            h = findobj(obj.figureHandle, 'Tag', 'Edges');
            set(h, 'XData', obj.Edges(:, 1), 'YData', obj.Edges(:, 2));
        end
    end

    methods (Access = private)
        function detectEdges(obj)
            % DETECTEDGES
            if isempty(obj.RPE)
                obj.addSegmentation();
            end
            bw1 = edge(obj.originalImage, 'Canny');
            % Exclude points below RPE
            bw1(min(obj.ILM(10:end-20,2)):end,:) = false;
            % Exclude points above choroid vertex
            if ~isempty(obj.Vertex)
                bw1(1:obj.Vertex(2)-10, :) = false;
            end
            [r, c] = find(bw1);
            obj.plotEdges([c, r]);
            obj.Edges = [c, r];
        end

        function detectChoroid(obj)
            % FITCHOROID
            [fitted, obj.ChoroidParams] = parabola_leastsquares(...
                obj.Edges(:, 1), obj.Edges(:, 2));
            obj.Choroid = [obj.Edges(:, 1), fitted];
            set(findobj(obj.figureHandle, 'Tag', 'ShowChoroid'),...
                'Enable', 'on');
            obj.plotChoroid();
            obj.statusUpdate(sprintf('Fit Choroid: %.2f, %.2f, %.4f',...
                obj.ChoroidParams));
        end

        function statusUpdate(obj, str)
            % STATUSUPDATE  Update status text
            if nargin < 2
                str = '';
            else
                assert(ischar(str), 'Status updates must be char');
            end
            set(findobj(obj.figureHandle, 'Tag', 'Stat'), 'String', str);
            drawnow;
        end

        function showByTag(obj, tag, action)
            % SHOWBYTAG
            set(findobj(obj.figureHandle, 'Tag', tag),...
                'Visible', action);
        end
    end

    methods (Access = private)
        function buttonUpFcn(obj, src, ~)
            if obj.waitingForVertex
                obj.Vertex = round(src.CurrentAxes.CurrentPoint(1,1:2));
                delete(findall(obj.figureHandle, 'Tag', 'Vertex'));
                line(obj.axHandle, obj.Vertex(1), obj.Vertex(2),...
                    'Marker', '+',...
                    'MarkerSize', 5,...
                    'Color', rgb('orange'),...
                    'Tag', 'Vertex');
                obj.waitingForVertex = false;
                set(findall(obj.figureHandle, 'Tag', 'AssignVertex'),...
                    'String', 'Change Vertex',...
                    'BackgroundColor', 'w');
                set(findobj(obj.figureHandle, 'Tag', 'DetectEdges'),...
                    'Enable', 'on');
            elseif obj.waitingForEdge
                newEdge = round(src.CurrentAxes.CurrentPoint(1,1:2));
                obj.Edges = cat(1, obj.Edges, newEdge);
                obj.waitingForEdge = false;
                obj.statusUpdate('');
            end
        end

        function onKeyPress(~, src, evt)
            assignin('base', 'evt', evt);
            assignin('base', 'src', src);
        end

        function onSegmentImage(obj, ~, ~)
            obj.statusUpdate('Segmenting Image');
            obj.addSegmentation();
            obj.statusUpdate('');
        end

        function onExportFigure(obj, ~, ~)
            newAxes = exportFigure(obj.axHandle);
            [fname, fpath] = uiputfile('*.png');
            print(newAxes.Parent, [fpath, filesep, fname], '-dpng', '-r600');
        end

        function onDetectEdges(obj, ~, ~)
            obj.detectEdges();
            set(findobj(obj.figureHandle, 'Tag', 'ShowEdges'),...
                'Enable', 'on');
            set(findobj(obj.figureHandle, 'Tag', 'SaveEdges'),...
                'Enable', 'on');
            set(findobj(obj.figureHandle, 'Tag', 'ExcludeEdges'),...
                'Enable', 'on');
        end

        function onLoadEdges(obj, ~, ~)
            [fName, fPath] = uigetfile('*.txt');
            newEdges = dlmread([fPath, filesep, fName]);
            obj.plotEdges(newEdges);
            obj.Edges = newEdges;
            set(findobj(obj.figureHandle, 'Tag', 'ShowEdges'),...
                'Enable', 'on');
            set(findobj(obj.figureHandle, 'Tag', 'SaveEdges'),...
                'Enable', 'on');
            set(findobj(obj.figureHandle, 'Tag', 'ExcludeEdges'),...
                'Enable', 'on');
        end

        function onSaveEdges(obj, ~, ~)
            [fname, fpath] = uiputfile('*.txt');
            dlmwrite([fpath, fname], obj.Edges);
        end

        function onShowSegments(obj, src, ~)
            if src.Value == 1
                action = 'on';
            else
                action = 'off';
            end
            obj.showByTag('RPE', action);
            obj.showByTag('ILM', action);
        end

        function onShowEdges(obj, src, ~)
            if src.Value == 1
                action = 'on';
            else
                action = 'off';
            end
            obj.showByTag('Edges', action);
        end

        function onShowChoroid(obj, src, ~)
            if src.Value == 1
                action = 'on';
            else
                action = 'off';
            end
            obj.showByTag('Choroid', action);
        end

        function onAssignVertex(obj, src, ~)
            obj.waitingForVertex = true;
            set(src, 'BackgroundColor', [0.5 0.5 0.5],...
                'String', 'Waiting....')
        end

        function onExcludeEdges(obj, src, ~)
            set(src, 'String', 'Waiting...',...
                'BackgroundColor', [0.5 0.5 0.5]);
            % Draw a polygon region of interest
            roi = imfreehand(obj.axHandle);
            pos = roi.getPosition();
            % Just in case the polygon wasn't closed...
            pos = [pos; pos(1,:)];
            [~, ~, ind] = InPolygon(obj.Edges(:, 1), obj.Edges(:, 2),...
                pos(:, 1), pos(:, 2));
            h = findobj(obj.figureHandle, 'Tag', 'Edges');
            obj.Edges(ind,:) = [];
            set(h, 'XData', obj.Edges(:, 1), 'YData', obj.Edges(:, 2));
            roi.delete();
            set(src, 'String', 'Exclude Edges',...
                'BackgroundColor', 'w');
        end

        function onAddEdges(obj, ~, ~)
            obj.waitingForEdge = true;
            obj.statusUpdate('Waiting for new edge');
        end

        function onExcludeOutliers(obj, ~, ~)
            if isempty(obj.Choroid)
                obj.statusUpdate('Requires existing choroid fit');
                return;
            end

            h = findobj(obj.figureHandle, 'Tag', 'Bound');
            try
                bnd = str2double(get(h, 'String'));
                set(h, 'BackgroundColor', 'w');
            catch
                set(h, 'BackgroundColor', 'r');
                obj.statusUpdate('Bound did not convert to valid integer');
                return;
            end

            lowerBound = obj.Choroid(:, 2) - bnd;
            upperBound = obj.Choroid(:, 2) + bnd;

            % Identify edges outside of boundary
            excludedEdges = [];
            for i = 1:size(obj.Edges, 1)
                if obj.Edges(i, 2) < lowerBound(i)
                    excludedEdges = [excludedEdges, i]; %#ok
                elseif obj.Edges(i, 2) > upperBound(i)
                    excludedEdges = [excludedEdges, i]; %#ok
                end
            end
            obj.Edges(unique(excludedEdges), :) = [];
            % Replot edges
            h = findobj(obj.figureHandle, 'Tag', 'Edges');
            set(h, 'XData', obj.Edges(:, 1), 'YData', obj.Edges(:, 2));
        end

        function onFitChoroid(obj, ~, ~)
            if ~isempty(obj.Edges)
                obj.detectChoroid();
            end
        end

        function onSaveAll(obj, ~, ~)
            h = findobj(obj.figureHandle, 'Tag', 'OCTName');
            if ~isempty(h.String)
                octName = h.String;
            else
                return
            end
            fpath = [uigetdir(), filesep, octName];
            dlmwrite([fpath, '_edges.txt'], obj.Edges);
            dlmwrite([fpath, '_choroid.txt'], obj.Choroid);
            dlmwrite([fpath, '_rpe.txt'], obj.RPE);
            dlmwrite([fpath, '_ilm.txt'], obj.ILM);
            dlmwrite([fpath, '_parabola.txt'], obj.ChoroidParams);
            fprintf('Saved as: %s\n', fpath);
        end
    end
end
