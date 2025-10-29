#!/usr/bin/env bash
set -euo pipefail

usage() { echo "usage: $(basename "$0") <bam_dir>" >&2; exit 2; }

[[ $# -eq 1 ]] || usage
BAM_DIR="$1"
[[ -d "$BAM_DIR" ]] || { echo "ERROR: '$BAM_DIR' is not a directory." >&2; exit 2; }

# Find the first BAM (non-recursive), lexicographic order for determinism
first_bam="$(find "$BAM_DIR" -maxdepth 1 -type f -name '*.bam' | LC_ALL=C sort | head -n1 || true)"
[[ -n "${first_bam}" ]] || { echo "ERROR: No BAM files found in '$BAM_DIR'." >&2; exit 1; }

# Extract basecall_model(s) from @RG DS using grep -P if available, else awk fallback
if grep -Pq '' <<<"" 2>/dev/null; then
  mapfile -t models < <(samtools view -H "$first_bam" \
    | grep -oP '(?<=basecall_model=)\S+' \
    | sort -u)
else
  mapfile -t models < <(samtools view -H "$first_bam" \
    | awk '{while(match($0,/basecall_model=([^ \t]+)/,m)){print m[1]; sub(/basecall_model=[^ \t]+/,"")}}' \
    | sort -u)
fi

(( ${#models[@]} > 0 )) || { echo "ERROR: No 'basecall_model=' found in @RG DS of '$first_bam'." >&2; exit 1; }
(( ${#models[@]} == 1 )) || { echo "ERROR: Multiple basecall models detected: ${models[*]}" >&2; exit 1; }
model="${models[0]}"

# Allow-list
case "$model" in
  "dna_r10.4.1_e8.2_400bps_sup@v5.2.0"|"dna_r10.4.1_e8.2_400bps_hac@v4.2.0")
    printf '%s\n' "$model"   # stdout contains ONLY the model on success
    ;;
  *)
    echo "ERROR: Unsupported basecall_model '$model'. Allowed: dna_r10.4.1_e8.2_400bps_sup@v5.2.0, dna_r10.4.1_e8.2_400bps_hac@v4.2.0" >&2
    exit 1
    ;;
esac
