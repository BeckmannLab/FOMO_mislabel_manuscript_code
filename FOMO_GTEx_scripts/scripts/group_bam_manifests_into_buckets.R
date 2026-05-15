library(glue)
library(dplyr)
library(tools)

manifest_dir <- "[PROJECT_DIR]/GTEx/bam_file_manifests"
fingerprint_vcf_dir <- "[PROJECT_DIR]/GTEx/fingerprint_vcfs"
groups_dir <- "[PROJECT_DIR]/GTEx/bam_file_groups"
manifest_jsons <- list.files(manifest_dir, pattern = "\\.json$")
fingerprint_vcfs <- list.files(fingerprint_vcf_dir, pattern = "\\.vcf$")
manifest_samples <- file_path_sans_ext(manifest_jsons)
## Need to do this twice to strip off the .fingerprint.vcf
fingerprint_samples <- file_path_sans_ext(file_path_sans_ext(fingerprint_vcfs))
manifest_samples <- setdiff(manifest_samples, fingerprint_samples)
n_samples <-  length(manifest_samples)
bucket_size <- 1
n_buckets <- ceiling(n_samples / bucket_size)
bucket_ids <- rep(1:n_buckets, length.out = length(manifest_samples))
manifest_buckets_df <- data.frame(sample=manifest_samples, bucket_id = bucket_ids)
for (i in bucket_ids) {
        bucket_file <- file.path("[PROJECT_DIR]/GTEx/bam_file_groups", glue("group_{i}.txt"))
        samples_in_bucket <- manifest_buckets_df %>% filter(bucket_id == i) %>% select(sample)
        write.table(samples_in_bucket, file=bucket_file, col.names=FALSE, row.names=FALSE, quote=FALSE)
}
