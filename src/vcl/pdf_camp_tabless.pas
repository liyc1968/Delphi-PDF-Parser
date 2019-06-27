unit pdf_camp_tabless;

interface
uses
digtypes,camp_japans,SysUtils,camp_cnns,camp_gbss,cmap_koreass;
const fz_empty_rect:fz_rect = ( X0:0; y0:0; x1:0;y1: 0 );

type
fontbig=record
 name:pchar;
 cmap:ppdf_cmap_s
end;
const cmap_table:array[0..149] of fontbig =
(
(name:'78-EUC-H';cmap:@cmap_78_EUC_H),
	(name:'78-EUC-V';cmap:@cmap_78_EUC_V),
	(name:'78-H';cmap:@cmap_78_H),
	(name:'78-RKSJ-H';cmap:@cmap_78_RKSJ_H),
	(name:'78-RKSJ-V';cmap:@cmap_78_RKSJ_V),
	(name:'78-V';cmap:@cmap_78_V),
	(name:'78ms-RKSJ-H';cmap:@cmap_78ms_RKSJ_H),
	(name:'78ms-RKSJ-V';cmap:@cmap_78ms_RKSJ_V),
	(name:'83pv-RKSJ-H';cmap:@cmap_83pv_RKSJ_H),
	(name:'90ms-RKSJ-H';cmap:@cmap_90ms_RKSJ_H),
	(name:'90ms-RKSJ-V';cmap:@cmap_90ms_RKSJ_V),
	(name:'90msp-RKSJ-H';cmap:@cmap_90msp_RKSJ_H),
	(name:'90msp-RKSJ-V';cmap:@cmap_90msp_RKSJ_V),
	(name:'90pv-RKSJ-H';cmap:@cmap_90pv_RKSJ_H),
	(name:'90pv-RKSJ-V';cmap:@cmap_90pv_RKSJ_V),
	(name:'Add-H';cmap:@cmap_Add_H),
	(name:'Add-RKSJ-H';cmap:@cmap_Add_RKSJ_H),
	(name:'Add-RKSJ-V';cmap:@cmap_Add_RKSJ_V),
	(name:'Add-V';cmap:@cmap_Add_V),
	(name:'Adobe-CNS1-0';cmap:@cmap_Adobe_CNS1_0),
	(name:'Adobe-CNS1-1';cmap:@cmap_Adobe_CNS1_1),
	(name:'Adobe-CNS1-2';cmap:@cmap_Adobe_CNS1_2),
	(name:'Adobe-CNS1-3';cmap:@cmap_Adobe_CNS1_3),
	(name:'Adobe-CNS1-4';cmap:@cmap_Adobe_CNS1_4),
	(name:'Adobe-CNS1-5';cmap:@cmap_Adobe_CNS1_5),
	(name:'Adobe-CNS1-6';cmap:@cmap_Adobe_CNS1_6),
	(name:'Adobe-CNS1-UCS2';cmap:@cmap_Adobe_CNS1_UCS2),
	(name:'Adobe-GB1-0';cmap:@cmap_Adobe_GB1_0),
	(name:'Adobe-GB1-1';cmap:@cmap_Adobe_GB1_1),
	(name:'Adobe-GB1-2';cmap:@cmap_Adobe_GB1_2),
	(name:'Adobe-GB1-3';cmap:@cmap_Adobe_GB1_3),
	(name:'Adobe-GB1-4';cmap:@cmap_Adobe_GB1_4),
	(name:'Adobe-GB1-5';cmap:@cmap_Adobe_GB1_5),
	(name:'Adobe-GB1-UCS2';cmap:@cmap_Adobe_GB1_UCS2),
	(name:'Adobe-Japan1-0';cmap:@cmap_Adobe_Japan1_0),
	(name:'Adobe-Japan1-1';cmap:@cmap_Adobe_Japan1_1),
	(name:'Adobe-Japan1-2';cmap:@cmap_Adobe_Japan1_2),
	(name:'Adobe-Japan1-3';cmap:@cmap_Adobe_Japan1_3),
	(name:'Adobe-Japan1-4';cmap:@cmap_Adobe_Japan1_4),
	(name:'Adobe-Japan1-5';cmap:@cmap_Adobe_Japan1_5),
	(name:'Adobe-Japan1-6';cmap:@cmap_Adobe_Japan1_6),
	(name:'Adobe-Japan1-UCS2';cmap:@cmap_Adobe_Japan1_UCS2),
	(name:'Adobe-Japan2-0';cmap:@cmap_Adobe_Japan2_0),
	(name:'Adobe-Korea1-0';cmap:@cmap_Adobe_Korea1_0),
	(name:'Adobe-Korea1-1';cmap:@cmap_Adobe_Korea1_1),
	(name:'Adobe-Korea1-2';cmap:@cmap_Adobe_Korea1_2),
	(name:'Adobe-Korea1-UCS2';cmap:@cmap_Adobe_Korea1_UCS2),
	(name:'B5-H';cmap:@cmap_B5_H),
	(name:'B5-V';cmap:@cmap_B5_V),
	(name:'B5pc-H';cmap:@cmap_B5pc_H),
	(name:'B5pc-V';cmap:@cmap_B5pc_V),
	(name:'CNS-EUC-H';cmap:@cmap_CNS_EUC_H),
	(name:'CNS-EUC-V';cmap:@cmap_CNS_EUC_V),
	(name:'CNS1-H';cmap:@cmap_CNS1_H),
	(name:'CNS1-V';cmap:@cmap_CNS1_V),
	(name:'CNS2-H';cmap:@cmap_CNS2_H),
	(name:'CNS2-V';cmap:@cmap_CNS2_V),
	(name:'ETHK-B5-H';cmap:@cmap_ETHK_B5_H),
	(name:'ETHK-B5-V';cmap:@cmap_ETHK_B5_V),
	(name:'ETen-B5-H';cmap:@cmap_ETen_B5_H),
	(name:'ETen-B5-V';cmap:@cmap_ETen_B5_V),
	(name:'ETenms-B5-H';cmap:@cmap_ETenms_B5_H),
	(name:'ETenms-B5-V';cmap:@cmap_ETenms_B5_V),
	(name:'EUC-H';cmap:@cmap_EUC_H),
	(name:'EUC-V';cmap:@cmap_EUC_V),
	(name:'Ext-H';cmap:@cmap_Ext_H),
	(name:'Ext-RKSJ-H';cmap:@cmap_Ext_RKSJ_H),
	(name:'Ext-RKSJ-V';cmap:@cmap_Ext_RKSJ_V),
	(name:'Ext-V';cmap:@cmap_Ext_V),
	(name:'GB-EUC-H';cmap:@cmap_GB_EUC_H),
	(name:'GB-EUC-V';cmap:@cmap_GB_EUC_V),
	(name:'GB-H';cmap:@cmap_GB_H),
	(name:'GB-V';cmap:@cmap_GB_V),
	(name:'GBK-EUC-H';cmap:@cmap_GBK_EUC_H),
	(name:'GBK-EUC-V';cmap:@cmap_GBK_EUC_V),
	(name:'GBK2K-H';cmap:@cmap_GBK2K_H),
	(name:'GBK2K-V';cmap:@cmap_GBK2K_V),
	(name:'GBKp-EUC-H';cmap:@cmap_GBKp_EUC_H),
	(name:'GBKp-EUC-V';cmap:@cmap_GBKp_EUC_V),
	(name:'GBT-EUC-H';cmap:@cmap_GBT_EUC_H),
	(name:'GBT-EUC-V';cmap:@cmap_GBT_EUC_V),
	(name:'GBT-H';cmap:@cmap_GBT_H),
	(name:'GBT-V';cmap:@cmap_GBT_V),
	(name:'GBTpc-EUC-H';cmap:@cmap_GBTpc_EUC_H),
	(name:'GBTpc-EUC-V';cmap:@cmap_GBTpc_EUC_V),
	(name:'GBpc-EUC-H';cmap:@cmap_GBpc_EUC_H),
	(name:'GBpc-EUC-V';cmap:@cmap_GBpc_EUC_V),
	(name:'H';cmap:@cmap_H),
	(name:'HKdla-B5-H';cmap:@cmap_HKdla_B5_H),
	(name:'HKdla-B5-V';cmap:@cmap_HKdla_B5_V),
	(name:'HKdlb-B5-H';cmap:@cmap_HKdlb_B5_H),
	(name:'HKdlb-B5-V';cmap:@cmap_HKdlb_B5_V),
	(name:'HKgccs-B5-H';cmap:@cmap_HKgccs_B5_H),
	(name:'HKgccs-B5-V';cmap:@cmap_HKgccs_B5_V),
	(name:'HKm314-B5-H';cmap:@cmap_HKm314_B5_H),
	(name:'HKm314-B5-V';cmap:@cmap_HKm314_B5_V),
	(name:'HKm471-B5-H';cmap:@cmap_HKm471_B5_H),
	(name:'HKm471-B5-V';cmap:@cmap_HKm471_B5_V),
	(name:'HKscs-B5-H';cmap:@cmap_HKscs_B5_H),
	(name:'HKscs-B5-V';cmap:@cmap_HKscs_B5_V),
	(name:'Hankaku';cmap:@cmap_Hankaku),
	(name:'Hiragana';cmap:@cmap_Hiragana),
	(name:'Hojo-EUC-H';cmap:@cmap_Hojo_EUC_H),
	(name:'Hojo-EUC-V';cmap:@cmap_Hojo_EUC_V),
	(name:'Hojo-H';cmap:@cmap_Hojo_H),
	(name:'Hojo-V';cmap:@cmap_Hojo_V),
	(name:'KSC-EUC-H';cmap:@cmap_KSC_EUC_H),
	(name:'KSC-EUC-V';cmap:@cmap_KSC_EUC_V),
	(name:'KSC-H';cmap:@cmap_KSC_H),
	(name:'KSC-Johab-H';cmap:@cmap_KSC_Johab_H),
	(name:'KSC-Johab-V';cmap:@cmap_KSC_Johab_V),
	(name:'KSC-V';cmap:@cmap_KSC_V),
	(name:'KSCms-UHC-H';cmap:@cmap_KSCms_UHC_H),
	(name:'KSCms-UHC-HW-H';cmap:@cmap_KSCms_UHC_HW_H),
	(name:'KSCms-UHC-HW-V';cmap:@cmap_KSCms_UHC_HW_V),
	(name:'KSCms-UHC-V';cmap:@cmap_KSCms_UHC_V),
	(name:'KSCpc-EUC-H';cmap:@cmap_KSCpc_EUC_H),
	(name:'KSCpc-EUC-V';cmap:@cmap_KSCpc_EUC_V),
	(name:'Katakana';cmap:@cmap_Katakana),
	(name:'NWP-H';cmap:@cmap_NWP_H),
	(name:'NWP-V';cmap:@cmap_NWP_V),
	(name:'RKSJ-H';cmap:@cmap_RKSJ_H),
	(name:'RKSJ-V';cmap:@cmap_RKSJ_V),
	(name:'Roman';cmap:@cmap_Roman),
	(name:'UniCNS-UCS2-H';cmap:@cmap_UniCNS_UCS2_H),
	(name:'UniCNS-UCS2-V';cmap:@cmap_UniCNS_UCS2_V),
	(name:'UniCNS-UTF16-H';cmap:@cmap_UniCNS_UTF16_H),
	(name:'UniCNS-UTF16-V';cmap:@cmap_UniCNS_UTF16_V),
	(name:'UniGB-UCS2-H';cmap:@cmap_UniGB_UCS2_H),
	(name:'UniGB-UCS2-V';cmap:@cmap_UniGB_UCS2_V),
	(name:'UniGB-UTF16-H';cmap:@cmap_UniGB_UTF16_H),
	(name:'UniGB-UTF16-V';cmap:@cmap_UniGB_UTF16_V),
	(name:'UniHojo-UCS2-H';cmap:@cmap_UniHojo_UCS2_H),
	(name:'UniHojo-UCS2-V';cmap:@cmap_UniHojo_UCS2_V),
	(name:'UniHojo-UTF16-H';cmap:@cmap_UniHojo_UTF16_H),
	(name:'UniHojo-UTF16-V';cmap:@cmap_UniHojo_UTF16_V),
	(name:'UniJIS-UCS2-H';cmap:@cmap_UniJIS_UCS2_H),
	(name:'UniJIS-UCS2-HW-H';cmap:@cmap_UniJIS_UCS2_HW_H),
	(name:'UniJIS-UCS2-HW-V';cmap:@cmap_UniJIS_UCS2_HW_V),
	(name:'UniJIS-UCS2-V';cmap:@cmap_UniJIS_UCS2_V),
	(name:'UniJIS-UTF16-H';cmap:@cmap_UniJIS_UTF16_H),
	(name:'UniJIS-UTF16-V';cmap:@cmap_UniJIS_UTF16_V),
	(name:'UniJISPro-UCS2-HW-V';cmap:@cmap_UniJISPro_UCS2_HW_V),
	(name:'UniJISPro-UCS2-V';cmap:@cmap_UniJISPro_UCS2_V),
	(name:'UniKS-UCS2-H';cmap:@cmap_UniKS_UCS2_H),
	(name:'UniKS-UCS2-V';cmap:@cmap_UniKS_UCS2_V),
	(name:'UniKS-UTF16-H';cmap:@cmap_UniKS_UTF16_H),
	(name:'UniKS-UTF16-V';cmap:@cmap_UniKS_UTF16_V),
	(name:'V';cmap:@cmap_V),
	(name:'WP-Symbol';cmap:@cmap_WP_Symbol)

);

function pdf_find_builtin_cmap(cmap_name:pchar):ppdf_cmap_s;

implementation

function pdf_find_builtin_cmap(cmap_name:pchar):ppdf_cmap_s;
var
	l,r,m,c:integer;
begin
  l:=0;
	r := length(cmap_table) - 1;
	while (l <= r)  do
	begin
		m := (l + r) shr 1;
		c := strcomp(cmap_name, cmap_table[m].name);


		if (c < 0) then
			r := m - 1
		else if (c > 0) then
			l := m + 1
		else
    begin
			result:= cmap_table[m].cmap;
      exit;
    end;
	end;
	result:=nil;
end;


end.
