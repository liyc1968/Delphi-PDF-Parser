unit filt_faxdss;

interface
uses SysUtils,Math,digtypes,base_object_functions,base_error;

const
	cfd_white_initial_bits = 8;
	cfd_black_initial_bits = 7;
	cfd_2d_initial_bits = 7;
	cfd_uncompressed_initial_bits = 6; 	//* must be 6 */

	ERROR = -1;
	ZEROS = -2; //* EOL follows; possibly with more padding first */
	UNCOMPRESSED = -3 ;

	P = -4;
	H = -5;
	VR3 = 0;
	VR2 = 1;
	VR1 = 2;
	V0 = 3;
	VL1 = 4;
	VL2 = 5;
	VL3 = 6;

	STATE_NORMAL=0; //,	/* neutral state, waiting for any code */
	STATE_MAKEUP=1; //,	/* got a 1d makeup code, waiting for terminating code */
	STATE_EOL=2; //,		/* at eol, needs output buffer space */
	STATE_H1=3; //
  STATE_H2=4; //	/* in H part 1 and 2 (both makeup and terminating codes) */
	STATE_DONE=5; //		/* all done */


type
 pcfd_node_s=^cfd_node_s;
 cfd_node_s=record

	val:smallint;
  nbits:smallint;
end;
cfd_node_s_items=array of cfd_node_s;



function  fz_open_faxd(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;
implementation
uses FZ_mystreams;
const cf_white_decode:array [0..303] of cfd_node_s= ((val:256;nbits:12),(val:272;nbits:12),(val:29;nbits:8),(val:30;nbits:8),(val:45;nbits:8),(val:46;nbits:8),(val:22;nbits:7),(val:22;nbits:7),
	(val:23;nbits:7),(val:23;nbits:7),(val:47;nbits:8),(val:48;nbits:8),(val:13;nbits:6),(val:13;nbits:6),(val:13;nbits:6),(val:13;nbits:6),(val:20;nbits:7),
	(val:20;nbits:7),(val:33;nbits:8),(val:34;nbits:8),(val:35;nbits:8),(val:36;nbits:8),(val:37;nbits:8),(val:38;nbits:8),(val:19;nbits:7),(val:19;nbits:7),
	(val:31;nbits:8),(val:32;nbits:8),(val:1;nbits:6),(val:1;nbits:6),(val:1;nbits:6),(val:1;nbits:6),(val:12;nbits:6),(val:12;nbits:6),(val:12;nbits:6),(val:12;nbits:6),
	(val:53;nbits:8),(val:54;nbits:8),(val:26;nbits:7),(val:26;nbits:7),(val:39;nbits:8),(val:40;nbits:8),(val:41;nbits:8),(val:42;nbits:8),(val:43;nbits:8),
	(val:44;nbits:8),(val:21;nbits:7),(val:21;nbits:7),(val:28;nbits:7),(val:28;nbits:7),(val:61;nbits:8),(val:62;nbits:8),(val:63;nbits:8),(val:0;nbits:8),
	(val:320;nbits:8),(val:384;nbits:8),(val:10;nbits:5),(val:10;nbits:5),(val:10;nbits:5),(val:10;nbits:5),(val:10;nbits:5),(val:10;nbits:5),(val:10;nbits:5),
	(val:10;nbits:5),(val:11;nbits:5),(val:11;nbits:5),(val:11;nbits:5),(val:11;nbits:5),(val:11;nbits:5),(val:11;nbits:5),(val:11;nbits:5),(val:11;nbits:5),
	(val:27;nbits:7),(val:27;nbits:7),(val:59;nbits:8),(val:60;nbits:8),(val:288;nbits:9),(val:290;nbits:9),(val:18;nbits:7),(val:18;nbits:7),(val:24;nbits:7),
	(val:24;nbits:7),(val:49;nbits:8),(val:50;nbits:8),(val:51;nbits:8),(val:52;nbits:8),(val:25;nbits:7),(val:25;nbits:7),(val:55;nbits:8),(val:56;nbits:8),
	(val:57;nbits:8),(val:58;nbits:8),(val:192;nbits:6),(val:192;nbits:6),(val:192;nbits:6),(val:192;nbits:6),(val:1664;nbits:6),(val:1664;nbits:6),
	(val:1664;nbits:6),(val:1664;nbits:6),(val:448;nbits:8),(val:512;nbits:8),(val:292;nbits:9),(val:640;nbits:8),(val:576;nbits:8),(val:294;nbits:9),
	(val:296;nbits:9),(val:298;nbits:9),(val:300;nbits:9),(val:302;nbits:9),(val:256;nbits:7),(val:256;nbits:7),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),
	(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),(val:2;nbits:4),
	(val:2;nbits:4),(val:2;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),
	(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:128;nbits:5),(val:128;nbits:5),(val:128;nbits:5),
	(val:128;nbits:5),(val:128;nbits:5),(val:128;nbits:5),(val:128;nbits:5),(val:128;nbits:5),(val:8;nbits:5),(val:8;nbits:5),(val:8;nbits:5),(val:8;nbits:5),
	(val:8;nbits:5),(val:8;nbits:5),(val:8;nbits:5),(val:8;nbits:5),(val:9;nbits:5),(val:9;nbits:5),(val:9;nbits:5),(val:9;nbits:5),(val:9;nbits:5),(val:9;nbits:5),(val:9;nbits:5),
	(val:9;nbits:5),(val:16;nbits:6),(val:16;nbits:6),(val:16;nbits:6),(val:16;nbits:6),(val:17;nbits:6),(val:17;nbits:6),(val:17;nbits:6),(val:17;nbits:6),
	(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),
	(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:4;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),
	(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),
	(val:14;nbits:6),(val:14;nbits:6),(val:14;nbits:6),(val:14;nbits:6),(val:15;nbits:6),(val:15;nbits:6),(val:15;nbits:6),(val:15;nbits:6),(val:64;nbits:5),
	(val:64;nbits:5),(val:64;nbits:5),(val:64;nbits:5),(val:64;nbits:5),(val:64;nbits:5),(val:64;nbits:5),(val:64;nbits:5),(val:6;nbits:4),(val:6;nbits:4),
	(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),
	(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),
	(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:7;nbits:4),(val:-2;nbits:3),(val:-2;nbits:3),
	(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),
	(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-3;nbits:4),(val:1792;nbits:3),(val:1792;nbits:3),(val:1984;nbits:4),
	(val:2048;nbits:4),(val:2112;nbits:4),(val:2176;nbits:4),(val:2240;nbits:4),(val:2304;nbits:4),(val:1856;nbits:3),(val:1856;nbits:3),
	(val:1920;nbits:3),(val:1920;nbits:3),(val:2368;nbits:4),(val:2432;nbits:4),(val:2496;nbits:4),(val:2560;nbits:4),(val:1472;nbits:1),
	(val:1536;nbits:1),(val:1600;nbits:1),(val:1728;nbits:1),(val:704;nbits:1),(val:768;nbits:1),(val:832;nbits:1),(val:896;nbits:1),
	(val:960;nbits:1),(val:1024;nbits:1),(val:1088;nbits:1),(val:1152;nbits:1),(val:1216;nbits:1),(val:1280;nbits:1),(val:1344;nbits:1),
	(val:1408;nbits:1)
  );

