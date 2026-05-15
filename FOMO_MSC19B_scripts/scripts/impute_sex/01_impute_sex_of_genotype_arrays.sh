cd "[PROJECT_DIR]/MSCBB/all_files/"
outfolder="imputed_sex"
mkdir $outfolder

file="[PROJECT_DIR]/MSCBB/all_files/mscic_freeze1_all_merged.hg38.vcf.gz"
output=$(basename ${file})

ml plink2
plink --vcf ${file} --const-fid 0 --make-bed --out ${outfolder}/${output}_imputedSex --impute-sex
