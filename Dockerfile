# Creates docker container that runs HCP Pipeline algorithms
#
#

# Uses xenial
FROM flywheel/hcp-base:1.0.3_4.3.0rc0

LABEL maintainer="Flywheel <support@flywheel.io>"

#############################################
# FSL 6.0.1 is a part of the base image.  Update the environment variables

# Configure FSL environment
ENV FSLDIR=/usr/share/fsl/6.0 \ 
    FSL_DIR="${FSLDIR}" \ 
    FSLOUTPUTTYPE=NIFTI_GZ \ 
    PATH=/usr/share/fsl/6.0/bin:$PATH \ 
    FSLMULTIFILEQUIT=TRUE \ 
    POSSUMDIR=/usr/share/fsl/6.0 \ 
    LD_LIBRARY_PATH=/usr/share/fsl/6.0/lib:$LD_LIBRARY_PATH \ 
    FSLTCLSH=/usr/bin/tclsh \ 
    FSLWISH=/usr/bin/wish \
    CARET7DIR=/opt/workbench/bin_linux64

# Set up specific environment variables for the HCP Pipeline
ENV FSL_DIR="${FSLDIR}" \ 
    HCPPIPEDIR=/opt/HCP-Pipelines \ 
    MSMBINDIR=${HCPPIPEDIR}/MSMBinaries \ 
    MSMCONFIGDIR=${HCPPIPEDIR}/MSMConfig
#ENV MATLAB_COMPILER_RUNTIME=/media/myelin/brainmappers/HardDrives/1TB/MATLAB_Runtime/v901
#ENV FSL_FIXDIR=/media/myelin/aahana/fix1.06

#For HCP Pipeline v4.0.1
ENV MSMBin=${HCPPIPEDIR}/MSMBinaries \
    HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates \ 
    HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries \ 
    HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config \ 
    HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts \ 
    HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts \ 
    HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts \ 
    HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts \ 
    HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts \ 
    HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts \ 
    HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts \ 
    HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography/scripts \ 
    HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts \ 
    HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts

#try to reduce strangeness from locale and other environment settings
ENV LC_ALL=C \ 
    LANGUAGE=C
#POSIXLY_CORRECT currently gets set by many versions of fsl_sub, unfortunately, but at least don't pass it in if the user has it set in their usual environment
RUN unset POSIXLY_CORRECT

#############################################
# FreeSurfer is installed in base image. Ensure environment is set
# 6.0.1 ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.1/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.1.tar.gz

# Set up the FreeSurfer environment
ENV OS=Linux \ 
    FS_OVERRIDE=0 \ 
    FIX_VERTEX_AREA= \ 
    SUBJECTS_DIR=/opt/freesurfer/subjects \ 
    FSF_OUTPUT_FORMAT=nii.gz \ 
    MNI_DIR=/opt/freesurfer/mni \ 
    LOCAL_DIR=/opt/freesurfer/local \ 
    FREESURFER_HOME=/opt/freesurfer \ 
    FSFAST_HOME=/opt/freesurfer/fsfast \ 
    MINC_BIN_DIR=/opt/freesurfer/mni/bin \ 
    MINC_LIB_DIR=/opt/freesurfer/mni/lib \ 
    MNI_DATAPATH=/opt/freesurfer/mni/data \ 
    FMRI_ANALYSIS_DIR=/opt/freesurfer/fsfast \ 
    PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5 \ 
    MNI_PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5 \ 
    PATH=/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/freesurfer/mni/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

#############################################
# Gradient unwarp script is installed in base image. 

#############################################
# MSM_HOCR v3 binary is installed in base image.
ENV MSMBINDIR=${HCPPIPEDIR}/MSMBinaries

# Install BIDS Validator
RUN apt-get update &&\
    apt-get install -y --no-install-recommends python3-pip && \
    apt-get clean && \
    pip install bids_validator && \
    rm -rf /var/lib/apt/lists/*

#############################################
# Copy gear-specific utils and dependencies
COPY utils ${FLYWHEEL}/utils

#TODO make a Docker user profile with permissions to the flywheel folder for singularity analysis

COPY scripts /tmp/scripts
COPY scenes /tmp/scenes

# Copy executable/manifest to Gear
COPY run.py ${FLYWHEEL}/run.py
COPY manifest.json ${FLYWHEEL}/manifest.json

# Patch from Keith Jamison's Gear. Change at your own risk.
COPY scripts/patch/DiffPreprocPipeline.sh /opt/HCP-Pipelines/DiffusionPreprocessing/

# ENV preservation for Flywheel Engine
# Do not remove this. utils.bids.environment depends on it and is called heavily through out suite.
RUN python -c 'import os, json; f = open("/tmp/gear_environ.json", "w"); json.dump(dict(os.environ), f)'


# Add poetry oversight.
RUN apt-get update && \
	apt-get install -y \
	software-properties-common &&\
	add-apt-repository ppa:deadsnakes/ppa && \
	apt-get update && \
	apt-get install -y --no-install-recommends python3.9\
	python3.9-venv \
	python3-pip\
	python3.9-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install poetry based on their preferred method. pip install is finnicky.
# Designate the install location, so that you can find it in Docker.
ENV PYTHONUNBUFFERED=1 \
    POETRY_VERSION=1.1.6 \
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    # do not ask any interactive questions
    POETRY_NO_INTERACTION=1 \
    VIRTUAL_ENV=/opt/venv
RUN python3.9 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN python3.9 -m pip install --upgrade pip && \
    ln -sf /usr/bin/python3.9 /opt/venv/bin/python3
ENV PATH="$POETRY_HOME/bin:$PATH"
#
## get-poetry respects ENV
#RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python
#
#
## Installing main dependencies
#COPY pyproject.toml poetry.lock $FLYWHEEL/
#RUN poetry install --no-dev
#
## Installing the current project (most likely to change, above layer can be cached)
## Note: poetry requires a README.md to install the current project
COPY run.py manifest.json README.md $FLYWHEEL/
COPY fw_gear_hcp_struct $FLYWHEEL/fw_gear_hcp_struct
COPY fw_gear_hcp_func $FLYWHEEL/fw_gear_hcp_func
COPY fw_gear_hcp_diff $FLYWHEEL/fw_gear_hcp_diff
COPY utils $FLYWHEEL/utils
#RUN poetry install --no-dev

# Configure entrypoint
RUN chmod a+x $FLYWHEEL/run.py
ENTRYPOINT ["/flywheel/v0/run.py"]
#ENTRYPOINT ["poetry","run","python","/flywheel/v0/run.py"]
