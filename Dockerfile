#FROM finlaymaguire/rgi:latest
# base image (stripped down ubuntu for Docker)
FROM --platform=linux/amd64 continuumio/miniconda3

# metadata
LABEL base.image="miniconda3"
LABEL version="2"
LABEL software="RGI"
LABEL description="Tool to identify resistance genes using the CARD database"
LABEL website="https://card.mcmaster.ca/"
LABEL documentation="https://github.com/arpcard/rgi/blob/master/README.rst"
LABEL license="https://github.com/arpcard/rgi/blob/master/LICENSE"
LABEL tags="Genomics"
LABEL maintainer="Finlay Maguire <finlaymaguire@gmail.com>"

# get some system essentials
RUN apt-get update && apt-get install -y wget parallel procps && conda init bash

# get latest version of the repo
RUN git clone https://github.com/arpcard/rgi
WORKDIR rgi

#install mamba because conda is slow
RUN conda install -c conda-forge mamba

# install all dependencies matching bioconda package meta.yml
RUN mamba env create -f conda_env.yml

# configure conda shell
SHELL ["conda", "run", "-n", "rgi", "/bin/bash", "-c"]

# install RGI in the repo itself
RUN pip install .

# install core rgi database
RUN wget https://card.mcmaster.ca/latest/data
RUN tar -xvf data ./card.json
RUN rgi load --card_json card.json

# Move to workdir
WORKDIR /data

##### Clean up
RUN rm -rf /var/cache/apt/* /var/lib/apt/lists/*;
RUN yes | conda clean --all
ENV PATH /opt/conda/envs/rgi/bin:$PATH

# ENTRYPOINT ["conda", "run", "-n", "rgi"]
