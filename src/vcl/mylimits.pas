unit mylimits;

interface
uses  SysUtils;
 const
 INT_MAX =2147483647;
 MAX_KEY_LEN = 48;
 FZ_BLEND_NORMAL=0;
	FZ_BLEND_MULTIPLY=1;
	FZ_BLEND_SCREEN=2;
	FZ_BLEND_OVERLAY=3;
	FZ_BLEND_DARKEN=4;
	FZ_BLEND_LIGHTEN=5;
	FZ_BLEND_COLOR_DODGE=6;
	FZ_BLEND_COLOR_BURN=7;
	FZ_BLEND_HARD_LIGHT=8;
	FZ_BLEND_SOFT_LIGHT=9;
	FZ_BLEND_DIFFERENCE=10;
	FZ_BLEND_EXCLUSION=11;

	//* PDF 1.4 -- standard non-separable */
	FZ_BLEND_HUE=12;
	FZ_BLEND_SATURATION=13;
	FZ_BLEND_COLOR=14;
	FZ_BLEND_LUMINOSITY=15;

	//* For packing purposes */

 	FZ_BLEND_MODEMASK = 15;
	FZ_BLEND_ISOLATED = 16;
	FZ_BLEND_KNOCKOUT = 32;
  MAX_DEPTH=8 ;

  BUTT = 0;
  ROUND = 1;
  SQUARE = 2;
  TRIANGLE = 3;
  MITER = 0;
  BEVEL = 2;
  HSUBPIX =5.0;
  VSUBPIX =5.0;


 INN=0;
 OUTt=1;
 ENTER=2;
 LEAVE=3;

 

implementation

end.


 