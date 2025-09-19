# Nanopore Human Variation Workflow on Bianca (UPPMAX)

This repository contains configuration and notes for running the Nanopore human variation workflow on the **Bianca** cluster at **UPPMAX**.  
Bianca does not allow outbound internet, so some workflow steps (e.g. snpEff annotations) require local database access.

---

# Preparing Singularity Images

Bianca does not allow direct internet access, so Docker/Singularity images must be prepared on the **transit.uppmax.uu.se** server and then transferred via the mounted **wharf** folder that is shared between Transit and Bianca.

We can run the `download_singularity_images.sh` script on Transit to download the Singularity images and move the resulting images to Bianca via the mounted Wharf folder.

   The script will:
   - Pull the required Docker images from Docker Hub (or another registry).
   - Convert them into Singularity `.sif` images.

---

# Configuring the nextflow workflow for Bianca

## Summary

- All processes have **safe defaults** and retry logic.  
- Resource-hungry steps **scale automatically** with retries.  
- Annotation steps use the **preinstalled snpEff database**, avoiding failures from lack of internet.

## 1. Use `uppmax.config` as base

1. Ignore parameters that aren’t relevant on Bianca by setting:

   ```groovy
   schema_ignore_params = "genomes,input_paths,cluster-options,clusterOptions,project,igenomes_base,max_time,max_cpus,max_memory,save_reference,config_profile_url,config_profile_contact,config_profile_description,show_hidden_params,validate_params,monochrome_logs,min_read_support_limit,min_read_support,aws_queue,aws_image_prefix,wf,clusterOptions,project,snpeff_data"
   ```

2. Define baseline resources for all unset processes:

   ```groovy
   process {
     cpus   = 1
     memory = { 4.GB * task.attempt }
     time   = '1h'
     maxRetries = 3
     errorStrategy = { task.exitStatus in [137,140] ? 'retry' : 'finish' }

     withLabel: 'snpeff_annotation' {
       containerOptions = "--bind ${params.snpeff_data}"
     }
   }
   ```

---

## 2. Tune resources per process

- Adjust `cpus`, `memory`, and `time` in `modules/local/common.nf`.  
- Scale resources with `task.attempt` for heavier steps.  
- Check `execution/trace.txt` after runs to refine resource settings.  
- Run small/lightweight steps locally to avoid SLURM overhead. For example:

  ```groovy
  process publish_artifact {
    executor 'local'
  }
  ```

---

## 3. Handle snpEff databases (Bianca has no internet)

1. Load the in-house snpEff database module:

   ```bash
   module load bioinfo-tools Nextflow snpEff_data
   ```

   This provides a shared directory with snpEff databases (`snpEff_data`).

2. Pass the path to the workflow:

   ```bash
   nextflow run main.nf --snpeff_data $SNPEFF_DATA
   ```

3. In the `uppmax.config`, bind the database path for snpEff tasks:

   ```groovy
   process {
     withLabel: 'snpeff_annotation' {
       containerOptions = "--bind ${params.snpeff_data}"
     }
   }
   ```

4. In `modules/local/common.nf`, ensure snpEff is run with the explicit data directory and no network downloads:

   ```bash
   snpEff ... -dataDir "$SNPEFF_DATA" -noDownload ...
   ```

---

## Notes

- Always request realistic SLURM walltimes (`time` in config or `#SBATCH -t`) to avoid the 1-minute default kill.  
- Monitor resource usage with `trace.txt` and adjust process directives accordingly.  
- For debugging snpEff, make sure the DB folder (`GRCh38.p13`, etc.) exists under the bound `$SNPEFF_DATA` path.