const cf_black_decode:array [0..319] of cfd_node_s=(
  (val:128;nbits:12),(val:160;nbits:13),(val:224;nbits:12),(val:256;nbits:12),(val:10;nbits:7),(val:11;nbits:7),(val:288;nbits:12),(val:12;nbits:7),
	(val:9;nbits:6),(val:9;nbits:6),(val:8;nbits:6),(val:8;nbits:6),(val:7;nbits:5),(val:7;nbits:5),(val:7;nbits:5),(val:7;nbits:5),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),
	(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:6;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),
	(val:5;nbits:4),(val:5;nbits:4),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),
	(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:1;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),
	(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),
	(val:4;nbits:3),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),
	(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),
	(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),(val:3;nbits:2),
	(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),
	(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),
	(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),(val:2;nbits:2),
	(val:-2;nbits:4),(val:-2;nbits:4),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),
	(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-3;nbits:5),(val:1792;nbits:4),
	(val:1792;nbits:4),(val:1984;nbits:5),(val:2048;nbits:5),(val:2112;nbits:5),(val:2176;nbits:5),(val:2240;nbits:5),(val:2304;nbits:5),
	(val:1856;nbits:4),(val:1856;nbits:4),(val:1920;nbits:4),(val:1920;nbits:4),(val:2368;nbits:5),(val:2432;nbits:5),(val:2496;nbits:5),
	(val:2560;nbits:5),(val:18;nbits:3),(val:18;nbits:3),(val:18;nbits:3),(val:18;nbits:3),(val:18;nbits:3),(val:18;nbits:3),(val:18;nbits:3),(val:18;nbits:3),
	(val:52;nbits:5),(val:52;nbits:5),(val:640;nbits:6),(val:704;nbits:6),(val:768;nbits:6),(val:832;nbits:6),(val:55;nbits:5),(val:55;nbits:5),
	(val:56;nbits:5),(val:56;nbits:5),(val:1280;nbits:6),(val:1344;nbits:6),(val:1408;nbits:6),(val:1472;nbits:6),(val:59;nbits:5),(val:59;nbits:5),
	(val:60;nbits:5),(val:60;nbits:5),(val:1536;nbits:6),(val:1600;nbits:6),(val:24;nbits:4),(val:24;nbits:4),(val:24;nbits:4),(val:24;nbits:4),
	(val:25;nbits:4),(val:25;nbits:4),(val:25;nbits:4),(val:25;nbits:4),(val:1664;nbits:6),(val:1728;nbits:6),(val:320;nbits:5),(val:320;nbits:5),
	(val:384;nbits:5),(val:384;nbits:5),(val:448;nbits:5),(val:448;nbits:5),(val:512;nbits:6),(val:576;nbits:6),(val:53;nbits:5),(val:53;nbits:5),
	(val:54;nbits:5),(val:54;nbits:5),(val:896;nbits:6),(val:960;nbits:6),(val:1024;nbits:6),(val:1088;nbits:6),(val:1152;nbits:6),(val:1216;nbits:6),
	(val:64;nbits:3),(val:64;nbits:3),(val:64;nbits:3),(val:64;nbits:3),(val:64;nbits:3),(val:64;nbits:3),(val:64;nbits:3),(val:64;nbits:3),(val:13;nbits:1),
	(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),
	(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:13;nbits:1),(val:23;nbits:4),(val:23;nbits:4),(val:50;nbits:5),
	(val:51;nbits:5),(val:44;nbits:5),(val:45;nbits:5),(val:46;nbits:5),(val:47;nbits:5),(val:57;nbits:5),(val:58;nbits:5),(val:61;nbits:5),(val:256;nbits:5),
	(val:16;nbits:3),(val:16;nbits:3),(val:16;nbits:3),(val:16;nbits:3),(val:17;nbits:3),(val:17;nbits:3),(val:17;nbits:3),(val:17;nbits:3),(val:48;nbits:5),
	(val:49;nbits:5),(val:62;nbits:5),(val:63;nbits:5),(val:30;nbits:5),(val:31;nbits:5),(val:32;nbits:5),(val:33;nbits:5),(val:40;nbits:5),(val:41;nbits:5),
	(val:22;nbits:4),(val:22;nbits:4),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),
	(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),(val:14;nbits:1),
	(val:15;nbits:2),(val:15;nbits:2),(val:15;nbits:2),(val:15;nbits:2),(val:15;nbits:2),(val:15;nbits:2),(val:15;nbits:2),(val:15;nbits:2),(val:128;nbits:5),
	(val:192;nbits:5),(val:26;nbits:5),(val:27;nbits:5),(val:28;nbits:5),(val:29;nbits:5),(val:19;nbits:4),(val:19;nbits:4),(val:20;nbits:4),(val:20;nbits:4),
	(val:34;nbits:5),(val:35;nbits:5),(val:36;nbits:5),(val:37;nbits:5),(val:38;nbits:5),(val:39;nbits:5),(val:21;nbits:4),(val:21;nbits:4),(val:42;nbits:5),
	(val:43;nbits:5),(val:0;nbits:3),(val:0;nbits:3),(val:0;nbits:3),(val:0;nbits:3)
  );


