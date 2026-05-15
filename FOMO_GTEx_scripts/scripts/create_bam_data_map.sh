exit 1
O="[PROJECT_DIR]/GTEx/bam_data_map"

# Ran this in copied_fingerprint_vcfs 
for f in *.vcf.gz; do
	S=$(bcftools query -l "${f}")
	P=$(realpath "${f}")
	echo -e "${P}\t${S}" >> "${O}"
done

