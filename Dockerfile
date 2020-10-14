FROM nfcore/base
LABEL description="Docker image containing all requirements for lehtiolab/nf-deqms pipeline"

RUN apt update && apt install -y fontconfig && apt clean -y

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/deqms-1.0/bin:$PATH
