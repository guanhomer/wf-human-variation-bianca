nextflow.enable.dsl=2

process align_minimap2 {
  tag "${alias}"
  cpus { 2 }
  memory { 16.GB }
  time '1h'
  publishDir params.outdir, mode: 'copy'

  input:
    tuple val(alias), path(ubam), path(reference)

  output:
    tuple val(alias), path("${alias}.bam"), path("${alias}.bam.bai")

  // Align ONT uBAMs → sorted BAM + BAI
  script:
  """
  set -euo pipefail

  # (Optional) if input could contain any stale alignment tags, clear them first.
  # For clean uBAMs this is effectively a no-op but safe.
  samtools reset --no-PG -x tp,cm,s1,s2,NM,MD,AS,SA,ms,nn,ts,cg,cs,dv,de,rl ${ubam} -o - \
    | samtools fastq -@ ${params.ubam_bam2fq_threads} - \
    | minimap2 -y -t ${params.ubam_map_threads} -a -x lr:hq --cap-kalloc 100m --cap-sw-mem 50m ${reference} - \
    | samtools sort -@ ${params.ubam_sort_threads} -o ${alias}.bam

  samtools index -@ ${params.ubam_sort_threads} ${alias}.bam
  """
}

workflow {
  // 1) enumerate *.bam in input_dir
  ch_ubams = Channel
    .fromPath("${params.input_dir}/*.bam", checkIfExists: true)
    .map { bam -> tuple(bam.baseName, bam) }  // alias, path

  // 2) broadcast reference
  ch_ref = Channel.value(file(params.reference))

  // 3) run alignment
  aligned = ch_ubams.combine(ch_ref) | align_minimap2

  emit:
    aligned
}