const cf_2d_decode:array [0..151] of cfd_node_s=(

  (val:128;nbits:11),(val:144;nbits:10),(val:6;nbits:7),(val:0;nbits:7),(val:5;nbits:6),(val:5;nbits:6),(val:1;nbits:6),(val:1;nbits:6),(val:-4;nbits:4),
	(val:-4;nbits:4),(val:-4;nbits:4),(val:-4;nbits:4),(val:-4;nbits:4),(val:-4;nbits:4),(val:-4;nbits:4),(val:-4;nbits:4),(val:-5;nbits:3),(val:-5;nbits:3),
	(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),
	(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:-5;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),
	(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),(val:4;nbits:3),
	(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),
	(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),
	(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),
	(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),
	(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),
	(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),
	(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),
	(val:3;nbits:1),(val:3;nbits:1),(val:3;nbits:1),(val:-2;nbits:4),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),
	(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),
	(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-1;nbits:0),(val:-3;nbits:3)
  );
const cf_uncompressed_decode:array [0..127] of cfd_node_s=(
  	(val:64;nbits:12),(val:5;nbits:6),(val:4;nbits:5),(val:4;nbits:5),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:3;nbits:4),(val:2;nbits:3),(val:2;nbits:3),
	(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),
	(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),
	(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),
	(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),
	(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),(val:0;nbits:1),
	(val:-1;nbits:0),(val:-1;nbits:0),(val:8;nbits:6),(val:9;nbits:6),(val:6;nbits:5),(val:6;nbits:5),(val:7;nbits:5),(val:7;nbits:5),(val:4;nbits:4),(val:4;nbits:4),
	(val:4;nbits:4),(val:4;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:5;nbits:4),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),
	(val:2;nbits:3),(val:2;nbits:3),(val:2;nbits:3),(val:3;nbits:3),(val:3;nbits:3),(val:3;nbits:3),(val:3;nbits:3),(val:3;nbits:3),(val:3;nbits:3),(val:3;nbits:3),(val:3;nbits:3),
	(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),
	(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:0;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),
	(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2),(val:1;nbits:2)
);
function  getbit(buf:pbyte; x:integer):integer;
begin
	result:= ( byte_items(buf)[x shr 3] shr ( 7 - (x and 7) ) ) and 1;
