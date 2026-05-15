project_dir="[PROJECT_DIR]/GTEx"
"${project_dir}/gen3-client" download-multiple --profile=BECKMANNN --manifest="${project_dir}/raw_manifests/file-manifest_vcf_select.json" --download-path="${project_dir}/downloaded_vcfs" --protocol=s3 --no-prompt=true

