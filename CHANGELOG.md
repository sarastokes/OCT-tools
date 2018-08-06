# CHANGELOG

### 5Aug2018
- Array format of RPE and ILM segmentation now matches Edges and Choroid. Previous code needs to account for `[y;x]` to `[x, y]` conversion.
- Added initial analysis function `choroidThickness.m`. Next step is to align the signals.

### 4Aug2018
- Changed `ExcludeEdges` function from imrect to imfreehand
- Added fast MEX function for finding edges within polygon `lib\inPolygon.c` which must be compiled. For now `ChoroidIdentification.m` tries to compile the function if `InPolygon.mexw64` isn't available, but in the future, an option to use Matlab's builtin `inpolygon` would be good.

### 3Aug2018
- First working version of RPE, ILM segmentation and choroid fits to a parabola.