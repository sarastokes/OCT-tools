function [Angle, Scale] = solveTransform(tform)
	% SOLVETRANFORM
	%
	% Description:
	%	[Angle, Scale] = solveTransform(tform)
	%
	% Input:
	%	tform 		affine2d or inverted 3x3 transform matrix
	%
	% Output:
	%	Scale 		scale transformation
	% 	Theta 		angle rotation
	%
	% History:
	%	3Jan2018 - SSP
	% ------------------------------------------------------------------
	if isa(tform, 'affine2d')
		T = tform.invert.T;
	else
		assert(size(tform) == [3 3], 'Input must by 3x3')
		T = tform;
	end

	a = T(2, 1);
	b = T(1, 1);

	Scale = sqrt(a*a + b*b);
	Theta = -1 * (atan2(a, b) * 180/pi);

	fprintf('Scale=%.2g\nAngle=%.2g\n', Scale, Angle);
end