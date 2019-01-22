function [rpe, ilm] = simpleSegmentation(img, varargin)
    % SIMPLESEGMENTATION
    %
    % Description:
    %   Segmentation of ILM and RPE from OCT b-scan with graph theory:
    %
    % Syntax:
    %   [rpe, ilm] = simpleSegmentation(img, varargin);
    %
    % Input:
    %   img         OCT b-scan image or OCT image file name
    % Optional key/value inputs:
    %   Plot        Display image with segmented layers, default = false.
    %   FileName    File name to save image, if empty image is not saved.
    %               Saves to current 
    % Output:
    %   layers      RPE and ILM layers
    %
    % Notes:
    %   - If given an RGB image, rgb2gray is used to convert to grayscale.
    %   - Check the ILM, RPE label as these sometimes get switched.
    %   - Currently no resize of image. Use imresize before running the
    %     function to reduce computation time.
    %
    % References:
    %   Chiu SJ et al, Automatic segmentation of seven retinal layers in
    %       SDOCT images congruent with expert manual segmentation,
    %       Optics Express, 2010;18(18);19413-19428
    %
    % History:
    %   Original - Pangyu Teng (from Mathworks File Exchange)
    %   3Aug2018 - SSP - slightly modified, wrapped in function
    %   5Aug2018 - SSP - changed output from [y;x] to [x,y]
    % ---------------------------------------------------------------------
    
    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'Plot', false, @islogical);
    addParameter(ip, 'FileName', [], @ischar);
    parse(ip, varargin{:});
    
    fname = ip.Results.FileName;
    if ~isempty(fname)
        plotme = true;
    else
        plotme = ip.Results.Plot;
    end
    
    if ischar(img)
        img = imread(img);
    end
    
    img = im2double(img);

    if numel(size(img)) == 3
        img = rgb2gray(img);
    end
    
    % Keep a copy of the input image for plotting
    originalImg = img;

    % Simplify image by blurring
    img = imfilter(img, fspecial('gaussian', [5, 20], 3));

    % TODO: Shrink if necessary?

    % ----------------------
    % Generate graph weights
    % ----------------------

    % Pad image with vertical column on both sides
    imgNew = padarray(img, [0, 1], 0, 'both');
    szImgNew = size(imgNew);

    % Get the vertical gradient (dF/dy)
    % TODO: gradient2?
    gradImg = nan(szImgNew);
    for i = 1:szImgNew(2)
        gradImg(:,i) = -1*gradient(imgNew(:,i),2);
    end
    gradImg = (gradImg-min(gradImg(:)))/(max(gradImg(:))-min(gradImg(:)));

    % Get the invert of the gradient image
    gradImgMinus = gradImg*-1+1;

    % --------------------------------------------------------
    % Generate adjacency matrix (Chiu et al 2010 - equation 1)
    % --------------------------------------------------------
    minWeight = 1e-5;
    % Array to store weights
    adjMW = nan(numel(imgNew(:)), 8);
    % Array to store negative weights
    adjMmW = adjMW;
    % Point A locations
    adjMX = adjMW;
    % Point B locations
    adjMY = adjMW;

    neighborIter = [1 1  1 0  0 -1 -1 -1;...
        1 0 -1 1 -1  1  0 -1];

    % Fill in arrays according to Section 3.2
    szadjMW = size(adjMW);
    ind = 1; indR = 0;
    fprintf('Progress:\n');
    while ind ~= szadjMW(1)*szadjMW(2)
        [i, j] = ind2sub(szadjMW,ind);
        [iX,iY] = ind2sub(szImgNew,i);
        jX = iX + neighborIter(1,j);
        jY  = iY + neighborIter(2,j);
        % Save the weights
        if jX >=1 && jX <= szImgNew(1) && jY >=1 && jY <= szImgNew(2)
            % Set to minimum if on the sides
            if jY == 1 || jY == szImgNew(2)
                adjMW(i,j) = minWeight;
                adjMmW(i,j) = minWeight;
                % Calculate weight based on equation 1.
            else
                adjMW(i,j) = 2 - gradImg(iX,iY) ...
                    - gradImg(jX,jY) + minWeight;
                adjMmW(i,j) = 2 - gradImgMinus(iX,iY) ... 
                    - gradImgMinus(jX,jY) + minWeight;
            end
            % Save the rows/columns of the corresponding nodes
            adjMX(i,j) = sub2ind(szImgNew,iX,iY);
            adjMY(i,j) = sub2ind(szImgNew,jX,jY);
        end
        ind = ind+1;

        %display progress
        if indR < round(10*ind/szadjMW(1)/szadjMW(2))
            indR = round(10*ind/szadjMW(1)/szadjMW(2));
            fprintf('%1.0f%%  ', 100*indR/10);
        end

    end
    fprintf('\nCalculating adjacency matrix and shortest paths\n');
    
    % Assemble adjacency matrix
    keepInd = ~isnan(adjMW(:)) & ~isnan(adjMX(:)) & ... 
        ~isnan(adjMY(:)) & ~isnan(adjMmW(:));
    adjMW = adjMW(keepInd);
    adjMmW = adjMmW(keepInd);
    adjMX = adjMX(keepInd);
    adjMY = adjMY(keepInd);

    % Sparse matrices based on equation 1 with the gradient
    adjMatrixW = sparse(adjMX(:),adjMY(:),adjMW(:),...
        numel(imgNew(:)),numel(imgNew(:)));
    % and the "invert" of gradient.
    adjMatrixMW = sparse(adjMX(:),adjMY(:),adjMmW(:),...
        numel(imgNew(:)),numel(imgNew(:)));

    % ---------------------
    % Get the shortest path
    % ---------------------

    % Layer going from dark to light
    [~, path{1}] = graphshortestpath(adjMatrixMW, 1, numel(imgNew(:)));
    [pathX,pathY] = ind2sub(szImgNew, path{1});

    % Layer going from light to dark
    [~, path2{1}] = graphshortestpath(adjMatrixW, 1, numel(imgNew(:)));
    [pathX2, pathY2] = ind2sub(szImgNew, path2{1});

    % Remove image borders
    pathX =pathX(gradient(pathY)~=0);
    pathY =pathY(gradient(pathY)~=0);
    pathX2 = pathX2(gradient(pathY2)~=0);
    pathY2 = pathY2(gradient(pathY2)~=0);

    % ------------------
    % Visualize and save
    % ------------------
    if plotme
        fh = figure('Name', 'OCT Segmentation'); hold on;
        imagesc(originalImg); 
        axis image off; 
        colormap('gray'); 
        plot(pathY, pathX, 'g--', 'LineWidth', 1.5);
        plot(pathY2, pathX2, 'r--', 'LineWidth', 1.5);
        legend({'rpe', 'ilm'});
        tightfig(fh);
        if ~isempty(fname)
            if ~isempty(strfind(fname), filesep)
                fname = [cd, filesep, fname];
            end
            fprintf('Saving to %s\n', fname);
            print(fh, fname, '-dpng', '-r600');
        end
    end

    ilm = [pathY; pathX]';
    rpe = [pathY2; pathX2]';
end