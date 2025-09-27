module load bioinfo-tools Nextflow snpEff_data/5.1

export NXF_HOME=/castor/project/proj_nobackup/tools/nextflow/.nextflow
export NXF_SINGULARITY_CACHEDIR=/proj/nobackup/sens2024549/human-variation-workflow/epi2me-labs/singularity/
export NXF_OFFLINE='true'
export NXF_OPTS='-Xms1g -Xmx4g'

WORKFLOW_DIR=/proj/nobackup/sens2024549/human-variation-workflow/epi2me-labs/wf-human-variation
CUSTOM_CONFIG=$WORKFLOW_DIR/uppmax.config

REF=/proj/sens2024549/reference/GRCh38.p14.genome.fa
# export BED=${DATA}demo.bed

BAM=/proj/sens2024549/nobackup/human-variation-workflow/20250919_BT-65_FF/bam/
SAMPLE_NAME=BT-65_FF

nextflow run $WORKFLOW_DIR \
 --bam $BAM \
 --ref $REF \
 --sample_name "$SAMPLE_NAME" \
 --snp \
 --sv \
 --cnv \
 --mod \
 --str \
 --phased \
 --snpeff_data $SNPEFF_DATA \
 -profile singularity \
 --threads 4 \
 --override_basecaller_cfg 'dna_r10.4.1_e8.2_400bps_sup@v5.2.0' \
 -c $CUSTOM_CONFIG \
 --project sens2024549
# -resume # disable as cleanup is enabled in config file

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