end;
function find_changing(line:pbyte; x, w:integer):integer;
var
	a, b:integer;
begin
	if (line=nil) then
  begin
		result:= w;
    exit;
  end;

	if (x = -1) then
	begin
		a := 0;
		x := 0;
	end
	else
	begin
		a := getbit(line, x);
		x:=x+1;
	end;

	while (x < w) do
	begin
		b := getbit(line, x);
		if (a <> b)  then
			break;
   	x:=x+1;
	end;

	result:= x;
end;

function find_changing_color(line:pbyte;  x, w, color:integer):integer;
begin
	if (line=nil) then
  begin
		result:=w;
    exit;
  end;
	x := find_changing(line, x, w);

	if (x < w) and (getbit(line, x) <> color) then
		x := find_changing(line, x, w);

	result:= x;
end;

const lm:array[0..7] of byte = (
	$FF, $7F, $3F, $1F, $0F, $07, $03, $01
);

const rm:array[0..7] of byte = (
	$00, $80, $C0, $E0, $F0, $F8, $FC, $FE
);

procedure setbits(line:pbyte;  x0, x1:integer);
var
	 a0, a1, b0, b1, a:integer;
begin
	a0 := x0 shr 3;
	a1 := x1 shr 3;

	b0 := x0 and 7;
	b1 := x1 and 7;

	if (a0 = a1) then
	begin
		if (b1<>0) then
			byte_items(line)[a0] :=byte_items(line)[a0] or ( lm[b0] and rm[b1]);
	end
	else
	begin
		byte_items(line)[a0] :=byte_items(line)[a0] or lm[b0];
		for a := a0 + 1 to a1-1 do
			byte_items(line)[a] := $FF;
		if (b1<>0) then
			byte_items(line)[a1] :=	byte_items(line)[a1] or rm[b1];
	end;
end;

type
pfz_faxd_s=^fz_faxd_s;
fz_faxd_s=record

  chain:pfz_stream_s;
  k:integer;
	end_of_line:integer;
	encoded_byte_align:integer;
	columns:integer;
	rows:integer;
	end_of_block:integer;
	black_is_1:integer;

	stride:integer;
	ridx:integer;

	bidx:integer;
	word:dword;

	stage:integer;

	a, c, dim, eolc:integer;
	ref:pbyte;
	dst:pbyte;
	rp, wp:pbyte;
end;


procedure eat_bits(fax:pfz_faxd_s; nbits:integer);
begin
	fax^.word :=fax^.word shl nbits;
	fax^.bidx :=fax^.bidx+ nbits;
end;

function fill_bits(fax:pfz_faxd_s):integer;
var
c:integer;
begin
	while (fax^.bidx >= 8)  do
	begin
		c := fz_read_byte(fax^.chain);
		if (c = eEOF) then
    begin
			result:= eEOF;
      exit;
    end;
		fax^.bidx :=fax^.bidx- 8;
		fax^.word :=fax^.word or ( c shl fax^.bidx);
	end;
	result:= 0;
