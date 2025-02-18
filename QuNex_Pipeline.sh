#!/bin/bash
#export CUDA_VISIBLE_DEVICES=`migtools_getgpu`

ID=$1

module load qunex

STUDY_FOLDER="/home/lpxfd2/Documents/QunexGE/output/${ID}"
RAW_DATA="/home/lpxfd2/Documents/QunexGE/data/${ID}"
BATCH_TEMPLATE="/home/lpxfd2/Documents/QunexGE/hcp_batch.txt"
SESSIONS="${ID}_01_MR"

log_dir="${STUDY_FOLDER}/processing/logs/comlogs"

wait_for_log() {
  local task_name=$1
  while true; do
    echo "Checking for log file: ${log_dir}/done_${task_name}*.log"
    ls -l "${log_dir}/"
    
    if ls "${log_dir}/done_${task_name}"*.log 1> /dev/null 2>&1; then
      echo "Log file found for ${task_name}. Continuing."
      break
    elif ls "${log_dir}/error_${task_name}"*.log 1> /dev/null 2>&1; then
      echo "Error encountered during ${task_name}. Exiting."
      exit 1
    else
      echo "Waiting for log file for ${task_name}..."
      sleep 10
    fi
  done
}


# create study
qunex_container create_study --studyfolder="${STUDY_FOLDER}"
wait_for_log "create_study"

# import data
qunex_container import_hcp \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --inbox="${RAW_DATA}" \
  --sessions="${SESSIONS}" \
  --action="copy" \
  --overwrite="yes" \
  --archive="leave" \
  --nameformat="(?P<subject_id>[^/]+?)/unprocessed/(?P<session_name>.*?)/(?P<data>.*)" \
  --hcplsname="hcpya" \
  --container="${QUNEXCONIMAGE}"
wait_for_log "import_hcp"

# setup hcp
qunex_container setup_hcp \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --sessions="${SESSIONS}" \
  --existing="clear" \
  --hcp_filename="standard" \
  --container="${QUNEXCONIMAGE}"
wait_for_log "setup_hcp"

# create batch
qunex_container create_batch \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --paramfile="${BATCH_TEMPLATE}" \
  --targetfile="${STUDY_FOLDER}/processing/batch.txt" \
  --sessions="${SESSIONS}" \
  --overwrite="append" \
  --container="${QUNEXCONIMAGE}"
wait_for_log "create_batch"

# Run Pre Freesurfer
qunex_container hcp_pre_freesurfer \
  --bind="/home/lpxfd2/Documents/QuenexGE:/home/lpxfd2/Documents/QuenexGE" \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --batchfile="${STUDY_FOLDER}/processing/batch.txt" \
  --container="${QUNEXCONIMAGE}" \
  --overwrite="yes" 
wait_for_log "hcp_pre_freesurfer"

qunex_container hcp_freesurfer \
  --bind="/home/lpxfd2/Documents/QuenexGE:/home/lpxfd2/Documents/QuenexGE" \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --batchfile="${STUDY_FOLDER}/processing/batch.txt" \
  --container="${QUNEXCONIMAGE}" \
  --overwrite="yes" 
wait_for_log "hcp_freesurfer"

qunex_container hcp_post_freesurfer \
  --bind="/home/lpxfd2/Documents/QuenexGE:/home/lpxfd2/Documents/QuenexGE" \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --batchfile="${STUDY_FOLDER}/processing/batch.txt" \
  --container="${QUNEXCONIMAGE}" \
  --overwrite="yes" 
wait_for_log "hcp_post_freesurfer"

# Run Pre Freesurfer
qunex_container hcp_diffusion \
  --bind="/home/lpxfd2/Documents/QuenexGE:/home/lpxfd2/Documents/QuenexGE" \
  --sessionsfolder="${STUDY_FOLDER}/sessions" \
  --batchfile="${STUDY_FOLDER}/processing/batch.txt" \
  --container="${QUNEXCONIMAGE}" \
  --overwrite="yes" \
  --nv \
  --hcp_dwi_combinedata=2 \
  --hcp_dwi_extraeddyarg="--data_is_shelled" 
wait_for_log "hcp_diffusion"
