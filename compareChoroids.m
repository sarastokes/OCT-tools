function shiftFac = compareChoroids(ratio1, ratio2, xShift)
	% COMPARECHOROIDS
	%
	% Description:
	%	Compare the choroid thickness ratios of two images, plot results
	%
	% Syntax:
	%	shiftFac = compareChoroids(ratio1, ratio2, xShift)
	% 
	% Inputs:
	%	ratio1 		choroid ratio of image 1 (before)
	%	ratio2 		choroid ratio of image 2 (after)
	% Optional inputs:
	% 	xShift 		align ratio2 with x-axis shift, (default = false)
	% Output:
	%	shiftFac 	scalar for x-axis shift
	%
	% History:
	%	6Aug2018 - SSP
	% --------------------------------------------------------------------

	if nargin < 3
		xShift = false;
	else
		assert(islogical(xShift), 'Set xShift to true/false');
	end

	figure('Name', 'Choroid Thickness Comparison');
	hold on;
	plot([0, max([numel(ratio1), numel(ratio2)])], [1 1],...
		'--', 'Color', [0.5, 0.5, 0.5]);
	plot(ratio1, '.k', 'MarkerSize', 3, 'Tag', 'Ratio1');
	p1 = plot(smooth(ratio1, 10), 'b', 'LineWidth', 1, 'Tag', 'Ratio1');
	plot(ratio2, '.k', 'MarkerSize', 3, 'Tag', 'Ratio2');
	p2 = plot(smooth(ratio2, 10), 'r', 'LineWidth', 1, 'Tag', 'Ratio2');

	grid on; axis tight;
	set(gca, 'Box', 'off', 'YLim', [0, 2]);
	xlabel('X-axis (pixels)');
	ylabel('choroid to retina thickness ratio');
	title('Choroid Thickness');
	legend([p1, p2], {'Before', 'After'});

	if xShift
		[~, ind1] = max(smooth(ratio1, 15));
		[~, ind2] = max(smooth(ratio2, 15));

		shiftFac = ind2 - ind1;
		fprintf('Shifting by %.3f\n', shiftFac);
		h = findall(gcf, 'Tag', 'Ratio2');
		for i = 1:numel(h)
			set(h(i), 'XData', get(h(i), 'XData') - shiftFac);
		end
	else
		shiftFac = [];
	end
end