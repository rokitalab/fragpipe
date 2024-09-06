# FragPipe
For FragPipe custom mass spectrometry library epitope searching development

Note: Canonical FASTA `UP000005640_9606.fasta` was obtained from [UniProt](https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/Eukaryota/UP000005640/), last modified date of 2024-07-24.

## To reproduce the code in this repository:
This repository contains a docker image and code used to conduct analyses.

1. Clone the repository
```
git clone git@github.com:rokitalab/fragpipe.git
```

2. Pull the docker container:
```
docker pull pgc-images.sbgenomics.com/rokita-lab/fragpipe:latest
```

3. Start the docker container, from the root directory, run:
```
docker run --name <CONTAINER_NAME> -d -e PASSWORD=ANYTHING -p 8787:8787 -v $PWD:/home/rstudio/fragpipe pgc-images.sbgenomics.com/rokita-lab/fragpipe:latest
```
Note: If running on a Macbook with M1 chip, include the argument `--platform linux/amd64`

4. To execute shell within the docker image, from the root directory, run:
```
docker exec -ti <CONTAINER_NAME> bash
```