end;

function get_code(fax:pfz_faxd_s; const table :pcfd_node_s; initialbits:integer):integer;
var
	word:dword;
	tidx:integer;
	val :integer;
	nbits:integer;
  mask:integer;
begin
	word := fax^.word;
	tidx := word shr (32 - initialbits);
	val := cfd_node_s_items(table)[tidx].val;
	nbits := cfd_node_s_items(table)[tidx].nbits;

	if (nbits > initialbits)  then
	begin
		mask := (1 shl (32 - initialbits)) - 1;
		tidx := val + ((word and mask) shr (32 - nbits));
		val := cfd_node_s_items(table)[tidx].val;
		nbits := initialbits + cfd_node_s_items(table)[tidx].nbits;
	end;

	eat_bits(fax, nbits);

	result:= val;
end;

//* decode one 1d code */
function dec1d(fax:pfz_faxd_s):integer;
var
	code:integer;
begin
	if (fax^.a = -1) then
		fax^.a := 0;

	if (fax^.c<>0) then
		code := get_code(fax, @cf_black_decode, cfd_black_initial_bits)
	else
		code := get_code(fax, @cf_white_decode, cfd_white_initial_bits);

	if (code = UNCOMPRESSED) then
  begin
	 result:= fz_throw('uncompressed data in faxd');
   exit;
  end;

	if (code < 0) then
  begin
		result:=fz_throw('negative code in 1d faxd');
    exit;
  end;

	if (fax^.a + code > fax^.columns) then
  begin
		result:= fz_throw('overflow in 1d faxd');
    exit;
  end;

	if (fax^.c<>0) then
		setbits(fax^.dst, fax^.a, fax^.a + code);

	fax^.a:=fax^.a+ code;

	if (code < 64) then
	begin
		 if fax^.c=0 then
			fax^.c := 1
      else
      fax^.c := 0;
		fax^.stage := STATE_NORMAL;
	end
	else
		fax^.stage := STATE_MAKEUP;
  result:=1;
	//return fz_okay;
end;

//* decode one 2d code */
function  dec2d(fax:pfz_faxd_s):integer;
var
	code, b1, b2,cc:integer;
begin

	if (fax^.stage = STATE_H1) or  (fax^.stage = STATE_H2) then
	begin
		if (fax^.a = -1) then
			fax^.a := 0;

		if (fax^.c<>0) then
			code := get_code(fax, @cf_black_decode, cfd_black_initial_bits)
		else
			code := get_code(fax, @cf_white_decode, cfd_white_initial_bits);

		if (code = UNCOMPRESSED) then
    begin
		 result:= fz_throw('uncompressed data in faxd');
      exit;
    end;

		if (code < 0)  then
    begin
			result:= fz_throw('negative code in 2d faxd');
      exit;
    end;

		if (fax^.a + code > fax^.columns) then
    begin
     fz_throw('ppppp:%d',[ppppppppppp]);
		 result:= fz_throw('overflow in 2d faxd');
     exit;
    end;

		if (fax^.c<>0) then
			setbits(fax^.dst, fax^.a, fax^.a + code);

		fax^.a :=fax^.a+ code;

		if (code < 64) then
		begin
      if fax^.c=0 then
			fax^.c := 1
      else
      fax^.c := 0;
			if (fax^.stage = STATE_H1) then
				fax^.stage := STATE_H2
			else if (fax^.stage = STATE_H2) then
				fax^.stage := STATE_NORMAL;
		end;

    result:=1;
    exit;
		//return fz_okay;
	end;

	code := get_code(fax, @cf_2d_decode, cfd_2d_initial_bits);

	case (code) of
	H:
		fax^.stage := STATE_H1;


	P:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 >= fax^.columns) then
			b2 := fax^.columns
		else
			b2 := find_changing(fax^.ref, b1, fax^.columns);
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b2);
		fax^.a := b2;
		end;

	V0:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	VR1:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := 1 + find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 >= fax^.columns) then b1 := fax^.columns;
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	 VR2:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := 2 + find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 >= fax^.columns) then b1 := fax^.columns;
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	VR3:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := 3 + find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 >= fax^.columns) then b1 := fax^.columns;
		if (fax^.c<>0) then  setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	VL1:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := -1 + find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 < 0) then b1 := 0;
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	VL2:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := -2 + find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 < 0) then b1 := 0;
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	VL3:
    begin
    if  fax^.c=1 then
    cc:=0
    else
    cc:=1;
		b1 := -3 + find_changing_color(fax^.ref, fax^.a, fax^.columns, cc);
		if (b1 < 0) then b1 := 0;
		if (fax^.c<>0) then setbits(fax^.dst, fax^.a, b1);
		fax^.a := b1;
		fax^.c := cc;
		end;

	UNCOMPRESSED:
  begin
		//return fz_throw("uncompressed data in faxd");
    result:=fz_throw('uncompressed data in faxd');
    exit;
  end;

	ERROR:
  begin
		result:= fz_throw('invalid code in 2d faxd');
    exit;
  end;

	else
  begin
		result:= fz_throw('invalid code in 2d faxd (%d)', [code]);
    exit;
  end;
	end;
 	result:= 0;
