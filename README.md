# Nanopore Human Variation Workflow (v2.7.2) on Bianca (UPPMAX)

This repository contains the preparation and configuration files needed to run the Nanopore human variation workflow on the **Bianca** cluster at **UPPMAX**.

It includes:

- A script `download_singularity_images.sh` to download and prepare the required Singularity images.

- A modified `uppmax.config` for resource settings and SLURM integration.

- An example script `run_workflow.sh` for launching the workflow with appropriate parameters.

- Multi-thread bam merge to speed up from 6 hours to 3 hours.

Because Bianca does not allow outbound internet access, this configuration also handles steps that would otherwise attempt online downloads (e.g. snpEff annotations), by pointing the workflow to a local preinstalled snpEff database.

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
- **Automatic cleanup cache** prevents excessive disk usage.
- Annotation steps use the **preinstalled snpEff database**, avoiding failures from lack of internet.

## 1. Use `uppmax.config` as base

1. Ignore parameters that aren’t relevant on Bianca by setting:

   ```groovy
   schema_ignore_params = "genomes,input_paths,cluster-options,clusterOptions,project,igenomes_base,max_time,max_cpus,max_memory,save_reference,config_profile_url,config_profile_contact,config_profile_description,show_hidden_params,validate_params,monochrome_logs,min_read_support_limit,min_read_support,aws_queue,aws_image_prefix,wf,snpeff_data"
   ```

2. Define baseline resources for all unset processes:

   ```groovy
   process {
     cpus   = 1
     memory = { 4.GB * task.attempt }
     time   = '1h'
     maxRetries = 3
     errorStrategy = { task.exitStatus in [137,140] ? 'retry' : 'finish' }
   }
   ```

3. Enable automatic cleanup with nf-boost to prevent excessive disk usage in the work cache.
⚠️ Note: This disables the resume feature. Comment out this section when running tests.

  ```groovy
   params.enable_boost   = false
   params.boost_cleanup  = 'v2'
   
   // Only load plugin when requested
   if (params.enable_boost as boolean) {
     plugins {
       id 'nf-boost@0.6.0'
     }
     boost {
       cleanup = params.boost_cleanup
     }
   }
  ```

## 2. Tune resources per process

- Adjust `cpus`, `memory`, and `time` in `uppmax.config` or `modules/local/common.nf`.  
- Scale resources with `task.attempt` for heavier steps.  
- Check `execution/trace.txt` after runs to refine resource settings.  
- Run small/lightweight steps locally to avoid SLURM overhead. For example:

uppmax.config
  ```groovy
  process {
        
      withName: 'catSortBams' {
       time = '8h'
      }
      
      withName: 'post_clair_phase_contig' {
       time = '3h'
      }
      
      withName: 'phase_contig' {
       time = '6h'
      }

      withName: 'publish_artifact' {
        executor = 'local'
      }

      withName: 'getAllChromosomesBed' {
        executor = 'local'
      }

      withName: 'getVersions' {
        executor = 'local'
      }

      withName: 'output_cnv' {
        executor = 'local'
      }

      withName: 'infer_sex' {
        executor = 'local'
      }

      withName: 'add_snp_tools_to_versions' {
        executor = 'local'
      }

      withName: 'getParams' {
        executor = 'local'
      }

      withName: 'output_sv' {
        executor = 'local'
      }

      withName: 'output_snp' {
        executor = 'local'
      }

      withName: 'annotate_snp_vcf' {
        cpus = 4
        memory = '8 GB'
        time = "10m"
      }

      withName: 'annotate_sv_vcf' {
        cpus = 4
        memory = '8 GB'
        time = '10m'
      }
  }
  ```

modules\local\wf-human-snp.nf
  ```groovy
  def threads = Math.max(task.cpus - 1, 1)
  process phase_contig {
    ...
    longphase phase ... -t ${threads}
    ...
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
   nextflow run main.nf ... --snpeff_data $SNPEFF_DATA
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

## Notes

- Always request realistic SLURM walltimes (`time` in config or `#SBATCH -t`) to avoid the 1-minute default kill.  
- Monitor resource usage with `trace.txt` and adjust process directives accordingly.  
- For debugging snpEff, make sure the DB folder (`GRCh38.p13`, etc.) exists under the bound `$SNPEFF_DATA` path.

---

# Run the workflow

To launch the workflow:

   ```bash
   bash run_workflow.sh
   ```

Adjust the input arguments based on your project:

`--bam` : directory containing aligned BAM files.

`--ref` : reference genome FASTA.

`--sample_name` : label for this run (used in output names).

`--snp --sv --str --mod --phased` : enable SNP calling, structural variant calling, Short Tandem Repeats detection, methylation, and phasing.

`--snpeff_data` : path to the local snpEff database (preinstalled via module).

`-profile singularity` : run using Singularity containers.

`--threads` : number of threads for lightweight tasks (SLURM allocation is handled by config).

`-c $CUSTOM_CONFIG` : use the UPPMAX config for SLURM resource settings and snpEff binding.

`--project` : your UPPMAX project ID.

`-resume` : reuse results from previous runs when possible.

`--enable_boost` : default false. true to enable cleanup boost. 




