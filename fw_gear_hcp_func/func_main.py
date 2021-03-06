#!/usr/bin/env python3
import logging
import os
import os.path as op

from fw_gear_hcp_func import hcpfunc_qc_mosaic, GenericfMRISurfaceProcessingPipeline, \
    GenericfMRIVolumeProcessingPipeline, func_utils
from utils import results

log = logging.getLogger(__name__)


def run(context):
    """
    Set up and complete the fMRIVolume and fMRISurface stages of the HCP Pipeline.
    """
    # Get file list and configuration from hcp-struct zipfile
    try:
        hcp_struct_zip_filename = context.get_input_path("StructZip")
        hcp_struct_list, hcp_struct_config = gear_preliminaries.preprocess_hcp_zip(
            hcp_struct_zip_filename
        )
        context.gear_dict["exclude_from_output"] = hcp_struct_list
        context.gear_dict["hcp_struct_config"] = hcp_struct_config
    except Exception as e:
        log.exception(e)
        log.fatal("Invalid hcp-struct zip file.")
        os.sys.exit(1)

    # Ensure the subject_id is set in a valid manner
    # (api, config, or hcp-struct config)
    try:
        gear_preliminaries.set_subject(context)
    except Exception as e:
        log.exception(e)
        log.fatal(
            "The Subject ID is not valid. Examine and try again.",
        )
        os.sys.exit(1)

    # ##########################################################################
    # #################Build and Validate Parameters############################
    # Doing as much parameter checking before ANY computation.
    # Fail as fast as possible.

    try:
        # Build and validate from Volume Processing Pipeline
        GenericfMRIVolumeProcessingPipeline.build(context)
        GenericfMRIVolumeProcessingPipeline.validate(context)
    except Exception as e:
        log.exception(e)
        log.fatal("Validating Parameters for the fMRI Volume Pipeline Failed!")
        os.sys.exit(1)

    try:
        # Build and validate from Surface Processign Pipeline
        GenericfMRISurfaceProcessingPipeline.build(context)
    except Exception as e:
        log.exception(e)
        log.fatal("Validating Parameters for the fMRI Surface Pipeline Failed!")
        os.sys.exit(1)

    ###########################################################################
    # Unzip hcp-struct results
    try:
        gear_preliminaries.unzip_hcp(context, hcp_struct_zip_filename)
    except Exception as e:
        log.exception(e)
        log.fatal("Unzipping hcp-struct zipfile failed!")
        os.sys.exit(1)

    # ##########################################################################
    # ##################Execute HCP Pipelines ##################################
    # Some hcp-func specific output parameters:
    (
        context.gear_dict["output_config"],
        context.gear_dict["output_config_filename"],
    ) = func_utils.configs_to_export(context)

    context.gear_dict["output_zip_name"] = op.join(
        context.output_dir,
        "{}_{}_hcpfunc.zip".format(
            context.config["Subject"], context.config["fMRIName"]
        ),
    )

    context.gear_dict["remove_files"] = func_utils.remove_intermediate_files
    ###########################################################################
    # Pipelines common commands
    QUEUE = ""
    LogFileDirFull = op.join(context.work_dir, "logs")
    os.makedirs(LogFileDirFull, exist_ok=True)
    FSLSUBOPTIONS = "-l " + LogFileDirFull

    command_common = [
        op.join(context.gear_dict["environ"]["FSLDIR"], "bin", "fsl_sub"),
        FSLSUBOPTIONS,
    ]

    context.gear_dict["command_common"] = command_common

    # Execute fMRI Volume Pipeline
    try:
        GenericfMRIVolumeProcessingPipeline.execute(context)
    except Exception as e:
        log.exception(e)
        log.fatal("The fMRI Volume Pipeline Failed!")
        if context.config["gear-save-on-error"]:
            results.cleanup(context)
        os.sys.exit(1)

    # Execute fMRI Surface Pipeline
    try:
        GenericfMRISurfaceProcessingPipeline.execute(context)
    except Exception as e:
        log.exception(e)
        log.fatal("The fMRI Surface Pipeline Failed!")
        if context.config["gear-save-on-error"]:
            results.cleanup(context)
        os.sys.exit(1)

    # Generate HCP-Functional QC Images
    try:
        hcpfunc_qc_mosaic.build(context)
        hcpfunc_qc_mosaic.execute(context)
    except Exception as e:
        log.exception(e)
        log.fatal("HCP Functional QC Images has failed!")
        if context.config["gear-save-on-error"]:
            results.cleanup(context)
        exit(1)

    ###########################################################################
    # Clean-up and output prep
    results.cleanup(context)

    return os.sys.exit(0)
