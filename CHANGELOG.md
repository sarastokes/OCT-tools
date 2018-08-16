# CHANGELOG

### 16Aug2018
- Reload and crop functions for OCT class.

### 8Aug2018
- Extra visualization options for the `OCT` class.
- QOD export option for getting choroid ratios into Igor Pro.
- Added instructions to README

### 7Aug2018
- Working class encompassing existing functions for individual OCT images (`OCT.m`).
- General improvements to workflow while analyzing images.

### 6Aug2018
- New function `alignImages.m` to determine rotation degree necessary to align images of the same eye from different days. 
- New function `compareChoroids.m` plots a comparison of two choroid thickness ratios and optionally aligns by shifting the 2nd ratio along the x-axis.
- Updates to `choroidThickness.m`.
- Utility function `exportFigure.m` for saving images of segmentation from `ChoroidIdentification.m`.

### 5Aug2018
- Array format of RPE and ILM segmentation now matches Edges and Choroid. Previous code needs to account for `[y;x]` to `[x, y]` conversion.
- Added initial analysis function `choroidThickness.m`. Next step is to align the signals.

### 4Aug2018
- Changed `ExcludeEdges` function from imrect to imfreehand
- Added fast MEX function for finding edges within polygon `lib\inPolygon.c` which must be compiled. For now `ChoroidIdentification.m` tries to compile the function if `InPolygon.mexw64` isn't available, but in the future, an option to use Matlab's builtin `inpolygon` would be good.

### 3Aug2018
- First working version of RPE, ILM segmentation and choroid fits to a parabola.