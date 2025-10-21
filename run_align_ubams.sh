# module load bioinfo-tools Nextflow snpEff_data/5.1
# cd /proj/sens2024549/nobackup/human-variation-workflow/BT_126_FF

# Nextflow settings
export NXF_HOME=/castor/project/proj_nobackup/tools/nextflow/.nextflow
export NXF_SINGULARITY_CACHEDIR=/proj/nobackup/sens2024549/human-variation-workflow/epi2me-labs/singularity
export NXF_OFFLINE=true
export NXF_OPTS='-Xms1g -Xmx4g'

# Workflow paths
WORKFLOW_DIR=/proj/nobackup/sens2024549/human-variation-workflow/epi2me-labs/wf-human-variation
CUSTOM_CONFIG=$WORKFLOW_DIR/uppmax_ryan.config

# Sample name from current directory (parent dir of current working dir)
SAMPLE_NAME=$(basename "$(pwd)")

# Input/output references
BAM=/proj/sens2024549/nobackup/human-variation-workflow/${SAMPLE_NAME}/bam
REF=/proj/sens2024549/reference/GRCh38.p14.genome.fa

# Move 0 byte bam files to bam/zero_byte_bam/
# Collect zero-byte BAMs (handles spaces/newlines)
zero_bams=()
while IFS= read -r -d '' f; do
  zero_bams+=("$f")
done < <(find "$BAM" -type f -name '*.bam' -size 0c -print0 2>/dev/null)

if (( ${#zero_bams[@]} > 0 )); then
  echo "Found ${#zero_bams[@]} zero-byte BAM file(s) in $BAM"
  dest="$BAM/zero_byte_bam"
  mkdir -p -- "$dest"
  
  for f in "${zero_bams[@]}"; do
    echo "Moving: $f -> $dest"
    mv -- "$f" "$dest" || { echo "Failed to move: $f" >&2; }
  done
fi

nextflow run $WORKFLOW_DIR/align_ubams.nf \
  -profile singularity \
  --input_dir $BAM \
  --reference $REF \
  --ubam_map_threads 1 --ubam_sort_threads 1 --ubam_bam2fq_threads 1 \
  --outdir bam_aligned \
  -c $CUSTOM_CONFIG \
  --snpeff_data $SNPEFF_DATA "" \
  --project sens2024549 \
  -resume
