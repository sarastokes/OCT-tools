function [newIm2, Theta, Scale] = alignImages(oct1, oct2, varargin)
    % ALIGNIMAGES
    % 
    % Description:
    %   Align OCT images of the same eye
    %
    % Syntax:
    %   [newImg, Theta, Scale] = alignImages(im1, im2, varargin)
    %
    % Inputs:
    %   im1         First image
    %   im2         Second image, this one will be rotated/translated
    % Optional key/value inputs:
    %   PlotType    0 = none, 1 = final images (default), 2 = all images
    %   Save        If provided, saves rotation to image 2 as .json
    %   Clip        Points to clip from start + end of each image
    %                 (default = [0, 0])
    % Outputs:
    %   newIm2      Aligned image
    %   Theta       Angle of rotation (imrotate)
    %   Scale       Scale factor applied (imresize)
    %
    % References
    % https://www.mathworks.com/help/vision/examples/
    % find-image-rotation-and-scale-using-automated-feature-matching.html
    %
    % History:
    %   6Aug2018 - SSP
    %   2Jan2019 - SSP - added more input image checking
    %   3Jan2019 - SSP - changed output to include angle and scale
    % ---------------------------------------------------------------------

    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'PlotType', 1, @(x) ismember(x, 1:3));
    addParameter(ip, 'Save', false, @islogical);
    addParameter(ip, 'Clip', [0, 0], @isnumeric);
    parse(ip, varargin{:});

    plotType = ip.Results.PlotType;
    clipValues = round(ip.Results.Clip);

    im1 = checkImage(oct1);
    im2 = checkImage(oct2);
    
    if nnz(clipValues) > 0
        im1 = im1(:, 1+clipValues(1):end-clipValues(2));
        im2 = im2(:, 1+clipValues(1):end-clipValues(2));
    end

    if plotType > 0
        figure();
        imshowpair(im1, im2);
        title('Original images');
    end
    
    % Identify matching features between the images
    pts1 = detectSURFFeatures(im1);
    pts2 = detectSURFFeatures(im2);
    
    [features1, validPts1] = extractFeatures(im1, pts1);
    [features2, validPts2] = extractFeatures(im2, pts2);
    
    % Match features by their descriptors
    indexPairs = matchFeatures(features1, features2);
    
    % Retrieve locations of corresponding points for each image
    matched1 = validPts1(indexPairs(:, 1));
    matched2 = validPts2(indexPairs(:, 2));
    
    % Show putative point matches
    if plotType == 2
        figure();
        showMatchedFeatures(im1, im2, matched1, matched2);
        title('Putatively matched points (including outliers)');
    end
    
    % Estimate transformation
    [tform, inlier2, inlier1] = estimateGeometricTransform(...
        matched2, matched1, 'similarity');
    
    % Display the matching points used in the computation
    if plotType == 2
        figure();
        showMatchedFeatures(im1, im2, inlier1, inlier2);
        title('Matching points (inliers only)');
        legend('pts image 1', 'pts image 2');
    end
    
    [Theta, Scale] = solveTransform(tform);
    
    % Transform image
    outputView = imref2d(size(im1));
    newIm2 = imwarp(im2, tform, 'OutputView', outputView);
    if plotType > 0

        figure(); imshowpair(im1, newIm2, 'diff');
        title(sprintf('Difference in %s and %s alignment',...
            oct1.imageName, oct2.imageName));
        colorbar(); colormap(bone);

        figure(); hold on;
        plot(1:size(im1, 2), sum((newIm2 - im1), 1)/256,...
            'LineWidth', 1, 'Color', hex2rgb('ff4040'));
        xlim([1, size(im1, 2)]);
        xlabel('pixels'); ylabel('error');
        title('Alignment errors');
        figPos(gcf, 0.8, 0.6);
        
        fh = figure();
        imshowpair(im1, newIm2);
        title(sprintf('%s and %s alignment', oct1.imageName, oct2.imageName));
        print(fh, sprintf('%s%s_%s_alignment.png',...
            oct2.imagePath, oct1.imageName, oct2.imageName),...
            '-dpng', '-r600');
    end
    
    % Save the output
    if ip.Results.Save
        oct2.update();
        oct2.Theta = Theta; oct2.Scale = Scale;
        oct2.saveJSON();
    end
end

function im = checkImage(im)
    % CHECKIMAGE  Parse input image
    if isa(im, 'OCT')
        im = im.rawImage;
    end

    if ndims(im) == 3
        im = rgb2gray(im);
    end
end