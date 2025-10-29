module load bioinfo-tools Nextflow snpEff_data/5.1 samtools

export NXF_VER=25.04.8
export NXF_HOME=/castor/project/proj_nobackup/tools/nextflow/.nextflow
export NXF_SINGULARITY_CACHEDIR=/proj/nobackup/sens2024549/human-variation-workflow/epi2me-labs/singularity/
export NXF_OFFLINE='true'
export NXF_OPTS='-Xms1g -Xmx4g'

WORKFLOW_DIR=/proj/nobackup/sens2024549/human-variation-workflow/epi2me-labs/wf-human-variation
CUSTOM_CONFIG=$WORKFLOW_DIR/uppmax.config
detect_basecaller_tool=/proj/nobackup/sens2024549/human-variation-workflow/script/detect_basecaller.sh

REF=/proj/sens2024549/reference/GRCh38.p14.genome.fa
# export BED=${DATA}demo.bed

BAM=/proj/sens2024549/nobackup/human-variation-workflow/20250919_BT-65_FF/bam/
SAMPLE_NAME=BT-65_FF

# Optional: ensure SNPEFF_DATA is set externally
: "${SNPEFF_DATA:?SNPEFF_DATA must be set}"

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

# Capture model or fail fast with script's non-zero exit
BASECALLER_CFG="$(bash -- "$detect_basecaller_tool" "$BAM" || true)"
if [[ -z "${BASECALLER_CFG//[[:space:]]/}" ]]; then
  echo "error: failed to detect basecaller model" >&2
  exit 1
fi
echo "Detected basecaller model: $BASECALLER_CFG"

# Run workflow
cmd="nextflow run $WORKFLOW_DIR"
cmd+=" --bam $BAM"
cmd+=" --ref $REF"
cmd+=" --sample_name $SAMPLE_NAME"
cmd+=" --snp"
cmd+=" --sv"
cmd+=" --cnv"
cmd+=" --mod"
cmd+=" --str"
cmd+=" --phased"
cmd+=" --snpeff_data $SNPEFF_DATA"
cmd+=" --bam_min_coverage 0"
cmd+=" -profile singularity"
cmd+=" --threads 4"

# Toggle one of these two lines by commenting/uncommenting:
# cmd+=" --override_basecaller_cfg 'dna_r10.4.1_e8.2_400bps_sup@v5.2.0'"
# cmd+=" --override_basecaller_cfg 'dna_r10.4.1_e8.2_400bps_hac@v4.2.0'"
cmd+=" --override_basecaller_cfg '$BASECALLER_CFG'"

cmd+=" -c $CUSTOM_CONFIG"
cmd+=" --project sens2024549"
cmd+=" --enable_boost true"
# cmd+=" -resume" # disable as cleanup is enabled in config file

# Print for debug
echo "Running command:"
echo "$cmd"

# Execute
eval "$cmd"

# Clean up
if ls output/*.wf-human-alignment-report.html 1>/dev/null 2>&1 && \
   ls output/*.wf-human-snp-report.html 1>/dev/null 2>&1 && \
   ls output/*.wf-human-str-report.html 1>/dev/null 2>&1 && \
   ls output/*.wf-human-cnv-report.html 1>/dev/null 2>&1 && \
   ls output/*.wf-human-sv-report.html 1>/dev/null 2>&1; then
    echo "All five report types found — removing work folder..."
    rm -rf work
else
    echo "Not all reports exist — keeping work folder."
fi