end;

function read_faxd(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	fax:pfz_faxd_s;
	p,ep:pbyte;
	tmp:pbyte;
  cc:integer;
	error:integer;

  label eol,rtc,loop;
begin
  fax := stm^.state;
	p := buf;
	ep:= buf;
  inc(ep, + len);

	if (fax^.stage = STATE_DONE) then
  begin
		//return 0;
    result:=0;
    exit;
  end;

	if (fax^.stage = STATE_EOL) then
		goto eol;

loop:

	if (fill_bits(fax)<>0) then
	begin
		if (fax^.bidx > 31) then
		begin
			if (fax^.a > 0) then
				goto eol;
			goto rtc;
		end;
	end;

	if ((fax^.word shr (32 - 12)) = 0) then
	begin
		eat_bits(fax, 1);
		goto loop;
	end;

	if ((fax^.word shr (32 - 12)) = 1) then
	begin
		eat_bits(fax, 12);
		fax^.eolc:=fax^.eolc+1;

		if (fax^.k > 0)  then
		begin
			if (fax^.a = -1) then
				fax^.a := 0;
			if ((fax^.word shr (32 - 1)) = 1) then
				fax^.dim := 1
			else
				fax^.dim := 2;
			eat_bits(fax, 1);
		end;
	end
	else if (fax^.k > 0) and (fax^.a = -1) then
	begin
		fax^.a := 0;
		if ((fax^.word shr (32 - 1)) = 1) then
			fax^.dim := 1
		else
			fax^.dim := 2;
		eat_bits(fax, 1);
	end
	else if (fax^.dim = 1) then
	begin
		fax^.eolc := 0;
		error := dec1d(fax);
		if (error<0)   then
    begin
		 result:= fz_rethrow(error, 'cannot decode 1d code');
     exit;
    end;
	end
	else if (fax^.dim = 2) then
	begin
		fax^.eolc := 0;
		error := dec2d(fax);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot decode 2d code');
      exit;
    end;
	end;

	//* no eol check after makeup codes nor in the middle of an H code */
	if ((fax^.stage = STATE_MAKEUP) or (fax^.stage = STATE_H1) or (fax^.stage = STATE_H2)) then
		goto loop;

	//* check for eol conditions */
	if (fax^.eolc<>0) or (fax^.a >= fax^.columns) then
	begin
		if (fax^.a > 0) then
			goto eol;
    if fax^.k < 0 then
    cc:=2
    else
    cc:=6;
		if (fax^.eolc = cc) then
			goto rtc;
	end;

	goto loop;

eol:
	fax^.stage := STATE_EOL;

	if (fax^.black_is_1<>0)  then
	begin
		while (cardinal(fax^.rp) < cardinal(fax^.wp)) and (cardinal(p) < cardinal(ep)) do
    begin
      p^:=fax^.rp^;
      inc(p);
      inc(fax^.rp);
    end;
	end
	else
	begin
		while (cardinal(fax^.rp) < cardinal(fax^.wp)) and (cardinal(p) < cardinal(ep)) do
    begin
      p^:=fax^.rp^ Xor $ff;
       inc(p);
      inc(fax^.rp);
    end;
	end;

	if (cardinal(fax^.rp) < cardinal(fax^.wp))  then
  begin
		result:=cardinal(p) - cardinal(buf);
    exit;
  end;
	tmp := fax^.ref;
	fax^.ref := fax^.dst;
	fax^.dst := tmp;
	fillchar(fax^.dst^, fax^.stride, 0);

	fax^.rp := fax^.dst;
	fax^.wp := fax^.dst;
  inc(fax^.wp, + fax^.stride);

	fax^.stage := STATE_NORMAL;
	fax^.c := 0;
	fax^.a := -1;
	fax^.ridx:=fax^.ridx+1;

	if (fax^.end_of_block=0) and (fax^.rows<>0)   then
	begin
		if (fax^.ridx >= fax^.rows) then
			goto rtc;
	end;

	//* we have not read dim from eol, make a guess */
	if ((fax^.k > 0) and (fax^.eolc=0) and (fax^.a = -1))   then
	begin
		if (fax^.ridx mod fax^.k = 0) then
			fax^.dim := 1
		else
			fax^.dim := 2;
  end;

	//* if end_of_line & encoded_byte_align, EOLs are *not* optional */
	if (fax^.encoded_byte_align<>0)  then
	begin
		if (fax^.end_of_line<>0) then
			eat_bits(fax, (12 - fax^.bidx) and 7)
		else
			eat_bits(fax, (8 - fax^.bidx) and 7);
	end;

	//* no more space in output, don't decode the next row yet */
	if cardinal(p)= (cardinal(buf) + len) then
  begin
		//return p - buf;
    result:=cardinal(p)-cardinal(buf);
    exit;
  end;

	goto loop;

rtc:
	fax^.stage := STATE_DONE;

	result:=cardinal(p)-cardinal(buf);
end;

procedure close_faxd(stm:pfz_stream_s);
var
	fax:pfz_faxd_s;
	i:integer;
begin
  fax := stm^.state;
	//* if we read any extra bytes, try to put them back */
	i := (32 - fax^.bidx) div 8;
	while (i<>0) do
  begin
		fz_unread_byte(fax^.chain);
    i:=i-1;
  end;

	fz_close(fax^.chain);
	fz_free(fax^.ref);
	fz_free(fax^.dst);
	fz_free(fax);
end;

function fz_open_faxd(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;
var
	fax:pfz_faxd_s;
	obj:pfz_obj_s;
begin
	fax := fz_malloc(sizeof(fz_faxd_s));
	fax^.chain := chain;

	fax^.ref := nil;
	fax^.dst := nil;

	fax^.k := 0;
	fax^.end_of_line := 0;
	fax^.encoded_byte_align := 0;
	fax^.columns := 1728;
	fax^.rows := 0;
	fax^.end_of_block := 1;
	fax^.black_is_1 := 0;

	obj := fz_dict_gets(params, 'K');
	if (obj<>nil) then fax^.k := fz_to_int(obj);

	obj := fz_dict_gets(params, 'EndOfLine');
	if (obj<>nil) then fax^.end_of_line := fz_to_bool(obj);

	obj := fz_dict_gets(params, 'EncodedByteAlign');
	if (obj<>nil) then fax^.encoded_byte_align := fz_to_bool(obj);

	obj := fz_dict_gets(params, 'Columns');
	if (obj<>nil) then fax^.columns := fz_to_int(obj);

	obj := fz_dict_gets(params, 'Rows');
	if (obj<>nil) then fax^.rows := fz_to_int(obj);

	obj := fz_dict_gets(params, 'EndOfBlock');
	if (obj<>nil) then fax^.end_of_block := fz_to_bool(obj);

	obj := fz_dict_gets(params, 'BlackIs1');
	if (obj<>nil) then fax^.black_is_1 := fz_to_bool(obj);

	fax^.stride := ((fax^.columns - 1) shr 3) + 1;
	fax^.ridx := 0;
	fax^.bidx := 32;
	fax^.word := 0;

	fax^.stage := STATE_NORMAL;
	fax^.a := -1;
	fax^.c := 0;
  if fax^.k < 0 then
     fax^.dim :=2
     else
     fax^.dim :=1;

	fax^.eolc := 0;

	fax^.ref := fz_malloc(fax^.stride);
	fax^.dst := fz_malloc(fax^.stride);
	fax^.rp := fax^.dst;
	fax^.wp := fax^.dst;
  inc(fax^.wp, + fax^.stride);

	fillchar(fax^.ref^, fax^.stride, 0);
	fillchar(fax^.dst^, fax^.stride, 0);
  ppppppppppp:=0;
	result:= fz_new_stream(fax, read_faxd, close_faxd);
end;




end.
