import os, os.path as op
import subprocess as sp
from collections import OrderedDict 

def build(context):
    environ = context.custom_dict['environ']
    params = OrderedDict()

    params['qc_scene_root']=op.join(context.work_dir,context.config['Subject'])

    params['T1wTemplateBrain'] = op.join(environ['HCPPIPEDIR_Templates'],
                                'MNI152_T1_' + \
                                str(context.config['TemplateSize']) + \
                                '_brain.nii.gz')

    params['qc_image_root']=op.join(context.work_dir,
                      context.config['Subject']+ \
                      '.hcpstruct_QC.')

    context.custom_dict['params'] = params

def execute(context):
    environ = context.custom_dict['environ']
    SCRIPT_DIR = context.custom_dict['SCRIPT_DIR']
    command = [op.join(SCRIPT_DIR,'hcpstruct_qc_mosaic.sh')]
    for key in context.custom_dict['params'].keys():
        command.append(context.custom_dict['params'][key])
    command.append('>>')
    command.append(op.join(context.work_dir,'logs','structuralqc.log'))
    context.log.info('HCP-Struct QC Mosaic command: \n' + ' '.join(command) + \
                     '\n\n')
    if not context.custom_dict['dry-run']:
        result = sp.Popen(command, stdout=sp.PIPE, stderr=sp.PIPE,
                        universal_newlines=True, env=environ)
        stdout, stderr = result.communicate()
        context.log.info(result.returncode)
        context.log.info(stdout)

        if result.returncode != 0:
            context.log.error('The command:\n ' +
                              ' '.join(command) +
                              '\nfailed. See log for debugging.')
            raise Exception(stderr)