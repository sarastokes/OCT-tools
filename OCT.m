classdef OCT < handle
    % OCT
    %
    % Description:
    %   Represents features and analyses of a single OCT b-scan
    %
    % Constructor:
    %   x = OCT(imageID, imagePath)
    %
    % Inputs:
    %   imageID         Image number (also image title)
    %   imagePath       Folder where image and data is stored, optional
    %                   If not provided, opens up UI to choose a folder
    %
    % Methods:
    %   obj.update()
    %   obj.crop()
    %   obj.doAnalysis()
    % Visualization methods:
    %   obj.show()
    %   obj.plotRatio()
    %   obj.plotSizes()
    %   obj.showSegmentation()
    %
    % History:
    %   7Aug2018 - SSP - working version compiled from previous functions
    %   11Aug2018 - SSP - added crop function
    %   14Aug2018 - SSP - added reload option
    %   2Jan2019 - SSP - changed edges to control points
    %   3Jan2019 - SSP - added scale property
    %   4Jan2019 - SSP - crop now happens before rotation and scaling
    % ---------------------------------------------------------------------

    % Identifiers
    properties (SetAccess = private)
        imagePath
        imageID
        refID
    end

    % Segmentation
    properties (SetAccess = public)
        RPE = [];
        ILM = [];
        Choroid = [];
        ChoroidParams = [];
        ControlPoints = [];
        CropValues = [];
        Shift = [];
        Theta = [];
        Scale = [];
    end

    % Analysis
    properties (SetAccess = private)
        choroidSize
        retinaSize
        choroidRatio
    end

    % Lazy loading of images and analysis
    properties (Dependent = true, Hidden = true)
        octImage
        rawImage
        imageName
    end

    % Transient copy of the full original image to support lazy loading
    properties (Hidden = true, SetAccess = private)
        originalImage
    end

    % Features which may have been extracted from the image
    properties (Constant = true, Hidden = true)
        FEATURES = {'rpe', 'ilm', 'choroid', 'parabola', 'controlpoints',...
            'crop', 'shift', 'theta', 'scale'};
    end

    methods
        function obj = OCT(imageID, imagePath)
            % OCT  Constructor
            assert(isnumeric(imageID), 'Image ID must be numeric');

            obj.imageID = imageID;
            if nargin < 2 || ~isfolder(imagePath)
                obj.imagePath = uigetdir();
            else
                obj.imagePath = imagePath;
            end
            fprintf('image path: %s\n', obj.imagePath);

            obj.pull();
            
            if ~isempty(obj.Choroid) && ~isempty(obj.RPE)
                obj.doAnalysis();
            end
        end

        function addRef(obj, refID)
            obj.refID = refID;
        end

        function update(obj)
            obj.pull();
        end

        function im = getSemiProcessedImage(obj, varargin)
            ip = inputParser();
            addParameter(ip, 'Crop', false, @islogical);
            addParameter(ip, 'Scale', false, @islogical);
            addParameter(ip, 'Rotate', false, @islogical);
            parse(ip, varargin{:});

            im = obj.fetchImage(true);
            if ip.Results.Crop
                im = obj.doCrop(im);
            end
            if ip.Results.Scale
                im = obj.doScale(im);
            end
            if ip.Results.Rotate
                im = obj.doRotate(im);
            end
        end
        
        function cropValues = crop(obj, saveValues)
            if nargin < 2
                saveValues = false;
            else
                assert(islogical(saveValues), 'Save values should be t/f');
            end
            
            fh = figure(); 
            [~, cropValues] = imcrop(obj.octImage);
            
            % Return if no crop specified.
            if isempty(cropValues)
                obj.CropValues = [];
                obj.saveJSON();
                return;
            end          
            cropValues = [ceil(cropValues(1:2)), floor(cropValues(3:4))];
            
            if saveValues
                obj.CropValues = cropValues;
                obj.saveJSON();
            end
            delete(fh);
        end
    end

    % Analysis methods
    methods 
        function doAnalysis(obj)
            % Determine the full x-axis
            xpts = obj.getXPts();

            % Evaluate choroid parabola at the x-axis points
            CHOROID = parabola(xpts, obj.ChoroidParams);

            % Interpolate the RPE and ILM boundaries to the new x-axis
            iRPE = interp1(obj.RPE(:, 1), obj.RPE(:, 2), xpts);
            iILM = interp1(obj.ILM(:, 1), obj.ILM(:, 2), xpts);

            % Choroid to RPE-Choroid boundary
            obj.choroidSize = abs(CHOROID - iRPE);
            % RPE-Choroid boundary to ILM
            obj.retinaSize = abs(iRPE - iILM);
            % Ratio of choroid size to retina size
            obj.choroidRatio = obj.choroidSize./obj.retinaSize;
            
            % Shift, if necessary
            % if ~isempty(obj.Shift)
            %     obj.choroidRatio = circshift(obj.choroidRatio, -obj.Shift);
            %     if obj.Shift > 0
            %         obj.choroidRatio(end-abs(obj.Shift):end) = NaN;
            %     elseif obj.Shift < 0
            %         obj.choroidRatio(1:obj.Shift) = NaN;
            %     end
            % end
        end

        function xpts = getXPts(obj, doShift)
            % GETXPTS  Get image x-axis, shifted or unshifted
            if nargin < 2
                doShift = false;
            end
            if ~isempty(obj.RPE) && ~isempty(obj.ILM)
                x_min = min([obj.RPE(:, 1); obj.ILM(:, 1)]);
                x_max = max([obj.RPE(:, 1); obj.ILM(:, 1)]);
                xpts = x_min:x_max;
            else
                xpts = [];
            end
            if doShift && ~isempty(obj.Shift)
                xpts = xpts + obj.Shift;
                fprintf('Applying shift of %.3g pixels\n', obj.Shift);
            end
        end

        function saveJSON(obj)
            % SAVEJSON  Store features as a single .json file
            warning('off', 'MATLAB:structOnObject');
            S = struct(obj);
            S = rmfield(S, {'choroidSize', 'retinaSize', 'choroidRatio'});
            S = rmfield(S, {'imageName', 'FEATURES'});
            S = rmfield(S, {'octImage', 'originalImage', 'rawImage'});

            savejson('', S, [obj.imagePath, filesep, obj.imageName, '.json']);
            warning('on', 'MATLAB:structOnObject');
            fprintf('Saved %s.json\n', obj.imageName);
        end
        
        function igor = igor(obj, smoothFac)
            if nargin < 2
                smoothFac = 12;
            end
            if isempty(obj.choroidRatio)
                obj.doAnalysis();
            end
            igor = [obj.getXPts(true)', smooth(obj.choroidRatio, smoothFac)];
            openvar('igor');
        end
    end

    % Visualization methods
    methods
        function show(obj, ax)
            % SHOW  Plot the OCT image (with rotation and crop)
            if nargin < 2
                ax = axes('Parent', figure());
            end
            imagesc(ax, obj.octImage); colormap(gray);
            title(ax, sprintf('Image #%u', obj.imageID));
            axis image off
            tightfig(gcf);
        end
        
        function ax = plotRatio(obj, varargin)
            % PLOTRATIO  Plot the choroid:retina ratio
            ip = inputParser();
            ip.CaseSensitive = false;
            ip.KeepUnmatched = true;
            addParameter(ip, 'Relative', false, @islogical);
            addParameter(ip, 'Smooth', 10, @isnumeric);
            addParameter(ip, 'ShowData', false, @islogical);
            addParameter(ip, 'Color', rgb('light blue'),...
                @(x) isvector(x) || ischar(x));
            addParameter(ip, 'LineWidth', 1, @isnumeric);
            addParameter(ip, 'Axes', [], @ishandle);
            parse(ip, varargin{:});
            smoothFac = ip.Results.Smooth;

            if isempty(obj.choroidRatio)
                obj.doAnalysis();
            end

            xpts = obj.getXPts(true);
            if isempty(ip.Results.Axes)
                fh = figure('Name', [obj.imageName, ' Choroid'],...
                    'Renderer', 'painters');
                ax = axes('Parent', fh);
                h = plot(ax, [min(xpts), max(xpts)], [1, 1], '--',...
                    'Color', [0.3, 0.3, 0.3], 'LineWidth', 0.75,...
                    'Tag', 'NormLine');
                set(get(get(h, 'Annotation'), 'LegendInformation'),...
                    'IconDisplayStyle', 'off'); 

                set(ax, 'Box', 'off'); grid(ax, 'on');
                ylabel(ax, 'choroid:retina ratio');
                xlabel(ax, 'x-axis (pixels)');

                figPos(fh, 0.7, 0.7);
            else
                ax = ip.Results.Axes;
            end
            hold(ax, 'on');

            if ip.Results.Relative && ~isempty(obj.refID)
                refOCT = OCT(obj.refID, obj.imagePath);
                refRatio = refOCT.choroidRatio;
                thisRatio = obj.choroidRatio;
                if numel(refRatio) > numel(xpts)
                    refRatio(numel(xpts)+1:end) = [];
                elseif numel(xpts) > numel(refRatio)
                    thisRatio(numel(refRatio)+1:end) = [];
                    % xpts = refOCT.getXPts();
                    xpts(numel(refRatio)+1:end) = [];
                end
                plot(ax, xpts, smooth(thisRatio - refRatio, smoothFac),...
                    'Color', ip.Results.Color, 'LineWidth', 1.5);
                set(findobj(ax, 'Tag', 'NormLine'), 'YData', [0, 0]);
                 ylim(ax, [-0.5, 0.5]);
            else
                plot(ax, xpts, smooth(obj.choroidRatio, smoothFac),...
                    'Color', ip.Results.Color,...
                    'LineWidth', ip.Results.LineWidth,...
                    'Tag', obj.imageName, 'DisplayName', obj.imageName);
                 ylim(ax, [0, 2]);
            end

            % Raw data
            if ip.Results.ShowData && ~ip.Results.Relative
                h = plot(ax, xpts, obj.choroidRatio, '.',...
                    'Color', hex2rgb('334de6'), 'MarkerSize', 4,...
                    'Tag', 'Data');
                set(get(get(h, 'Annotation'), 'LegendInformation'),...
                    'IconDisplayStyle', 'off');
            end
            
            xlim(ax, [0, max(xpts)]);
        end

        function plotSizes(obj, ax)
            % PLOTRATIO  Plot raw sizes of choroid and retina
            if isempty(obj.choroidRatio)
                obj.doAnalysis();
            end

            xpts = obj.getXPts(true);
            
            if nargin < 2
                ax = axes('Parent', figure('Renderer', 'painters'),...
                    'Box', 'off', 'XLim', [0, max(xpts)]); 
                hold(ax, 'on'); 
                grid(ax, 'on');                
                xlabel(ax, 'x-axis (pixels)'); 
                ylabel(ax, 'Width (pixels)');
                
                title(ax, [obj.imageName ' - Choroid and Retina Sizes']);
            end

            p1 = plot(ax, xpts, smooth(obj.choroidSize, 10),...
                'b', 'LineWidth', 1, 'Tag', [obj.imageName, '_Choroid']);
            p2 = plot(ax, xpts, smooth(obj.retinaSize, 10),...
                'r', 'LineWidth', 1, 'Tag', [obj.imageName, '_RPE']);
            
            if nargin < 2
                legend([p1, p2], {'Choroid', 'Retina'});
            end
            
        end
        
        function showSegmentation(obj)
            % SHOWSEGMENTATION  Show image with overlaid segmentation
            if isempty(obj.RPE)
                return
            end
            obj.show(); hold on;
            plot(obj.RPE(:, 1), obj.RPE(:, 2), 'b');
            plot(obj.ILM(:, 1), obj.ILM(:, 2), 'b');
            if ~isempty(obj.Choroid)
                plot(obj.Choroid(:, 1), obj.Choroid(:, 2), 'r');
            end
        end
    end

    % Dependent set/get methods
    methods
        function imageName = get.imageName(obj)
            imageName = ['im', num2str(obj.imageID)];
        end

        function octImage = get.octImage(obj)
            if isempty(obj.originalImage)
                octImage = obj.fetchImage();
            else
                octImage = obj.originalImage;
            end

            % Crop/rotate/transform, if necessary
            octImage = obj.doCrop(octImage);
            octImage = obj.doScale(octImage);
            octImage = obj.doRotate(octImage);
        end

        function rawImage = get.rawImage(obj)
            rawImage = obj.fetchImage(true);
        end
    end

    % Private image processing methods
    methods (Access = private)
        function im = fetchImage(obj, getRaw)
            % FETCHIMAGE  Read image from file
            if nargin < 2
                getRaw = false;
            end
            if getRaw
                str = [obj.imagePath, 'raw', filesep, num2str(obj.imageID), '.png'];
            else
                str = [obj.imagePath, num2str(obj.imageID), '.png'];
            end
            im = imread(str);

            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
        end
        
        function im = doCrop(obj, im)
            % DOCROP  Crop the image, if necessary
            if ~isempty(obj.CropValues)
                im = imcrop(im, obj.CropValues);
                fprintf('Cropped by %u, %u\n',...
                    abs(round([size(im, 1) - obj.CropValues(3),...
                               size(im, 2) - obj.CropValues(4)])));
            end
        end

        function im = doScale(obj, im)
            % DOSCALE  Scale the image, if necessary
            if ~isempty(obj.Scale)
                im = imresize(im, obj.Scale);
                fprintf('Scaled by %.4g%%\n', 100 * obj.Scale);
            end
        end

        function im = doRotate(obj, im)
            % DOROTATE  Rotate the image, if necessary
            if ~isempty(obj.Theta)
                im = imrotate(im, obj.Theta);
                fprintf('Applied rotation of %.2f degrees\n', obj.Theta);
            end
        end
    end

    % Private IO methods
    methods (Access = private)
            
        function pull(obj)
            % RELOAD  Reload image and data from .json files
            obj.originalImage = obj.fetchImage();
            hasJSON = obj.loadJSON();
            if ~hasJSON
                obj.saveJSON();
                % disp('Loading .txt files instead');
                % obj.loadTXT();
            end
            if ~isempty(obj.RPE) && ~isempty(obj.Choroid)
                obj.doAnalysis();
            end
        end

        function tf = loadJSON(obj)
            % LOADJSON  Load a .json file
            jsonPath = [obj.imagePath, filesep, obj.imageName, '.json'];
            if ~exist(jsonPath, 'file')
                str = strsplit(jsonPath, filesep);
                fprintf('Did not find file %s\n', str{end});
                tf = false;
            else
                S = loadjson(jsonPath);
                tf = true;
                if isfield(S, 'imageID') && ~isempty(S.imageID)
                    assert(obj.imageID == S.imageID,...
                        'Image ID numbers do not match!');
                end
                
                obj.refID = S.refID;
                obj.RPE = S.RPE; obj.ILM = S.ILM;
                obj.Shift = S.Shift; obj.Theta = S.Theta; obj.Scale = S.Scale;
                obj.CropValues = S.CropValues;
                obj.ControlPoints = S.ControlPoints;
                obj.ChoroidParams = S.ChoroidParams;
                obj.Choroid = S.Choroid;
            end
        end

        function loadTXT(obj)
            % LOAD  Load parameters from file, if they exist
            obj.Choroid = obj.fetch(obj.getPath('choroid'));
            obj.ChoroidParams = obj.fetch(obj.getPath('parabola'));
            obj.RPE = obj.fetch(obj.getPath('rpe'));
            obj.ILM = obj.fetch(obj.getPath('ilm'));
            obj.ControlPoints = obj.fetch(obj.getPath('controlpoints'));
            obj.CropValues = obj.fetch(obj.getPath('crop'));
            obj.Shift = obj.fetch(obj.getPath('shift'));
            obj.Theta = obj.fetch(obj.getPath('theta'));
            obj.Scale = obj.fetch(obj.getPath('scale'));
        end
        
        function str = getPath(obj, x)
            % GETPATH  Returns path of saved feature .txt file
            x = lower(x);
            assert(ismember(x, obj.FEATURES),...
                'Path value not in features list!');
            str = [obj.imagePath, filesep, obj.imageName, '_', x, '.txt'];
        end
    end

    methods (Static)
        function x = fetch(filePath)
            % FETCH  Reads a .txt file if existing, returns message if not
            if ~exist(filePath, 'file')
                str = strsplit(filePath, filesep);
                fprintf('Did not find file %s\n', str{end});
                x = [];
            else
                x = dlmread(filePath);
            end
        end
    end
end
