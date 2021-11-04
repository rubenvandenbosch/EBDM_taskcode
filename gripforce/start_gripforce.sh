# INPUTS
# input 1 = full path to conda environment to activate
# input 2 = full path to directory containing this and other gripforce code files

# Collect input arguments
env_path=$1
grip_dir=$2

# Activate conda environment
conda activate $env_path

# Change directory to the folder containing the gripforce files
cd $grip_dir

# Start gripforce recording
xterm -e ./start_recording_buffer.sh &
xterm -e python gripforce2ft.py buffer://localhost:1972 /dev/cu.usbserial-AI04441H 50 True

