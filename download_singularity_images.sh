#!/bin/bash

# Define the container information as associative arrays, found from base.config
declare -A containers
containers=(
    ["e2l_base"]="ontresearch/wf-human-variation:sha8ecee6d351b0c2609b452f3a368c390587f6662d"
    ["e2l_snp"]="ontresearch/wf-human-variation-snp:sha8cc7e88ff71bf593d7852309a31d3adb29a7caeb"
    ["e2l_sv"]="ontresearch/wf-human-variation-sv:sha8134f9fef5e19605c7fb4c1348961d6771f1af79"
    ["e2l_mod"]="ontresearch/modkit:shaa7bf2b62946eeb7646b9b9d60b892edfc3b3a52c"
    ["cnv"]="ontresearch/wf-cnv:sha428cb19e51370020ccf29ec2af4eead44c6a17c2"
    ["str"]="ontresearch/wf-human-variation-str:shadd2f2963fe39351d4e0d6fa3ca54e1064c6ec057"
    ["spectre"]="ontresearch/spectre:sha42472d37a5a992c3ee27894a23dce5e2fff66d27"
    ["snpeff"]="ontresearch/snpeff:shaff5aecfe85e945f49215fa3d43b9ed4ae352bd5c"
    ["common"]="ontresearch/wf-common:sha72f3517dd994984e0e2da0b97cb3f23f8540be4b"
    ["longphase"]="ontresearch/longphase:sha4ff1cd9a6eee338a414082cb24f943bcc4ce8e7c"
)

# Create a directory for downloaded Singularity images
output_dir="singularity"
mkdir -p "$output_dir"

# Loop through the containers and pull them with Singularity
for key in "${!containers[@]}"; do
    # Extract the image name and tag for the output filename
    image="${containers[$key]}"
    base_name=$(echo "$image" | sed 's/[:/]/-/g')

    # Generate the Singularity image filename
    output_file="$output_dir/$base_name.img"

    if [[ -f "$output_file" ]]; then
        echo "Skipping $image (already exists at $output_file)."
        continue
    fi

    echo "Downloading $image as $output_file ..."
    
    # Pull the image with Singularity
    singularity pull --name "$output_file" "docker://$image"
    
    if [[ $? -eq 0 ]]; then
        echo "Successfully downloaded $image."
    else
        echo "Failed to download $image. Please check for errors."
    fi
done

echo "All downloads completed."
